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

@class RTC_OBJC_TYPE(RTCFrameDecryptor);

RTC_OBJC_EXPORT
@protocol RTC_OBJC_TYPE
(RTCFrameDecryptorDelegate)<NSObject>

/** Receives decryption events, should answer with decrypted data per frame */
- (nullable NSData *)frameDecryptor: (RTC_OBJC_TYPE (RTCFrameDecryptor) *)decryptor mediaType: (RTCRtpMediaType)mediaType withFrame: (NSData *)encrypted;

@end


RTC_OBJC_EXPORT
@protocol RTC_OBJC_TYPE
(RTCFrameDecryptor)<NSObject>

@property(nonatomic, weak) id<RTC_OBJC_TYPE(RTCFrameDecryptorDelegate)> delegate;

@end

RTC_OBJC_EXPORT
@interface RTC_OBJC_TYPE (RTCFrameDecryptor) : NSObject <RTC_OBJC_TYPE(RTCFrameDecryptor)>
/** Size change of frame after decryption (in bytes). Can be negative */
- (instancetype)initWithSizeChange: (int) sizeChange NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
