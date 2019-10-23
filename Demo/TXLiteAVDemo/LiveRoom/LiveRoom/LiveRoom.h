//
//  LiveRoom.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RoomDef.h"


/**
   事件回调: 房间关闭、Debug事件信息、出错说明
 */
@protocol LiveRoomListener <NSObject>
@optional

- (void)onRoomClose:(NSString *)roomID;

- (void)onDebugMsg:(NSString *)msg;

- (void)onError:(int)errCode errMsg:(NSString *)errMsg;


/**
   接收群文本消息
   @note 跟sendRoomTextMsg对应
 */
- (void)onRecvRoomTextMsg:(NSString *)roomID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar textMsg:(NSString *)textMsg;

/**
   接收群自定义消息
   @note 跟sendRoomCustomMsg对应
 */
- (void)onRecvRoomCustomMsg:(NSString *)roomID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar cmd:(NSString *)cmd msg:(NSString *)msg;

/**
   获取房间pusher列表的回调通知
 */
- (void)onGetPusherList:(NSArray<PusherInfo *> *)pusherInfoArray;

/**
   新的pusher加入直播(连麦)
 */
- (void)onPusherJoin:(PusherInfo *)pusherInfo;

/**
   pusher退出直播(连麦)的通知
 */
- (void)onPusherQuit:(PusherInfo *)pusherInfo;

/**
   大主播收到连麦请求
   @param userID    连麦请求者的userID
   @param userName  连麦请求者的昵称
   @param userAvatar   连麦请求者的头像URL
 */
- (void)onRecvJoinPusherRequest:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar;

/**
   小主播收到被大主播踢出连麦的通知
 */
- (void)onKickout;


/**
   主播收到PK请求
   @param userID     PK请求者的userID
   @param userName   PK请求者的昵称
   @param userAvatar PK请求者的头像URL
   @param streamUrl  PK请求者的流地址
 */
- (void)onRecvPKRequest:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar streamUrl:(NSString *)streamUrl;

/**
   主播收到结束PK的请求
   @param userID     PK请求者的userID
 */
- (void)onRecvPKFinishRequest:(NSString *)userID;

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
   加入直播的回调
 */
typedef void (^IJoinPusherCompletionHandler)(int errCode, NSString *errMsg);

/**
   退出直播的回调
 */
typedef void (^IQuitPusherCompletionHandler)(int errCode, NSString *errMsg);

/**
   小主播发起连麦请求的回调
   @param errCode 0表示成功，1表示拒绝，-1表示超时
   @param errMsg  消息说明
 */
typedef void (^IRequestJoinPusherCompletionHandler)(int errCode, NSString *errMsg);

/**
   主播发起PK请求的回调
   @param errCode 0表示成功，1表示拒绝，-1表示超时
   @param errMsg  消息说明
   @param streamUrl 若errCode为0，则streamUrl表示对方主播的播放流地址
 */
typedef void (^IRequestPKCompletionHandler)(int errCode, NSString *errMsg, NSString *streamUrl);

/**
   获取在线主播列表的回调
 */
typedef void (^IGetOnlinePusherListCompletionHandler)(NSArray<PusherInfo *> *pusherInfoArray);

/**
   获取房间列表的回调
   @param roomInfoArray 请求的房间列表信息
 */
typedef void (^IGetRoomListCompletionHandler)(int errCode, NSString *errMsg, NSArray<RoomInfo *> *roomInfoArray);

/**
   获取房间观众列表的回调
   @param audienceInfoArray 请求的房间观众列表信息
 */
typedef void (^IGetAudienceListCompletionHandler)(int errCode, NSString *errMsg, NSArray<AudienceInfo *> *audienceInfoArray);

/**
   播放开始的回调
 */
typedef void (^IPlayBegin)();

/**
   播放过程中发生错误时的回调
 */
typedef void (^IPlayError)(int errCode, NSString *errMsg);


@interface LiveRoom : NSObject

@property (nonatomic, weak) id<LiveRoomListener> delegate;

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
- (void)createRoom:(NSString *)roomID roomInfo: (NSString *)roomInfo withCompletion:(ICreateRoomCompletionHandler)completion;

/**
   进入房间
   @param roomID 房间号
   @param view 播放视频所在的区域
   @param completion 进入房间完成的回调
 */
- (void)enterRoom:(NSString *)roomID withView:(UIView *)view withCompletion:(IEnterRoomCompletionHandler)completion;

/**
   离开房间
 */
- (void)exitRoom:(IExitRoomCompletionHandler)completion;

/**
   加入直播
   @note 小主播在请求加入连麦成功后，调用该函数加入直播间推流
   @param completion 请求完成的回调
 */
- (void)joinPusher:(IJoinPusherCompletionHandler)completion;

