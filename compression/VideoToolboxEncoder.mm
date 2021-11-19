//
//  VideoToolboxEncoder.cpp
//  compression
//
//  Created by xuyang on 2021/9/2.
//

#include "VideoToolboxEncoder.h"
#import <VideoToolbox/VTCompressionProperties.h>
#include <stdio.h>
inline int64_t getSysMicroSec() {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}

void dict_set_i32(CFMutableDictionaryRef dict, CFStringRef key,
                  int32_t value) {
  CFNumberRef number;
  number = CFNumberCreate(nil, kCFNumberSInt32Type, &value);
  CFDictionarySetValue(dict, key, number);
  CFRelease(number);
}


inline int64_t getTimeDiff(int64_t& last) {
  int64_t now = getSysMicroSec();
  int64_t diff = now - last;
  last = now;
  return diff;
}

void delay(int us){
  int64_t start = getSysMicroSec();
  while(getSysMicroSec()-start < us);
}


VideoToolboxEncoder::VideoToolboxEncoder() {
  XLOG("[VideoToolBoxEncoder] Created");
}

VideoToolboxEncoder::~VideoToolboxEncoder() {
  DestroyCompressionSession();
  XLOG("[VideoToolBoxEncoder] destructed");
}



static void encodeComplete(void* outputCallbackRefCon,
                           void* sourceFrameRefCon,
                           OSStatus status,
                           VTEncodeInfoFlags infoFlags,
                           CMSampleBufferRef sampleBuffer) {
  XLOG("encode one frame complete, current time is: %lld", getSysMicroSec());
  if (sampleBuffer == NULL) {
    XLOG("error!!!, sampleBuffer is nil");
    return;
  }
  if (!CMSampleBufferDataIsReady(sampleBuffer)) {
    XLOG("sampleBuffer data not ready");
    return;
  }
//  delay(1000);
//  CFRelease(sampleBuffer);
}


bool VideoToolboxEncoder::InitCompressionSession() {
  CFMutableDictionaryRef encoderSpecification =
      CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);

  CFMutableDictionaryRef sourceImageBufferAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
  CFDictionarySetValue(sourceImageBufferAttributes, kCVPixelBufferOpenGLESCompatibilityKey, kCFBooleanTrue);
  CFDictionaryRef io_surface_value = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, NULL, NULL);
  CFDictionarySetValue(sourceImageBufferAttributes, kCVPixelBufferIOSurfacePropertiesKey, io_surface_value);

  OSType target_pixelformat = kCVPixelFormatType_420YpCbCr8Planar;
  dict_set_i32(sourceImageBufferAttributes,
                 kCVPixelBufferPixelFormatTypeKey, target_pixelformat);
  dict_set_i32(sourceImageBufferAttributes,
                 kCVPixelBufferBytesPerRowAlignmentKey, 16);
  CFDictionarySetValue(sourceImageBufferAttributes, kCVPixelBufferWidthKey, CFNumberCreate(NULL, kCFNumberIntType, &codec_settings.width));
  CFDictionarySetValue(sourceImageBufferAttributes, kCVPixelBufferHeightKey, CFNumberCreate(NULL, kCFNumberIntType, &codec_settings.height));

  OSStatus status = VTCompressionSessionCreate(NULL,
                                      codec_settings.width,
                                      codec_settings.height,
                                      kCMVideoCodecType_HEVC,
                                      NULL,
                                      sourceImageBufferAttributes,
                                      NULL,
                                      encodeComplete,
                                      this,
                                      &compression_session_);
  CFRelease(encoderSpecification);
  CFRelease(sourceImageBufferAttributes);
  CHECK_STATUS_LOG(status, VTCompressionSessionCreate);
  
  //设置实时编码输出（避免延迟）
  //default enable realtime encode, which will disable B frames
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_RealTime);

  //设置不产生B帧
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_AllowFrameReordering);

  //设置期望帧率
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(29.97));
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_ExpectedFrameRate);

  //设置设置关键帧（GOPsize)间隔
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_MaxKeyFrameInterval,
                                (__bridge CFTypeRef)@(codec_settings.gop_size));
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_MaxKeyFrameInterval);

  //是否考虑电池效率
//  status = VTSessionSetProperty(compression_session_,
//                       kVTCompressionPropertyKey_MaximizePowerEfficiency,
//                       kCFBooleanFalse);
//  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_MaximizePowerEfficiency);

  //是否编码速度优先
//  status = VTSessionSetProperty(compression_session_,
//                       kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality,
//                       kCFBooleanTrue);
//  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality);

  //设置编码器profile
  CFStringRef profileRef;
  profileRef = kVTProfileLevel_HEVC_Main_AutoLevel;
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_ProfileLevel, profileRef);
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_ProfileLevel);
  
  //是否允许openGOP
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_AllowOpenGOP, kCFBooleanFalse);
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_AllowOpenGOP);

  //设置平均比特率
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(codec_settings.bitrate));
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_AverageBitRate);

  //设置比特率上限
  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef)@[@20000000, @10]);
  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_DataRateLimits);
  
  //开启分层编码 便于丢帧
//  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_AllowTemporalCompression, kCFBooleanFalse);
//  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_AllowTemporalCompression);
  
//  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_Quality, (__bridge CFTypeRef)@(0.1));
//  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_Quality);
  
  
//  status = VTSessionSetProperty(compression_session_, kVTCompressionPropertyKey_MaxFrameDelayCount, (__bridge CFTypeRef)@(3));
//  CHECK_STATUS_LOG(status, kVTCompressionPropertyKey_MaxFrameDelayCount);
  //准备解码
  VTCompressionSessionPrepareToEncodeFrames(compression_session_);
  return 0;
}

static void outputHandler (OSStatus status,
          VTEncodeInfoFlags infoFlags,
          CMSampleBufferRef sampleBuffer ){
  
}


int VideoToolboxEncoder::Encode(CVPixelBufferRef pixel_buffer, int pts) {
  if (pixel_buffer) {
    // timestamp_ms will affect encode bitrate. Make sure it is in millisecconds
    int frame_duration_ms = 1000 / 29.97;
    CMTime timestamp_ms = CMTimeMake(pts* frame_duration_ms, 1000);

    VTEncodeInfoFlags flags;
    int64_t startEncodeFrame = getSysMicroSec();
    OSStatus status = VTCompressionSessionEncodeFrame(compression_session_, pixel_buffer, timestamp_ms, kCMTimeInvalid, nullptr, nullptr, &flags);
    int64_t endEncodeFrame = getSysMicroSec();
    XLOG("Encode one Frame  cost: %dus, flag: %d, current time is: %lld", (int)(endEncodeFrame-startEncodeFrame), flags, getSysMicroSec());
    if (status != noErr) {
      XLOG("VTCompressionSessionEncodeFrame error:%d", (int)status);
      return -1;
    }
  } else {
    // flush encoder.
    OSStatus status = VTCompressionSessionCompleteFrames(compression_session_, kCMTimeIndefinite);
    if (status != noErr) {
      XLOG("VTCompressionSessionCompleteFrames error:%d", (int)status);
      return -1;
    }
  }
  return 0;
}

void VideoToolboxEncoder::DestroyCompressionSession() {
  if (compression_session_) {
    // descard all pending frames
    XLOG("VideoToolBoxEncoder::DestroyCompressionSession called");
    VTCompressionSessionCompleteFrames(compression_session_, kCMTimeInvalid);
    VTCompressionSessionInvalidate(compression_session_);
    CFRelease(compression_session_);
    compression_session_ = nullptr;
  }
}
