//
//  VideoToolboxEncoder.h
//  compression
//
//  Created by xuyang on 2021/9/2.
//

#ifndef VideoToolboxEncoder_h
#define VideoToolboxEncoder_h
#include <stdio.h>
#import <VideoToolbox/VideoToolbox.h>
#import <Foundation/Foundation.h>
#include <CoreVideo/CoreVideo.h>
#include <CoreGraphics/CGImage.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMFormatDescription.h>
#include <time.h>


#define XLOG(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#define CHECK_STATUS_LOG(s,msg) {if (s != noErr) {XLOG("set %s failed: %d", #msg, (int)s);}};

typedef OSStatus(*getParameterSetAtIndexFunc)(CMFormatDescriptionRef videoDesc,
                                              size_t parameterSetIndex,
                                              const uint8_t** parameterSetPointerOut,
                                              size_t* parameterSetSizeOut,
                                              size_t* parameterSetCountOut,
                                              int* NALUnitHeaderLengthOut);

enum  VideoCodecType {
  kVideoCodecH264 = 0,
  kVideoCodecHEVC,
};

struct CodecSettings {
  int width = 1080;
  int height = 1920;
  int gop_size = 30;
  int bitrate = 20000000;
  double fps = 29.97;
  VideoCodecType codec_type;

  // reserved for HEVC
//  int temporal_layers = 1;
};

class VideoToolboxEncoder {
 public:
  VideoToolboxEncoder();
  virtual ~VideoToolboxEncoder();

  bool InitCompressionSession();
  int Encode(CVPixelBufferRef pixel_buffer, int pts);
  void DestroyCompressionSession();

//  CVPixelBufferRef pixel_buffer = nullptr;
  
  CodecSettings codec_settings;
  
//  getParameterSetAtIndexFunc get_param_set_func_;
  
  VTCompressionSessionRef compression_session_ = NULL;
};


#endif /* VideoToolboxEncoder_h */
