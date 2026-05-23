#import "CimbarDecoderBridge.h"
#import "cimbar_c.h"                // pure C, no C++ headers — avoids ObjC `id` conflict

#import <AVFoundation/AVFoundation.h>

// ---------------------------------------------------------------------------
// CimbarDecodeResult
// ---------------------------------------------------------------------------
@implementation CimbarDecodeResult
@end

// ---------------------------------------------------------------------------
// CimbarDecoderBridge
// ---------------------------------------------------------------------------
@interface CimbarDecoderBridge () {
    cimbar_decoder_t *_decoder;
}
@end

@implementation CimbarDecoderBridge

- (instancetype)initWithExpectedFileSize:(uint64_t)expectedSize
                               colorBits:(unsigned)colorBits
                              symbolBits:(unsigned)symbolBits
                                    dark:(BOOL)dark
                              configMode:(int)configMode
{
    self = [super init];
    if (!self) return nil;

    (void)expectedSize; // reserved for future use
    _decoder = cimbar_decoder_create(colorBits, symbolBits, dark, configMode);
    if (!_decoder) return nil;
    return self;
}

- (void)dealloc {
    if (_decoder) cimbar_decoder_destroy(_decoder);
    _decoder = nullptr;
}

- (nullable CimbarDecodeResult *)processFrame:(CMSampleBufferRef)sampleBuffer {
    if (!_decoder) return nil;

    CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pb) return nil;

    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    void *addr  = CVPixelBufferGetBaseAddress(pb);
    size_t w    = CVPixelBufferGetWidth(pb);
    size_t h    = CVPixelBufferGetHeight(pb);
    size_t bpr  = CVPixelBufferGetBytesPerRow(pb);
    OSType fmt  = CVPixelBufferGetPixelFormatType(pb);

    if (fmt != kCVPixelFormatType_32BGRA || !addr) {
        CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    uint8_t *outData = NULL;
    size_t   outLen  = 0;
    float    progress = 0.0f;

    // Zero-copy: pass raw pointer to C++. Lock held during decode, no 8MB clone.
    int rc = cimbar_decoder_process_frame(_decoder, addr, (unsigned)w, (unsigned)h, (unsigned)bpr,
                                           &outData, &outLen, &progress);
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);

    CimbarDecodeResult *result = [[CimbarDecodeResult alloc] init];
    result.progress = progress;

    if (rc == 2 && outData && outLen > 0) {
        result.success  = YES;
        result.fileData = [NSData dataWithBytesNoCopy:outData length:outLen freeWhenDone:YES];
        const char* cname = cimbar_decoder_get_filename(_decoder);
        result.fileName = cname ? [NSString stringWithUTF8String:cname] : @"cimbar_received.bin";
        result.progress = 1.0f;
    } else if (rc == 1) {
        result.success = NO;
    } else {
        return nil; // frame skipped
    }
    return result;
}

- (float)decodeProgress {
    return _decoder ? cimbar_decoder_progress(_decoder) : 0.0f;
}

- (void)reset {
    if (_decoder) cimbar_decoder_reset(_decoder);
}

@end
