#include "cimbar_c.h"

#include "cimb_translator/CimbDecoder.h"
#include "cimb_translator/CimbReader.h"
#include "cimb_translator/Config.h"
#include "compression/zstd_decompressor.h"
#include "compression/zstd_header_check.h"
#include "encoder/Decoder.h"
#include "extractor/Extractor.h"
#include "fountain/fountain_decoder_sink.h"

#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

#include <memory>
#include <mutex>
#include <vector>

using namespace cimbar;

struct mem_ostream {
    std::vector<uint8_t> buf;
    void write(const char* data, size_t len) {
        buf.insert(buf.end(), (const uint8_t*)data, (const uint8_t*)data + len);
    }
    mem_ostream() = default;
    mem_ostream(const std::string&, std::ios_base::openmode) {}
};

struct cimbar_decoder_t {
    Decoder decoder{true /*ecc*/, true /*interleave*/};
    std::unique_ptr<fountain_decoder_sink> fountain_sink;
    std::mutex mutex;

    bool complete = false;
    std::vector<uint8_t> output;
    std::string filename;
};

extern "C" {

cimbar_decoder_t* cimbar_decoder_create(unsigned color_bits, unsigned symbol_bits,
                                         int dark, int config_mode) {
    cimbar::Config::update(config_mode);
    auto* d = new cimbar_decoder_t();
    try {
        unsigned bitsPerOp = cimbar::Config::color_bits() + cimbar::Config::symbol_bits();
        unsigned chunkSize = cimbar::Config::fountain_chunk_size(bitsPerOp);

        auto on_store = [d](const std::string& fallback, const std::vector<uint8_t>& compressed) -> std::string {
            std::string realName = zstd_header_check::get_filename(compressed.data(), compressed.size());
            d->filename = realName.empty() ? fallback : realName;

            zstd_decompressor<mem_ostream> dec;
            dec.write((const char*)compressed.data(), compressed.size());
            d->output = std::move(dec.buf);
            d->complete = true;
            return d->filename;
        };

        d->fountain_sink = std::make_unique<fountain_decoder_sink>(chunkSize, on_store);
    } catch (...) {
        delete d;
        return nullptr;
    }
    return d;
}

const char* cimbar_decoder_get_filename(cimbar_decoder_t* dec) {
    return dec ? dec->filename.c_str() : nullptr;
}

void cimbar_decoder_destroy(cimbar_decoder_t* dec) { delete dec; }

int cimbar_decoder_process_frame(cimbar_decoder_t* dec,
                                  const void* bgra_data, unsigned w, unsigned h, unsigned stride,
                                  uint8_t** out_data, size_t* out_len, float* progress) {
    if (!dec || dec->complete) return 0;

    cv::Mat img((int)h, (int)w, CV_8UC4, (void*)bgra_data, (int)stride);
    if (img.empty()) return 0;

    Extractor extractor(0, {cimbar::Config::image_size_x(), cimbar::Config::image_size_y()});
    cv::Mat deskewed;
    int status = extractor.extract(img, deskewed);
    if (status == Extractor::FAILURE) return 0;
    bool needsSharpen = (status == Extractor::NEEDS_SHARPEN);

    try {
        dec->decoder.decode_fountain(deskewed, *dec->fountain_sink, needsSharpen, 2);
    } catch (...) {
        return 0;
    }

    {
        std::lock_guard<std::mutex> lock(dec->mutex);
        if (dec->complete) {
            *out_data = (uint8_t*)malloc(dec->output.size());
            if (*out_data) {
                memcpy(*out_data, dec->output.data(), dec->output.size());
                *out_len = dec->output.size();
            }
            if (progress) *progress = 1.0f;
            return 2;
        }

        auto progVec = dec->fountain_sink->get_progress();
        float p = 0.0f;
        if (!progVec.empty()) p = (float)progVec[0];
        if (progress) *progress = p;
    }
    return 1;
}

float cimbar_decoder_progress(cimbar_decoder_t* dec) {
    if (!dec) return 0.0f;
    if (dec->complete) return 1.0f;
    std::lock_guard<std::mutex> lock(dec->mutex);
    auto pv = dec->fountain_sink->get_progress();
    return pv.empty() ? 0.0f : (float)pv[0];
}

void cimbar_decoder_reset(cimbar_decoder_t* dec) {
    if (!dec) return;
    std::lock_guard<std::mutex> lock(dec->mutex);
    dec->complete = false;
    dec->output.clear();

    unsigned bitsPerOp = cimbar::Config::color_bits() + cimbar::Config::symbol_bits();
    unsigned chunkSize = cimbar::Config::fountain_chunk_size(bitsPerOp);

    auto on_store = [dec](const std::string& fallback, const std::vector<uint8_t>& compressed) -> std::string {
        std::string realName = zstd_header_check::get_filename(compressed.data(), compressed.size());
        dec->filename = realName.empty() ? fallback : realName;

        zstd_decompressor<mem_ostream> d;
        d.write((const char*)compressed.data(), compressed.size());
        dec->output = std::move(d.buf);
        dec->complete = true;
        return dec->filename;
    };

    dec->fountain_sink = std::make_unique<fountain_decoder_sink>(chunkSize, on_store);
    dec->decoder = Decoder{true, true};
}

} // extern "C"
