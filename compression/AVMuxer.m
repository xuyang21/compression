////
////  AVMuxer.m
////  compression
////
////  Created by xuyang on 2021/11/15.
////
//
//#import <Foundation/Foundation.h>
//#import "AVMuxer.h"
//#import <AVFoundation/AVFoundation.h>
//
//@implementation AVMuxer
//{
//    dispatch_semaphore_t semaphore;
//    dispatch_queue_t    awriteQueue;
//    dispatch_queue_t    vwriteQueue;
//}
//
//
//- (void)transcodec:(NSURL *)srcURL dstURL:(NSURL *)dstURL
//{
//    semaphore = dispatch_semaphore_create(0);
//    awriteQueue = dispatch_queue_create("awriteQueue.com", DISPATCH_QUEUE_SERIAL);
//    vwriteQueue = dispatch_queue_create("vwriteQueue.com", DISPATCH_QUEUE_SERIAL);
//    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
//
//    AVURLAsset *inputAsset = [AVURLAsset assetWithURL:srcURL];
//    [inputAsset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
//        AVAssetReader *reader = [self createReader:inputAsset];
//        [self demuxer:reader dstUrl:dstURL];
//    }];
//
//    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
//    NSLog(@"结束了，耗时 %f秒",CFAbsoluteTimeGetCurrent() - startTime);
//
//}
//
//- (AVAssetReader*)createReader:(AVAsset*)asset
//{
//    NSError *error = nil;
//    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
//    if (error) {
//        NSLog(@"create reader failer");
//        return nil;
//    }
//
//    // 创建视频输出对象
//    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
//    // 由于这里要从h264编码变成h265编码，所以就需要视频的格式为YUV的
//    /** 遇到问题：编码视频提示Domain=AVFoundationErrorDomain Code=-11800 "The operation could not be completed"
//     *  分析原因：iOS不支持kCVPixelFormatType_422YpCbCr8BiPlanarFullRange，这里写错了应该是kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
//     *  解决方案：改成kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
//     */
//    NSDictionary *videoOutputs = @{
//        (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
//    };
//    AVAssetReaderTrackOutput *readerVideoTrackOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:videoOutputs];
//    readerVideoTrackOut.alwaysCopiesSampleData = NO;
//    [reader addOutput:readerVideoTrackOut];
//
//    // 创建音频输出对象
//    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
//    NSDictionary *audioSettings = @{
//        AVFormatIDKey:@(kAudioFormatLinearPCM),
//    };
//    AVAssetReaderTrackOutput *readerAudioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack outputSettings:audioSettings];
//    readerAudioOutput.alwaysCopiesSampleData = NO;
//    [reader addOutput:readerAudioOutput];
//
//    return reader;
//}
//
//- (void)demuxer:(AVAssetReader*)reader dstUrl:(NSURL*)dstUrl
//{
//    AVAsset *asset = reader.asset;
//
//    // 获取视频相关参数信息
//    CMFormatDescriptionRef srcVideoformat = (__bridge CMFormatDescriptionRef)[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0].formatDescriptions[0];
//    CMVideoDimensions demensions = CMVideoFormatDescriptionGetDimensions(srcVideoformat);
//
//    // 创建封装器，通过封装器的回调函数驱动来获取数据
//    NSError *error = nil;
//    // zsz:todo 又一次忘记写了这句代码
//    unlink([dstUrl.path UTF8String]);
//    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:dstUrl fileType:AVFileTypeQuickTimeMovie error:&error];
//    if (error) {
//        NSLog(@"create writer failer");
//        dispatch_semaphore_signal(semaphore);
//        return;
//    }
//
//    // 添加音视频输入对象
//    // 对于音频来说 编码方式，采样率，采样格式，声道数，声道类型等等是必须的参数，比特率可以不用设置
//    // 对于食品来说 编码方式，视频宽和高则是必须参数
//    // 低端机型不支持H265编码
//    NSDictionary *videoSettings = @{
//        AVVideoCodecKey:AVVideoCodecHEVC,
//        AVVideoWidthKey:@(demensions.width),
//        AVVideoHeightKey:@(demensions.height)
//    };
//    AVAssetWriterInput *videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
//    videoInput.expectsMediaDataInRealTime = NO;
//    [writer addInput:videoInput];
//
//    // 获取音频相关参数
//    CMFormatDescriptionRef audioFormat = (__bridge CMFormatDescriptionRef)[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0].formatDescriptions[0];
//    // 备注，这个extensions并不是音频相关参数，不知道是什么。
////    CFDictionaryRef properties = CMFormatDescriptionGetExtensions(audioFormat);
//    // 获取音频相关参数
//    const AudioStreamBasicDescription *audioDes = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormat);
//    size_t layout_size = 0;
//    // 对于音频来说 编码方式，采样率，采样格式，声道数，声道类型等等是必须的参数，比特率可以不用设置
//    // 对于食品来说 编码方式，视频宽和高则是必须参数
//    const AudioChannelLayout *layout = CMAudioFormatDescriptionGetChannelLayout(audioFormat, &layout_size);
//    // ios 不支持mp3的编码
//    NSDictionary *audioSettings = @{
//        AVFormatIDKey:@(kAudioFormatMPEG4AAC),
//        AVSampleRateKey:@(audioDes->mSampleRate),
//        AVChannelLayoutKey:[NSData dataWithBytes:layout length:layout_size],
//        AVNumberOfChannelsKey:@(audioDes->mChannelsPerFrame),
//    };
//    AVAssetWriterInput *audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
//    /** 遇到问题：设置音频输入对象的expectsMediaDataInRealTime为YES，提示Domain=AVFoundationErrorDomain Code=-11800 "
//     *  The operation could not be completed"
//     *  分析原因：暂时没太明白，音视频采集的时候这个属性也都设置为YES了也没有问题，这里出问题
//     *  解决方案：将此属性设置为NO
//     */
//    audioInput.expectsMediaDataInRealTime = NO;
//    [writer addInput:audioInput];
//
//    //开启解封装和封装
//    if (![reader startReading]) {
//        NSLog(@"reader startReading failer %@",reader.error);
//        dispatch_semaphore_signal(semaphore);
//        return;
//    }
//    if (![writer startWriting]) {
//        NSLog(@"writer startWriting failer %@",writer.error);
//        dispatch_semaphore_signal(semaphore);
//        return;
//    }
//
//    AVAssetReaderOutput *videoOutput = nil,*audioOutput = nil;
//    for (AVAssetReaderOutput *output in reader.outputs) {
//        if ([output.mediaType isEqualToString:AVMediaTypeVideo]) {
//            videoOutput = output;
//        } else {
//            audioOutput = output;
//        }
//    }
//
//    __block BOOL firstWrite = YES;
//    __block BOOL videoFinish = NO;
//    __block BOOL audioFinish = NO;
//    // 配置写入音视频数据的工作队列
//    /** 遇到问题：模拟器发现内存消耗几个G，实际设备发现内存消耗正常
//     *  分析原因：模拟器用cpu指令模拟GPU，内存模拟GPU的内存,因为这里编解码都是用的gpu,所以模拟器看起来内存消耗非常高
//     *  解决方案：正常现象
//     */
//    [videoInput requestMediaDataWhenReadyOnQueue:vwriteQueue usingBlock:^{
//        while (videoInput.readyForMoreMediaData) {  // 说明可以开始写入视频数据了
//
//            if (reader.status == AVAssetReaderStatusReading) {
//                CMSampleBufferRef samplebuffer = [videoOutput copyNextSampleBuffer];
//
//                if (samplebuffer) {
//                    // 从视频输出对象中读取数据
//                    CMTime pts = CMSampleBufferGetOutputPresentationTimeStamp(samplebuffer);
//
//                    if (firstWrite) {
//                        firstWrite = NO;
//
//                        [writer startSessionAtSourceTime:pts];
//                    }
//
//                    // 向视频输入对象写入数据
//                    BOOL result = [videoInput appendSampleBuffer:samplebuffer];
//
//                    NSLog(@"video writer %d",result);
//                    if (!result) {
//                        NSLog(@"video writer error %@",writer.error);
//                    }
//                    CMSampleBufferInvalidate(samplebuffer);
//                    CFRelease(samplebuffer);
//                } else {
//                   NSLog(@"说明视频数据读取完毕");
//                   videoFinish = YES;
//
//                   // 源文件中视频数据读取完毕，那么就不需要继续写入视频数据了，将视频输入对象标记为结束
//                   [videoInput markAsFinished];
//               }
//            }
//        }
//
//        if (videoFinish && audioFinish) {
//            NSLog(@"真正结束了1");
//            [writer finishWritingWithCompletionHandler:^{
//                [reader cancelReading];
//                dispatch_semaphore_signal(self->semaphore);
//            }];
//        }
//    }];
//
//    // 配置写入音频数据的工作队列
//    [audioInput requestMediaDataWhenReadyOnQueue:awriteQueue usingBlock:^{
//        while (audioInput.readyForMoreMediaData) {  // 说明可以开始写入数据了
//
//            if (reader.status == AVAssetReaderStatusReading) {
//                CMSampleBufferRef samplebuffer = [audioOutput copyNextSampleBuffer];
//                if (samplebuffer) {
//
//                    // 从输出对象中读取数据
//                    CMTime pts = CMSampleBufferGetOutputPresentationTimeStamp(samplebuffer);
//
//                    if (firstWrite) {
//                        firstWrite = NO;
//
//                        [writer startSessionAtSourceTime:pts];
//                    }
//
//                    // 向视频输入对象写入数据
//                    BOOL result = [audioInput appendSampleBuffer:samplebuffer];
//                    NSLog(@"audio writer %d",result);
//                    if (!result) {
//                        NSLog(@"audio writer error %@",writer.error);
//                    }
//                    CMSampleBufferInvalidate(samplebuffer);
//                    CFRelease(samplebuffer);
//                } else {
//                    NSLog(@"说明音频数据读取完毕1111");
//                    audioFinish = YES;
//
//                    // 源文件中视频数据读取完毕，那么就不需要继续写入视频数据了，将视频输入对象标记为结束
//                    [audioInput markAsFinished];
//                }
//            }
//        }
//
//        if (videoFinish && audioFinish) {
//            NSLog(@"真正结束了2");
//            [writer finishWritingWithCompletionHandler:^{
//                [reader cancelReading];
//                dispatch_semaphore_signal(self->semaphore);
//            }];
//
//        }
//    }];
//}
//@end
