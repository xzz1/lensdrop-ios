#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/// Decode result for a single frame (or batch of frames).
/// progress is a hint from the fountain decoder (0..1). @c success==YES when the file is complete.
@interface CimbarDecodeResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, assign) float progress;
@property (nonatomic, strong, nullable) NSData *fileData;
@property (nonatomic, copy,   nullable) NSString *fileName;
@property (nonatomic, assign) unsigned long long processedFrames;
@property (nonatomic, assign) unsigned long long extractedFrames;
@property (nonatomic, assign) unsigned long long decodedFrames;
@property (nonatomic, assign) unsigned long long decodedBytes;
@property (nonatomic, assign) double frameMilliseconds;
@end

/// Objective-C++ bridge that wraps the libcimbar C++ decoding pipeline.
@interface CimbarDecoderBridge : NSObject

/// @param expectedSize  Expected file size in bytes, or 0 if unknown.
/// @param colorBits     Bits per tile carried in colour channel (default 2).
/// @param symbolBits    Bits per tile carried in the symbol (default 4).
/// @param dark          @c YES for dark-background codes, @c NO for light.
/// @param configMode    Config preset: 0=auto, 4=5x5 legacy, 8=8x8 legacy, 66=micro, 67=mini, 68=standard.
- (instancetype)initWithExpectedFileSize:(uint64_t)expectedSize
                               colorBits:(unsigned)colorBits
                              symbolBits:(unsigned)symbolBits
                                    dark:(BOOL)dark
                              configMode:(int)configMode;

/// Feed one camera frame into the decoder.
/// Returns a result with progress; @c fileData is non-nil only on completion.
/// Returns @c nil when the frame was skipped or produced no new data.
- (nullable CimbarDecodeResult *)processFrame:(CMSampleBufferRef)sampleBuffer;

/// Current decode progress (0..1).
- (float)decodeProgress;

/// Reset the decoder for a fresh transfer.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
