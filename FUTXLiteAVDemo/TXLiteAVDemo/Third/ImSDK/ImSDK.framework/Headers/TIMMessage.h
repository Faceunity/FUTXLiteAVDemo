//
//  TIMMessage.h
//  ImSDK
//
//  Created by bodeng on 28/1/15.
//  Copyright (c) 2015 tencent. All rights reserved.
//

#ifndef ImSDK_TIMMessage_h
#define ImSDK_TIMMessage_h


#import <Foundation/Foundation.h>

#import "TIMComm.h"
#import "TIMCallback.h"

@class TIMConversation;

/**
 *  消息Elem基类
 */
@interface TIMElem : NSObject
@end

#pragma mark - 普通消息Elem

/**
 *  文本消息Elem
 */
@interface TIMTextElem : TIMElem
/**
 *  消息文本
 */
@property(nonatomic,strong) NSString * text;

@end


/**
 *  自定义消息类型
 */
@interface TIMCustomElem : TIMElem

/**
 *  自定义消息二进制数据
 */
@property(nonatomic,strong) NSData * data;
/**
 *  自定义消息描述信息，做离线Push时文本展示（已废弃，请使用TIMMessage中offlinePushInfo进行配置）
 */
@property(nonatomic,strong) NSString * desc DEPRECATED_ATTRIBUTE;
/**
 *  离线Push时扩展字段信息（已废弃，请使用TIMMessage中offlinePushInfo进行配置）
 */
@property(nonatomic,strong) NSString * ext DEPRECATED_ATTRIBUTE;
/**
 *  离线Push时声音字段信息（已废弃，请使用TIMMessage中offlinePushInfo进行配置）
 */
@property(nonatomic,strong) NSString * sound DEPRECATED_ATTRIBUTE;
@end

#pragma mark - 群组消息Elem

/**
 *  群Tips
 */
@interface TIMGroupTipsElem : TIMElem

/**
 *  群组Id
 */
@property(nonatomic,strong) NSString * group;

/**
 *  群Tips类型
 */
@property(nonatomic,assign) TIM_GROUP_TIPS_TYPE type;

/**
 *  操作人用户名
 */
@property(nonatomic,strong) NSString * opUser;

/**
 *  被操作人列表 NSString* 数组
 */
@property(nonatomic,strong) NSArray * userList;

/**
 *  当前群人数： TIM_GROUP_TIPS_TYPE_INVITE、TIM_GROUP_TIPS_TYPE_QUIT_GRP、
 *             TIM_GROUP_TIPS_TYPE_KICKED时有效
 */
@property(nonatomic,assign) uint32_t memberNum;

@end

/**
 *  群系统消息
 */
@interface TIMGroupSystemElem : TIMElem

/**
 * 操作类型
 */
@property(nonatomic,assign) TIM_GROUP_SYSTEM_TYPE type;

/**
 * 群组Id
 */
@property(nonatomic,strong) NSString * group;

/**
 * 操作人
 */
@property(nonatomic,strong) NSString * user;

/**
 *  用户自定义透传消息体（type＝TIM_GROUP_SYSTEM_CUSTOM_INFO时有效）
 */
@property(nonatomic,strong) NSData * userData;


@end


#pragma mark - 消息体TIMMessage

/**
 填入sound字段表示接收时不会播放声音
 */
extern NSString * const kIOSOfflinePushNoSound;

@interface TIMOfflinePushInfo : NSObject
/**
 *  自定义消息描述信息，做离线Push时文本展示
 */
@property(nonatomic,strong) NSString * desc;
/**
 *  离线Push时扩展字段信息
 */
@property(nonatomic,strong) NSString * ext;
/**
 *  推送规则标志
 */
@property(nonatomic,assign) TIMOfflinePushFlag pushFlag;
/**
 *  iOS离线推送配置
 */
@property(nonatomic,strong) TIMIOSOfflinePushConfig * iosConfig;
/**
 *  Android离线推送配置
 */
@property(nonatomic,strong) TIMAndroidOfflinePushConfig * androidConfig;
@end


/**
 *  消息
 */
@interface TIMMessage : NSObject

/**
 *  增加Elem
 *
 *  @param elem elem结构
 *
 *  @return 0       表示成功
 *          1       禁止添加Elem（文件或语音多于两个Elem）
 *          2       未知Elem
 */
- (int)addElem:(TIMElem*)elem;

/**
 *  获取对应索引的Elem
 *
 *  @param index 对应索引
 *
 *  @return 返回对应Elem
 */
- (TIMElem*)getElem:(int)index;

/**
 *  获取Elem数量
 *
 *  @return elem数量
 */
- (int)elemCount;

/**
 *  设置离线推送配置信息
 *
 *  @param info 配置信息
 *
 *  @return 0 成功
 */
- (int)setOfflinePushInfo:(TIMOfflinePushInfo*)info;

/**
 *  获得本消息离线推送配置信息
 *
 *  @return 配置信息，没设置返回nil
 */
- (TIMOfflinePushInfo*)getOfflinePushInfo;

/**
 *  设置业务命令字
 *
 *  @param buzCmds 业务命令字列表
 *                 @"im_open_busi_cmd.msg_robot" 表示发送给IM机器人
 *                 @"im_open_busi_cmd.msg_nodb" 表示不存离线
 *                 @"im_open_busi_cmd.msg_noramble" 表示不存漫游
 *                 @"im_open_busi_cmd.msg_nopush" 表示不实时下发给用户
 *
 *  @return 0 成功
 */
- (int)setBusinessCmd:(NSArray*)buzCmds;

/**
 *  获取会话
 *
 *  @return 该消息所对应会话
 */
- (TIMConversation*)getConversation;

/**
 *  消息状态
 *
 *  @return TIMMessageStatus 消息状态
 */
- (TIMMessageStatus)status;

/**
 *  是否发送方
 *
 *  @return TRUE 表示是发送消息    FALSE 表示是接收消息
 */
- (BOOL)isSelf;

/**
 *  获取发送方
 *
 *  @return 发送方标识
 */
- (NSString*)sender;

/**
 *  消息Id
 */
- (NSString*)msgId;

/**
 *  获取消息uniqueId
 *
 *  @return uniqueId
 */
- (uint64_t)uniqueId;

/**
 *  当前消息的时间戳
 *
 *  @return 时间戳
 */
- (NSDate*)timestamp;

/**
 *  设置消息的优先级
 *
 *  @param priority 优先级
 *
 *  @return TRUE 设置成功
 */
- (BOOL)setPriority:(TIMMessagePriority)priority;

/**
 *  获取消息的优先级
 *
 *  @return 优先级
 */
- (TIMMessagePriority)getPriority;


@end

#endif