/**
   退出直播
   @note 小主播主动退出连麦时调用，如果是被大主播踢掉，则无需调用
   @param completion 请求完成的回调
 */
- (void)quitPusher:(IQuitPusherCompletionHandler)completion;

/**
   小主播发起连麦请求
   @param timeout    超时时间，单位:秒
   @param completion 请求完成的回调
 */
- (void)requestJoinPusher:(NSInteger)timeout withCompletion:(IRequestJoinPusherCompletionHandler)completion;

/**
   大主播接受连麦请求
   @param userID  请求连麦者的userID
 */
- (void)acceptJoinPusher:(NSString *)userID;

/**
   大主播拒绝连麦请求
   @param userID  请求连麦者的userID
   @param reason  拒绝的理由，可以不填
 */
- (void)rejectJoinPusher:(NSString *)userID reason:(NSString *)reason;

/**
   大主播踢掉一个连麦的小主播
   @param userID  小主播的userID
 */
- (void)kickoutSubPusher:(NSString *)userID;

/**
   主播PK: 发起PK请求
   @param userID     其他房间主播的userID
   @param timeout    超时时间，单位:秒
   @param completion 请求完成的回调
 */
- (void)sendPKReques:(NSString *)userID timeout:(NSInteger)timeout withCompletion:(IRequestPKCompletionHandler)completion;

/**
   主播PK: 发送结束PK的请求
   @param userID     其他房间主播的userID
   @note: 不需要等对方回复
 */
- (void)sendPKFinishRequest:(NSString *)userID;

/**
   主播PK: 接受PK请求
   @param userID     其他房间主播的userID
 */
- (void)acceptPKRequest:(NSString *)userID;

/**
   主播PK: 拒绝PK请求
   @param userID  其他房间主播的userID
   @param reason  拒绝的理由，可以不填
 */
- (void)rejectPKRequest:(NSString *)userID reason:(NSString *)reason;

/**
   获取在线的主播列表(不包括自己)
 */
- (void)getOnlinePusherList:(IGetOnlinePusherListCompletionHandler)completion;

/**
   主播PK: 开始播放对方的流
   @param playUrl    要播放的流地址
   @param view       播放视频所在的区域
   @param playBegin  播放开始的回调
   @param playError  播放过程中发生错误时的回调
 */
- (void)startPlayPKStream:(NSString *)playUrl view:(UIView *)view playBegin:(IPlayBegin)playBegin playError:(IPlayError)playError;

/**
   主播PK: 结束PK
 */
- (void)stopPlayPKStream;

/**
   获取房间列表，分页获取
   @param index 获取的房间开始索引，从0开始计算
   @param cnt 获取的房间个数
   @param completion 拉取房间列表完成的回调，回调里返回获取的房间列表信息，如果个数小于cnt则表示已经拉取所有的房间列表
 */
- (void)getRoomList:(int)index cnt:(int)cnt withCompletion:(IGetRoomListCompletionHandler)completion;

/**
   获取某个房间里的观众列表（最多返回最近加入的 30 个观众）
   @param roomID 房间roomID
   @param completion 拉取房间观众列表完成的回调
 */
- (void)getAudienceList:(NSString *)roomID  withCompletion:(IGetAudienceListCompletionHandler)completion;

/**
   发送群文本消息
 */
- (void)sendRoomTextMsg:(NSString *)textMsg;

/**
   发送群自定义消息
 */
- (void)sendRoomCustomMsg:(NSString *)cmd msg:(NSString *)msg;

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
   @param view       播放视频所在的区域
   @param userID     要播放的成员ID
   @param playBegin  播放开始的回调
   @param playError  播放过程中发生错误时的回调
 */
- (void)addRemoteView:(UIView *)view withUserID:(NSString *)userID playBegin:(IPlayBegin)playBegin playError:(IPlayError)playError;

/**
   停止播放指定userID的视频
   @param userID 停止播放的成员ID
   @note 收到onPusherQuit事件后，内部会调用此函数停止播放该成员的视频，用户只需在UI层上层将对应的view销毁或者隐藏，改变显示布局
 */
- (void)deleteRemoteView:(NSString *)userID;

/**
   切换前后摄像头
 */
- (void)switchCamera;

/**
   打开闪关灯
   @param bEnable YES:打开  NO:关闭
 */
- (void)toggleTorch:(BOOL)bEnable;

/**
  设置静音推流
 */
- (void)setMute:(BOOL)isMute;

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


