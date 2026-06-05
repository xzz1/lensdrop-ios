/* Pure C API for libcimbar decoder. No ObjC, no C++ in this header. */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

typedef struct cimbar_decoder_t cimbar_decoder_t;

typedef struct cimbar_decoder_frame_stats_t {
    uint64_t processed_frames;
    uint64_t extracted_frames;
    uint64_t decoded_frames;
    uint64_t decoded_bytes;
    double frame_ms;
} cimbar_decoder_frame_stats_t;

cimbar_decoder_t* cimbar_decoder_create(unsigned color_bits, unsigned symbol_bits,
                                         int dark, int config_mode);
void cimbar_decoder_destroy(cimbar_decoder_t* dec);

/* Returns 0 if frame was skipped, >0 if data was produced.
   On completion, *out_data and *out_len are set. Caller must free *out_data. */
int cimbar_decoder_process_frame(cimbar_decoder_t* dec,
                                  const void* bgra_data, unsigned w, unsigned h, unsigned stride,
                                  uint8_t** out_data, size_t* out_len, float* progress,
                                  cimbar_decoder_frame_stats_t* stats);

const char* cimbar_decoder_get_filename(cimbar_decoder_t* dec);
float cimbar_decoder_progress(cimbar_decoder_t* dec);
void cimbar_decoder_reset(cimbar_decoder_t* dec);

#ifdef __cplusplus
}
#endif
