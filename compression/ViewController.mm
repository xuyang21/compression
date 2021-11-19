//
//  ViewController.m
//  compression
//
//  Created by xuyang on 2021/9/2.
//

#import "ViewController.h"
#import "VideoToolboxEncoder.h"
#import <AVFoundation/AVFoundation.h>
@interface ViewController ()
@property (nonatomic, weak)IBOutlet UITextField* dealy_text;
@property (nonatomic, weak)IBOutlet UITextField* cost_time_text;
@property (nonatomic, weak)IBOutlet UITextField* av_asset_cost_time_text;
@end

BOOL clearCacheWithFilePath(NSString *path){
  //拿到path路径的下一级目录的子文件夹
  NSArray *subPathArr = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
  if(subPathArr.count == 0){
    return YES;
  }
    NSString *filePath = nil;
    NSError *error = nil;
    for (NSString *subPath in subPathArr)
    {
        filePath = [path stringByAppendingPathComponent:subPath];
        //删除子文件夹
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (error) {
            return NO;
        }
    }
    return YES;
}

@implementation ViewController

inline int64_t getSysMicroSec() {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}

void delayms(int us){
  int64_t start = getSysMicroSec();
  while(getSysMicroSec()-start < us);
}

static void dict_set_i32(CFMutableDictionaryRef dict, CFStringRef key,
                  int32_t value) {
  CFNumberRef number;
  number = CFNumberCreate(nil, kCFNumberSInt32Type, &value);
  CFDictionarySetValue(dict, key, number);
  CFRelease(number);
}


- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  self.dealy_text.text = @"1000";
}

- (IBAction)startEncode{
  int delay_us = self.dealy_text.text.intValue;
  XLOG("delay %d ms between each frame", delay_us);
  VideoToolboxEncoder myEncoder;
  CodecSettings* codec_settings = &myEncoder.codec_settings;
//  codec_setting.
  CVPixelBufferRef pixel_buffer = NULL;
  XLOG("create pixcelBuffer, width: %d, height: %d, bitrate: %d", codec_settings->width, codec_settings->height, codec_settings->bitrate);
  CVPixelBufferCreate(NULL, codec_settings->width, codec_settings->height, kCVPixelFormatType_420YpCbCr8Planar, NULL, &pixel_buffer);
 
  int64_t start_encode = getSysMicroSec();
  myEncoder.InitCompressionSession();
  for(int i = 0; i < 1830; ++i){
    delayms(delay_us);
    myEncoder.Encode(pixel_buffer, i);
  }
  myEncoder.Encode(NULL, 0);
  int64_t end_encode = getSysMicroSec();
  double cost_time = (double)(end_encode-start_encode)/1e6;
  XLOG("encode finished! cost %lfs", cost_time);
  NSString *strValue = [@(cost_time) stringValue];
  self.cost_time_text.text = strValue;
}

- (IBAction)AVAssetStartEncode{
  int delay_us = self.dealy_text.text.intValue;
  XLOG("delay %d ms between each frame", delay_us);
  CVPixelBufferRef pixel_buffer = NULL;
  int32_t res = CVPixelBufferCreate(NULL, 1080, 1920, kCVPixelFormatType_420YpCbCr8PlanarFullRange, NULL, &pixel_buffer);
  if(res < 0){
    XLOG("create pixcelBuffer failed");
    return;
  }
  XLOG("create pixcelBuffer");
  
  int64_t start_encode = getSysMicroSec();
  NSError *error = nil;
  NSString *path_document=NSHomeDirectory();
  NSString *libDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *tmpDir = NSTemporaryDirectory();
  if(!clearCacheWithFilePath(tmpDir)){
    XLOG("clearCacheWithFilePath failed");
    return;
  }
  AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:
      [NSURL fileURLWithPath:[tmpDir stringByAppendingString: @"wt.MOV"]] fileType:AVFileTypeQuickTimeMovie
      error:&error];
  NSParameterAssert(videoWriter);
  NSDictionary* compressionProperties =
      @{
        (__bridge NSString *)kVTCompressionPropertyKey_ExpectedFrameRate:@(29.97),
//        (__bridge NSString *)kVTCompressionPropertyKey_AverageBitRate:@(20000000),
        AVVideoProfileLevelKey:(__bridge NSString *)kVTProfileLevel_HEVC_Main_AutoLevel,
        AVVideoExpectedSourceFrameRateKey: @(29.97),
        (__bridge NSString *)kVTCompressionPropertyKey_RealTime:@YES,
        (__bridge NSString *)kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality:@YES,
        };
  
  NSDictionary *videoColorProperties = @{
    AVVideoColorPrimariesKey:AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoTransferFunctionKey:AVVideoTransferFunction_ITU_R_709_2,
    AVVideoYCbCrMatrixKey:AVVideoYCbCrMatrix_ITU_R_709_2
  };
  NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecTypeHEVC,
                                         AVVideoWidthKey: @(1080),
                                         AVVideoHeightKey: @(1920),
                                  AVVideoCompressionPropertiesKey:compressionProperties,
                                  AVVideoColorPropertiesKey:videoColorProperties
  };
  AVAssetWriterInput* writerInput = [AVAssetWriterInput
      assetWriterInputWithMediaType:AVMediaTypeVideo
      outputSettings:videoSettings];
  NSParameterAssert(writerInput);
  NSDictionary *pixelBufferAttributes = @{
    (__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey : [NSNumber numberWithBool:YES],
    (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : [NSNumber numberWithBool:YES],
    (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8PlanarFullRange],
    (__bridge NSString *)kCVPixelBufferWidthKey : [NSNumber numberWithInt:1080],
    (__bridge NSString *)kCVPixelBufferHeightKey : [NSNumber numberWithInt:1920],
  };
  AVAssetWriterInputPixelBufferAdaptor* writerInputAdaptor = [AVAssetWriterInputPixelBufferAdaptor
      assetWriterInputPixelBufferAdaptorWithAssetWriterInput: writerInput
      sourcePixelBufferAttributes: pixelBufferAttributes];
  writerInput.expectsMediaDataInRealTime = YES;
  if([videoWriter canAddInput:writerInput] == false){
    XLOG("add input failed");
  }
  [videoWriter addInput:writerInput];
  [videoWriter startWriting];
  [videoWriter startSessionAtSourceTime: kCMTimeZero];
  for(int i = 0; i < 1830;){
    if([[writerInputAdaptor assetWriterInput] isReadyForMoreMediaData] == true){
      CMTime timestamp_ms = CMTimeMake((i*100000/29.97), 100000);
      BOOL status = [writerInputAdaptor appendPixelBuffer:pixel_buffer withPresentationTime:timestamp_ms];
      ++i;
      if(status == true){
        XLOG("AvAssetWriter write succeed");
      }
      else{
        XLOG("AvAssetWriter write failed");
        return;
      }
    }
  }
  CMTime timestamp_ms = CMTimeMake(183100000/29.97, 100000);
  [writerInput markAsFinished];
  [videoWriter endSessionAtSourceTime:timestamp_ms];
  [videoWriter finishWritingWithCompletionHandler:^{}];
  
  int64_t end_encode = getSysMicroSec();
  double cost_time = (double)(end_encode-start_encode)/1e6;
  XLOG("AvAssetWriter encode finished! cost %lfs", cost_time);
  NSString *strValue = [@(cost_time) stringValue];
  self.av_asset_cost_time_text.text = strValue;
}

@end

