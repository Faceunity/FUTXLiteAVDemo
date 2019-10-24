//
//  TIMComm.h
//  ImSDK
//
//  Created by bodeng on 29/1/15.
//  Copyright (c) 2015 tencent. All rights reserved.
//

#ifndef ImSDK_TIMComm_h
#define ImSDK_TIMComm_h

#import <Foundation/Foundation.h>

#define ERR_IMSDK_KICKED_BY_OTHERS      6208

@protocol TIMUserStatusListener;
@class TIMMessage;
@class TIMConversation;
@class TIMAPNSConfig;

#pragma mark - 枚举类型

/**
 * 日志级别
 */
typedef NS_ENUM(NSInteger, TIMLogLevel) {
    TIM_LOG_NONE                = 0,
    TIM_LOG_ERROR               = 1,
    TIM_LOG_WARN                = 2,
    TIM_LOG_INFO                = 3,
    TIM_LOG_DEBUG               = 4,
};

/**
 * 会话类型：
 *      C2C     双人聊天
 *      GROUP   群聊
 */
typedef NS_ENUM(NSInteger, TIMConversationType) {
    /**
     *  C2C 类型
     */
    TIM_C2C              = 1,
    
    /**
     *  群聊 类型
     */
    TIM_GROUP            = 2,
    
    /**
     *  系统消息
     */
    TIM_SYSTEM           = 3,
};

/**
 *  消息状态
 */
typedef NS_ENUM(NSInteger, TIMMessageStatus){
    /**
     *  消息发送中
     */
    TIM_MSG_STATUS_SENDING              = 1,
    /**
     *  消息发送成功
     */
    TIM_MSG_STATUS_SEND_SUCC            = 2,
    /**
     *  消息发送失败
     */
    TIM_MSG_STATUS_SEND_FAIL            = 3,
};

/**
 *  消息优先级标识
 */
typedef NS_ENUM(NSInteger, TIMMessagePriority) {
    /**
     *  高优先级，一般为红包或者礼物消息
     */
    TIM_MSG_PRIORITY_HIGH               = 1,
    /**
     *  普通优先级，普通消息
     */
    TIM_MSG_PRIORITY_NORMAL             = 2,
    /**
     *  低优先级，一般为点赞消息
     */
    TIM_MSG_PRIORITY_LOW                = 3,
    /**
     *  最低优先级，一般为后台下发的成员进退群通知
     */
    TIM_MSG_PRIORITY_LOWEST             = 4,
};

typedef NS_ENUM(NSInteger, TIMLoginStatus) {
    /**
     *  已登陆
     */
    TIM_STATUS_LOGINED             = 1,
    
    /**
     *  登陆中
     */
    TIM_STATUS_LOGINING            = 2,
    
    /**
     *  无登陆
     */
    TIM_STATUS_LOGOUT              = 3,
};

typedef NS_ENUM(NSInteger, TIMOfflinePushFlag) {
    /**
     *  按照默认规则进行推送
     */
    TIM_OFFLINE_PUSH_DEFAULT    = 0,
    /**
     *  不进行推送
     */
    TIM_OFFLINE_PUSH_NO_PUSH    = 1,
};

typedef NS_ENUM(NSInteger, TIMAndroidOfflinePushNotifyMode) {
    /**
     *  通知栏消息
     */
    TIM_ANDROID_OFFLINE_PUSH_NOTIFY_MODE_NOTIFICATION = 0x00,
    /**
     *  不弹窗，由应用自行处理
     */
    TIM_ANDROID_OFFLINE_PUSH_NOTIFY_MODE_CUSTOM = 0x01,
};

/**
 *  群Tips类型
 */
