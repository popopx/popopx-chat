/*
 *  Copyright 2023 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>
#import <WebRTC/RTCMacros.h>

typedef NS_ENUM(NSInteger, RTCRtpMediaType);

NS_ASSUME_NONNULL_BEGIN

@class RTC_OBJC_TYPE(RTCFrameEncryptor);

RTC_OBJC_EXPORT
@protocol RTC_OBJC_TYPE
(RTCFrameEncryptorDelegate)<NSObject>

/** Receives encryption events, should answer with encrypted data per frame */
- (nullable NSData *)frameEncryptor: (RTC_OBJC_TYPE (RTCFrameEncryptor) *)encryptor mediaType: (RTCRtpMediaType)mediaType withFrame: (NSData *)unencrypted;

@end


RTC_OBJC_EXPORT
@protocol RTC_OBJC_TYPE
(RTCFrameEncryptor)<NSObject>

@property(nonatomic, weak) id<RTC_OBJC_TYPE(RTCFrameEncryptorDelegate)> delegate;

@end

RTC_OBJC_EXPORT
@interface RTC_OBJC_TYPE (RTCFrameEncryptor) : NSObject <RTC_OBJC_TYPE(RTCFrameEncryptor)>
/** Size change of frame after encryption (in bytes). Can be negative */
- (instancetype)initWithSizeChange: (int) sizeChange NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