/* setBeautyLevel 设置美颜 和 美白 效果级别
 * 参数：
 
 *          beautyStyle     : TX_Enum_Type_BeautyStyle类型。
 *          beautyLevel     : 美颜级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 *          whitenessLevel  : 美白级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 *          ruddinessLevel  : 红润级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setBeautyStyle:(int)beautyStyle beautyLevel:(float)beautyLevel whitenessLevel:(float)whitenessLevel ruddinessLevel:(float)ruddinessLevel;

/* setEyeScaleLevel  设置大眼级别（特权版本有效，普通版本设置此参数无效）
 * 参数：
 *          eyeScaleLevel     : 大眼级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setEyeScaleLevel:(float)eyeScaleLevel;

/* setFaceScaleLevel  设置瘦脸级别（特权版本有效，普通版本设置此参数无效）
 * 参数：
 *          faceScaleLevel    : 瘦脸级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setFaceScaleLevel:(float)faceScaleLevel;

/* setFilter 设置指定素材滤镜特效
 * 参数：
 *          image     : 指定素材，即颜色查找表图片。注意：一定要用png格式！！！
 *          demo用到的滤镜查找表图片位于RTMPiOSDemo/RTMPiOSDemo/resource／FilterResource.bundle中
 */
- (void)setFilter:(UIImage *)image;

/* setSpecialRatio 设置滤镜效果程度
 * 参数：
 *          specialValue     : 从0到1，越大滤镜效果越明显，默认取值0.5
 */
- (void)setSpecialRatio:(float)specialValue;


/* setFaceVLevel  设置V脸（特权版本有效，普通版本设置此参数无效）
 * 参数：
 *          faceVLevel    : V脸级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setFaceVLevel:(float)faceVLevel;

/* setChinLevel  设置下巴拉伸或收缩（特权版本有效，普通版本设置此参数无效）
 * 参数：
 *          chinLevel    : 下巴拉伸或收缩级别取值范围 -9 ~ 9； 0 表示关闭 -9收缩 ~ 9拉伸。
 */
- (void)setChinLevel:(float)chinLevel;

/* setFaceShortLevel  设置短脸（特权版本有效，普通版本设置此参数无效）
 * 参数：
 *          faceShortlevel    : 短脸级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setFaceShortLevel:(float)faceShortlevel;

/* setNoseSlimLevel  设置瘦鼻（特权版本有效，普通版本设置此参数无效）
 * 参数：
 *          noseSlimLevel    : 瘦鼻级别取值范围 0 ~ 9； 0 表示关闭 1 ~ 9值越大 效果越明显。
 */
- (void)setNoseSlimLevel:(float)noseSlimLevel;

/**
 * 设置绿幕文件。仅增值版有效
 *
 * @param file 绿幕文件路径。支持mp4; nil 关闭绿幕
 */
- (void)setGreenScreenFile:(NSURL *)file;

/**
 * 选择动效。仅增值版有效
 *
 * @param tmplName 动效名称
 * @param tmplDir 动效所在目录
 */
- (void)selectMotionTmpl:(NSString *)tmplName inDir:(NSString *)tmplDir;


/* 以下接口用于混音处理，背景音与Mic采集到的人声混合
 * playBGM 播放背景音乐
 * @param path: 音乐文件路径，一定要是app对应的document目录下面的路径，否则文件会读取失败
 */
- (BOOL)playBGM:(NSString *)path;

/**
 * playBGM 播放背景音乐
 * @param path 音乐文件路径，一定要是app对应的document目录下面的路径，否则文件会读取失败
 * @param beginNotify 音乐播放开始的回调通知
 * @param progressNotify 音乐播放的进度通知，单位毫秒
 * @param completeNotify 音乐播放结束的回调通知
 */
- (BOOL)playBGM:(NSString *)path
        withBeginNotify:(void (^)(NSInteger errCode))beginNotify
        withProgressNotify:(void (^)(NSInteger progressMS, NSInteger durationMS))progressNotify
        andCompleteNotify:(void (^)(NSInteger errCode))completeNotify;

/**
 * 停止播放背景音乐
 */
- (BOOL)stopBGM;

/**
 * 暂停播放背景音乐
 */
- (BOOL)pauseBGM;

/**
 * 继续播放背景音乐
 */
- (BOOL)resumeBGM;

/**
 * 获取音乐文件总时长，单位毫秒
 * @param path 音乐文件路径，如果path为空，那么返回当前正在播放的music时长
 */
- (int)getMusicDuration:(NSString *)path;

/* setMicVolume 设置麦克风的音量大小，播放背景音乐混音时使用，用来控制麦克风音量大小
 * @param volume: 音量大小，1为正常音量，建议值为0~2，如果需要调大音量可以设置更大的值
 */
- (BOOL)setMicVolume:(float)volume;

/* setBGMVolume 设置背景音乐的音量大小，播放背景音乐混音时使用，用来控制背景音音量大小
 * @param volume: 音量大小，1为正常音量，建议值为0~2，如果需要调大背景音量可以设置更大的值
 */
- (BOOL)setBGMVolume:(float)volume;


@end
