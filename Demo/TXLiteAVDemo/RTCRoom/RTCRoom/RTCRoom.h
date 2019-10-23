//
//  RTCRoom.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RoomDef.h"

/**
   事件回调: 房间pusher列表下发、pusher进入、pusher退出、房间关闭、Debug事件信息、出错说明、接收群文本消息
 */
@protocol RTCRoomListener <NSObject>

- (void)onGetPusherList:(NSArray<PusherInfo *> *)pusherInfoArray;

- (void)onPusherJoin:(PusherInfo *)pusherInfo;

- (void)onPusherQuit:(PusherInfo *)pusherInfo;

- (void)onRoomClose:(NSString *)roomID;

- (void)onDebugMsg:(NSString *)msg;

- (void)onError:(int)errCode errMsg:(NSString *)errMsg;

@optional
- (void)onRecvRoomTextMsg:(NSString *)roomID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar textMsg:(NSString *)textMsg;

@end



/**
   初始化IM等功能的回调
   @note: 初始化失败就不能创建和加入房间
 */
typedef void (^ILoginCompletionHandler)(int errCode, NSString *errMsg);

/**
 从RoomService后台登出回调
 */
typedef void (^ILogoutCompletionHandler)(int errCode, NSString *errMsg);

/**
   创建房间的回调
 */
typedef void (^ICreateRoomCompletionHandler)(int errCode, NSString *errMsg);

/**
   进入房间的回调
 */
typedef void (^IEnterRoomCompletionHandler)(int errCode, NSString *errMsg);

/**
   离开房间的回调
 */
typedef void (^IExitRoomCompletionHandler)(int errCode, NSString *errMsg);

/**
   获取房间列表的回调
   @param roomInfoArray 请求的房间列表信息
 */
typedef void (^IGetRoomListCompletionHandler)(int errCode, NSString *errMsg, NSArray<RoomInfo *> *roomInfoArray);

/**
 播放开始的回调
 */
typedef void (^IPlayBegin)();

/**
 播放过程中发生错误时的回调
 */
typedef void (^IPlayError)(int errCode, NSString *errMsg);


@interface RTCRoom : NSObject

@property (nonatomic, weak) id<RTCRoomListener> delegate;
    
/**
   初始化IM等功能，客户需要注册云通信账号，使用独立模式，IM签名信息及用户信息，客户在登录后台计算并通过登录协议返回
   @param serverDomain 服务器域名地址
   @param loginInfo 初始化信息
   @param completion 初始化完成的回调
*/
- (void)login:(NSString*)serverDomain loginInfo:(LoginInfo *)loginInfo withCompletion:(ILoginCompletionHandler)completion;

/**
 从Room后台登出
 @param completion 登出完成回调
 */
-(void)logout:(ILogoutCompletionHandler)completion;

/**
 创建房间
 @param roomID   房间ID，可以传空
 @param roomInfo 房间信息
 @param completion 房间创建完成的回调，里面会携带roomID
 */
- (void)createRoom:(NSString *)roomID roomInfo:(NSString *)roomInfo withCompletion:(ICreateRoomCompletionHandler)completion;

/**
   进入房间
   @param roomID 房间号
   @param completion 进入房间完成的回调
 */
- (void)enterRoom:(NSString *)roomID withCompletion:(IEnterRoomCompletionHandler)completion;

/**
   离开房间
 */
- (void)exitRoom:(IExitRoomCompletionHandler)completion;

/**
   获取房间列表，分页获取
   @param index 获取的房间开始索引，从0开始计算
   @param cnt 获取的房间个数
   @param completion 拉取房间列表完成的回调，回调里返回获取的房间列表信息，如果个数小于cnt则表示已经拉取所有的房间列表
 */
- (void)getRoomList:(int)index cnt:(int)cnt withCompletion:(IGetRoomListCompletionHandler)completion;

/**
   发送群文本消息
 */
- (void)sendRoomTextMsg:(NSString *)textMsg;

/**
   预览本地画面
   @param view 本地预览画面展示的区域
 */
- (void)startLocalPreview:(UIView *)view;

/**
   停止本地预览
 */
- (void)stopLocalPreview;

/**
 播放指定userID的视频
 @param view 播放视频所在的区域
 @userID     要播放的成员ID
 @playBegin  播放开始的回调
 @playError  播放过程中发生错误时的回调
 */
- (void)addRemoteView:(UIView *)view withUserID:(NSString *)userID playBegin:(IPlayBegin)playBegin playError:(IPlayError)playError;

/**
   停止播放指定userID的视频
   @userID 停止播放的成员ID
   @note 收到onPusherQuit事件后，内部会调用此函数停止播放该成员的视频，用户只需在UI层上层将对应的view销毁或者隐藏，改变显示布局
 */
- (void)deleteRemoteView:(NSString *)userID;

/**
   切换前后摄像头
 */
- (void)switchCamera;

/**
  设置静音推流
 */
- (void)setMute:(BOOL)isMute;

/**
   设置声音是否为高清晰度
   @param isHD YES: 48K采样，NO: 16K采样
 */
- (void)setHDAudio:(BOOL)isHD;

/**
   设置视频的码率区间
   @param minBitrate 最低码率
   @param maxBitrate 最高码率
 */
- (void)setBitrateRange:(int)minBitrate max:(int)maxBitrate;

/**
   从前台切到后台后会发送静音数据，同时发送默认画面
   @param pauseImage 要发送的默认画面图片
 */
- (void)switchToBackground:(UIImage *)pauseImage;

/**
   从后台回到前台的时候，调用此函数恢复推送camera采集的数据
 */
- (void)switchToForeground;

/**
   在渲染view上显示播放或推流状态统计及事件消息浮层
 */
- (void)showVideoDebugLog:(BOOL)isShow;

/**
   设置美颜 和 美白 效果级别
   @praram beautyStyle    取值为TX_Enum_Type_BeautyStyle
   @praram beautyLevel    美颜级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
   @praram whitenessLevel 美白级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
   @praram ruddinessLevel 红润级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setBeautyStyle:(int)beautyStyle beautyLevel:(float)beautyLevel whitenessLevel:(float)whitenessLevel ruddinessLevel:(float)ruddinessLevel;


@end
