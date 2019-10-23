//
//  TIMCallback.h
//  ImSDK
//
//  Created by bodeng on 30/3/15.
//  Copyright (c) 2015 tencent. All rights reserved.
//

#ifndef ImSDK_TIMCallback_h
#define ImSDK_TIMCallback_h

#import "TIMComm.h"

@class TIMMessage;

/**
 *  用户在线状态通知
 */
@protocol TIMUserStatusListener <NSObject>
@optional
/**
 *  踢下线通知
 */
- (void)onForceOffline;

/**
 *  断线重连失败
 */
- (void)onReConnFailed:(int)code err:(NSString*)err;

/**
 *  用户登录的userSig过期（用户需要重新获取userSig后登录）
 */
- (void)onUserSigExpired;
@end

/**
 *  消息回调
 */
@protocol TIMMessageListener <NSObject>
@optional
/**
 *  新消息回调通知
 *
 *  @param msgs 新消息列表，TIMMessage 类型数组
 */
- (void)onNewMessage:(NSArray*)msgs;
@end


#endif
