//
//  AnswerPlayIMCenter.h
//  TXLiteAVDemo_Enterprise
//
//  Created by tomzhu on 2018/1/18.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImSDK/ImSDK.h>

@protocol AnswerPlayIMCenterDelegate <NSObject>
@required

/**
 聊天消息回调

 @param message 消息内容
 @param userId 发送者ID
 */
- (void)onRecvChatMessage:(NSString *)message fromUser:(NSString *)userId;

/**
 问题消息回调

 @param message 题目消息内容
 */
- (void)onRecvIssueMessage:(NSData *)message;

/**
 群组删除回调
 */
- (void)onIMGroupDelete:(NSString *)groupId;

/**
 被其他设备踢下线
 */
- (void)onForceOffline;

/**
 登录的UserSig已过期
 */
- (void)onUserSigExpired;

/**
 重连失败

 @param code 错误码
 @param err 错误描述
 */
- (void)onReConnFailed:(int)code err:(NSString *)err;

@end

@interface AnswerPlayIMCenter : NSObject

@property(nonatomic, strong) id<AnswerPlayIMCenterDelegate> delegate;

/**
 获取IMCenter单例
 
 @return IMCenter对象
 */
+ (instancetype)getInstance;

/**
 初始化IMCenter（仅需初始化一次）
 
 @param sdkAppId 云通信控制台分配的sdkAppid
 @param accountType 云通信控制台分配的accounttype
 */
- (void)initIMCenter:(int)sdkAppId accountType:(NSString *)accountType;

/**
 登录IM用户
 
 @param loginParam 登录参数
 @param succ 成功回调
 @param fail 失败回调
 */
- (void)loginIMUser:(TIMLoginParam *)loginParam succ:(TIMSucc)succ fail:(TIMFail)fail;

/**
 登出IM用户
 */
- (void)logout;

/**
 发送聊天消息
 
 @param message 消息内容
 @param succ 成功回调
 @param fail 失败回调
 */
- (void)sendChatMessage:(NSString *)message succ:(TIMSucc)succ fail:(TIMFail)fail;

/**
 加入聊天群组和题目群组
 
 @param chatGroup 聊天群组的GroupID
 @param issueGroup 题目群组的GroupID
 @param succ 成功回调
 @param fail 失败回调
 */
- (void)joinIMGroup:(NSString *)chatGroup issueGroup:(NSString *)issueGroup succ:(TIMSucc)succ fail:(TIMFail)fail;

@end