typedef NS_ENUM(NSInteger, TIM_GROUP_TIPS_TYPE){
    /**
     *  邀请加入群 (opUser & groupName & userList)
     */
    TIM_GROUP_TIPS_TYPE_INVITE              = 0x01,
    /**
     *  退出群 (opUser & groupName & userList)
     */
    TIM_GROUP_TIPS_TYPE_QUIT_GRP            = 0x02,
    /**
     *  踢出群 (opUser & groupName & userList)
     */
    TIM_GROUP_TIPS_TYPE_KICKED              = 0x03,
    /**
     *  设置管理员 (opUser & groupName & userList)
     */
    TIM_GROUP_TIPS_TYPE_SET_ADMIN           = 0x04,
    /**
     *  取消管理员 (opUser & groupName & userList)
     */
    TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN        = 0x05,
    /**
     *  群资料变更 (opUser & groupName & introduction & notification & faceUrl & owner)
     */
    TIM_GROUP_TIPS_TYPE_INFO_CHANGE         = 0x06,
    /**
     *  群成员资料变更 (opUser & groupName & memberInfoList)
     */
    TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE         = 0x07,
};

/**
 *  群系统消息类型
 */
typedef NS_ENUM(NSInteger, TIM_GROUP_SYSTEM_TYPE){
    /**
     *  申请加群请求（只有管理员会收到）
     */
    TIM_GROUP_SYSTEM_ADD_GROUP_REQUEST_TYPE              = 0x01,
    /**
     *  申请加群被同意（只有申请人能够收到）
     */
    TIM_GROUP_SYSTEM_ADD_GROUP_ACCEPT_TYPE               = 0x02,
    /**
     *  申请加群被拒绝（只有申请人能够收到）
     */
    TIM_GROUP_SYSTEM_ADD_GROUP_REFUSE_TYPE               = 0x03,
    /**
     *  被管理员踢出群（只有被踢的人能够收到）
     */
    TIM_GROUP_SYSTEM_KICK_OFF_FROM_GROUP_TYPE            = 0x04,
    /**
     *  群被解散（全员能够收到）
     */
    TIM_GROUP_SYSTEM_DELETE_GROUP_TYPE                   = 0x05,
    /**
     *  创建群消息（创建者能够收到）
     */
    TIM_GROUP_SYSTEM_CREATE_GROUP_TYPE                   = 0x06,
    /**
     *  邀请入群通知(被邀请者能够收到)
     */
    TIM_GROUP_SYSTEM_INVITED_TO_GROUP_TYPE               = 0x07,
    /**
     *  主动退群（主动退群者能够收到）
     */
    TIM_GROUP_SYSTEM_QUIT_GROUP_TYPE                     = 0x08,
    /**
     *  设置管理员(被设置者接收)
     */
    TIM_GROUP_SYSTEM_GRANT_ADMIN_TYPE                    = 0x09,
    /**
     *  取消管理员(被取消者接收)
     */
    TIM_GROUP_SYSTEM_CANCEL_ADMIN_TYPE                   = 0x0a,
    /**
     *  群已被回收(全员接收)
     */
    TIM_GROUP_SYSTEM_REVOKE_GROUP_TYPE                   = 0x0b,
    /**
     *  邀请入群请求(被邀请者接收)
     */
    TIM_GROUP_SYSTEM_INVITE_TO_GROUP_REQUEST_TYPE        = 0x0c,
    /**
     *  邀请加群被同意(只有发出邀请者会接收到)
     */
    TIM_GROUP_SYSTEM_INVITE_TO_GROUP_ACCEPT_TYPE         = 0x0d,
    /**
     *  邀请加群被拒绝(只有发出邀请者会接收到)
     */
    TIM_GROUP_SYSTEM_INVITE_TO_GROUP_REFUSE_TYPE         = 0x0e,
    /**
     *  用户自定义通知(默认全员接收)
     */
    TIM_GROUP_SYSTEM_CUSTOM_INFO                         = 0xff,
};

#pragma mark - block回调

/**
 *  一般操作成功回调
 */
typedef void (^TIMSucc)();

/**
 *  操作失败回调
 *
 *  @param code 错误码
 *  @param msg  错误描述，配合错误码使用，如果问题建议打印信息定位
 */
typedef void (^TIMFail)(int code, NSString * msg);

/**
 *  登陆成功回调
 */
typedef void (^TIMLoginSucc)();

/**
 *  APNs推送配置更新成功回调
 *
 *  @param config 配置
 */
