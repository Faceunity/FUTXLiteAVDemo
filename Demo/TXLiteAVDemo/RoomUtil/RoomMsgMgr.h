//
//  RoomMsgMgr.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/1.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RoomMsgMgrConfig : NSObject
@property (nonatomic, copy) NSString* userID;        // 后台分配的唯一ID
@property (nonatomic, assign) int     appID;         // IM登录的appid
@property (nonatomic, copy) NSString* accType;       // IM登录的账号类型
@property (nonatomic, copy) NSString* userSig;       // IM登录需要的签名
@property (nonatomic, copy) NSString* userName;      // 发送自定义文本消息时需要
@property (nonatomic, copy) NSString* userAvatar;    // 发送自定义文本消息时需要
@end


@protocol RoomMsgListener <NSObject>

// 接收群文本消息
- (void)onRecvGroupTextMsg:(NSString *)groupID userID:(NSString *)userID textMsg:(NSString *)textMsg userName:(NSString *)userName userAvatar:(NSString *)userAvatar;

// 接收到群成员变更消息
- (void)onMemberChange:(NSString *)groupID;

// 接收到房间解散消息
- (void)onGroupDelete:(NSString *)groupID;

@optional

// 接收到小主播的连麦请求
- (void)onRecvLinkMicRequest:(NSString *)groupID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar;

// 接收到大主播的连麦回应， result为YES表示同意连麦，为NO表示拒绝连麦
- (void)onRecvLinkMicResponse:(NSString *)groupID result:(BOOL)result message:(NSString *)message;

// 接收到被大主播的踢出连麦的消息
- (void)onRecvLinkMicKickout:(NSString *)groupID;

// 接收群自定义消息，cmd为自定义命令字，msg为自定义消息体(这里统一使用json字符串)
- (void)onRecvGroupCustomMsg:(NSString *)groupID userID:(NSString *)userID cmd:(NSString *)cmd msg:(NSString *)msg userName:(NSString *)userName userAvatar:(NSString *)userAvatar;

// 接收到PK请求
- (void)onRecvPKRequest:(NSString *)groupID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar streamUrl:(NSString *)streamUrl;

// 接收到PK请求回应, result为YES表示同意PK，为NO表示拒绝PK，若同意，则streamUrl为对方的播放流地址
- (void)onRecvPKResponse:(NSString *)groupID userID:(NSString *)userID result:(BOOL)result message:(NSString *)message streamUrl:(NSString *)streamUrl;

// 接收PK结束消息
- (void)onRecvPKFinishRequest:(NSString *)groupID userID:(NSString *)userID;

@end


typedef void (^IRoomMsgMgrCompletion)(int errCode, NSString *errMsg);


@interface RoomMsgMgr : NSObject

@property (nonatomic, weak) id<RoomMsgListener> delegate;


- (instancetype)initWithConfig:(RoomMsgMgrConfig *)config;

// 登录
- (void)login:(IRoomMsgMgrCompletion)completion;

// 登出
- (void)logout:(IRoomMsgMgrCompletion)completion;

// 创建房间
- (void)createRoom:(NSString *)groupID groupName:(NSString *)groupName completion:(IRoomMsgMgrCompletion)completion;

// 加入房间
- (void)enterRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion;

// 退出房间
- (void)leaveRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion;

// 发送群自定义消息
- (void)sendRoomCustomMsg:(NSString *)cmd msg:(NSString *)msg;

// 发送群文本消息
- (void)sendRoomTextMsg:(NSString *)textMsg;

// 向userID发起连麦请求
- (void)sendLinkMicRequest:(NSString *)userID;

// 向userID发起连麦响应, result为YES表示接收，为NO表示拒绝
- (void)sendLinkMicResponse:(NSString *)userID withResult:(BOOL)result andReason:(NSString *)reason;

// 群主向userID发出踢出连麦消息
- (void)sendLinkMicKickout:(NSString *)userID;

// 向userID发起PK请求
- (void)sendPKRequest:(NSString *)userID withAccelerateURL:(NSString *)accelerateURL;

// 请求结束PK
- (void)sendPKFinishRequest:(NSString *)userID;

// 接收PK
- (void)acceptPKRequest:(NSString *)userID withAccelerateURL:(NSString *)accelerateURL;

// 拒绝PK
- (void)rejectPKRequest:(NSString *)userID reason:(NSString *)reason;

@end
