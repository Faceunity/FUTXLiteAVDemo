//
//  AnswerRoom.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RoomDef.h"


/**
   事件回调: 房间关闭、Debug事件信息、出错说明、接收群文本消息
 */
@protocol AnswerRoomListener <NSObject>

- (void)onRoomClose:(NSString *)roomID;

- (void)onDebugMsg:(NSString *)msg;

- (void)onError:(int)errCode errMsg:(NSString *)errMsg;

@optional
- (void)onRecvRoomTextMsg:(NSString *)roomID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar textMsg:(NSString *)textMsg;

- (void)onPlayerMessage:(NSData *)msg;

@end



/**
   初始化IM等功能的回调
   @note: 初始化失败就不能创建和加入房间
 */
typedef void (^IInitCompletionHandler)(int errCode, NSString *errMsg);

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



@interface AnswerRoom : NSObject

@property (nonatomic, weak) id<AnswerRoomListener> delegate;

/**
   初始化IM等功能，客户需要注册云通信账号，使用独立模式，IM签名信息及用户信息，客户在登录后台计算并通过登录协议返回
   @param serverDomain 服务器域名地址
   @param userInfo IM及用户初始化信息
   @param completion 初始化完成的回调
 */
- (void)init:(NSString*)serverDomain accountInfo:(SelfAccountInfo *)userInfo withCompletion:(IInitCompletionHandler)completion;

/**
   创建房间
   @param roomName 房间名
   @param completion 房间创建完成的回调，里面会携带roomID
 */
- (void)createRoom:(NSString *)roomName withCompletion:(ICreateRoomCompletionHandler)completion;

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
   切换前后摄像头
 */
- (void)switchCamera;

- (void)sendMessage:(NSString *)mesg;

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
   设置推流端视频的分辨率
 */
- (void)setVideoRatio:(RoomVideoRatio)ratio;

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
 * @param file: 绿幕文件路径。支持mp4; nil 关闭绿幕
 */
- (void)setGreenScreenFile:(NSURL *)file;

/**
 * 选择动效。仅增值版有效
 *
 * @param tmplName: 动效名称
 * @param tmplDir: 动效所在目录
 */
- (void)selectMotionTmpl:(NSString *)tmplName inDir:(NSString *)tmplDir;


@end