typedef void (^TIMAPNSConfigSucc)(TIMAPNSConfig* config);

/**
 *  群创建成功
 *
 *  @param groupId 群组Id
 */
typedef void (^TIMCreateGroupSucc)(NSString * groupId);

#pragma mark - 基本类型

@interface TIMCodingModel : NSObject <NSCoding>

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

@end

@interface TIMSdkConfig : NSObject

/**
 *  用户标识接入SDK的应用ID，必填
 */
@property(nonatomic,assign) int sdkAppId;

/**
 *  用户的账号类型，必填
 */
@property(nonatomic,strong) NSString * accountType;

/**
 *  禁用crash上报，默认上报
 */
@property(nonatomic,assign) BOOL disableCrashReport;

/**
 *  禁止在控制台打印log
 */
@property(nonatomic,assign) BOOL disableLogPrint;

/**
 *  本地写log文件的等级，默认DEBUG等级
 */
@property(nonatomic,assign) TIMLogLevel logLevel;

/**
 *  log文件路径，不设置时为默认路径
 */
@property(nonatomic,strong) NSString * logPath;


@end


@interface TIMUserConfig : NSObject

/**
 *  用户登录状态监听器
 */
@property(nonatomic,strong) id<TIMUserStatusListener> userStatusListener;


@end

/**
 *  登陆信息
 */

@interface TIMLoginParam : NSObject

/**
 * 用户名
 */
@property(nonatomic,strong) NSString* identifier;

/**
 *  鉴权Token
 */
@property(nonatomic,strong) NSString* userSig;

/**
 *  App用户使用OAuth授权体系分配的Appid
 */
@property(nonatomic,strong) NSString* appidAt3rd;


@end

/**
 *  APNs 配置
 */
@interface TIMAPNSConfig : NSObject
/**
 *  是否开启推送：0-不进行设置 1-开启推送 2-关闭推送
 */
@property(nonatomic,assign) uint32_t openPush;
/**
 *  C2C消息声音,不设置传入nil
 */
@property(nonatomic,strong) NSString * c2cSound;

/**
 *  Group消息声音,不设置传入nil
 */
@property(nonatomic,strong) NSString * groupSound;

/**
 *  Video声音,不设置传入nil
 */
@property(nonatomic,strong) NSString * videoSound;

@end

/**
 *  SetToken 参数
 */
@interface TIMTokenParam : NSObject
/**
 *  获取的客户端Token信息
 */
@property(nonatomic,strong) NSData* token;
/**
 *  业务ID，传递证书时分配
 */
@property(nonatomic,assign) uint32_t busiId;

@end


/**
 *  切后台参数
 */
@interface TIMBackgroundParam : NSObject

/**
 *  C2C 未读计数
 */
@property(nonatomic,assign) int c2cUnread;

/**
 *  群 未读计数
 */
@property(nonatomic,assign) int groupUnread;

@end

@interface TIMAndroidOfflinePushConfig : NSObject
/**
 *  离线推送时展示标签
 */
@property(nonatomic,strong) NSString * title;
/**
 *  Android离线Push时声音字段信息
 */
@property(nonatomic,strong) NSString * sound;
/**
 *  离线推送时通知形式
 */
@property(nonatomic,assign) TIMAndroidOfflinePushNotifyMode notifyMode;

@end

@interface TIMIOSOfflinePushConfig : NSObject
/**
 *  离线Push时声音字段信息
 */
@property(nonatomic,strong) NSString * sound;
/**
 *  忽略badge计数
 */
@property(nonatomic,assign) BOOL ignoreBadge;

@end

/**
 *  事件上报信息
 */
@interface TIMEventReportItem : NSObject
/**
 *  事件id
 */
@property(nonatomic,assign) uint32_t event;
/**
 *  错误码
 */
@property(nonatomic,assign) uint32_t code;
/**
 *  错误描述
 */
@property(nonatomic,strong) NSString * desc;
/**
 *  事件延迟（单位ms）
 */
@property(nonatomic,assign) uint32_t delay;

@end

#endif
