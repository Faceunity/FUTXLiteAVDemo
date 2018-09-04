//
//  IMSdkInt.h
//  ImSDK
//
//  Created by tomzhu on 2017/8/11.
//  Copyright © 2017年 tencent. All rights reserved.
//

#ifndef IMSdkInt_h
#define IMSdkInt_h

#import <Foundation/Foundation.h>
#import "TIMComm.h"

#define ENABLE_AVSDK_SUPPORT

#ifdef ENABLE_AVSDK_SUPPORT

@interface OMErrResp : NSObject

@property(nonatomic,strong) NSString* cmd;
@property(nonatomic,strong) NSString* uin;
@property(nonatomic,assign) int seq;
@property(nonatomic,assign) int errCode;
@property(nonatomic,strong) NSString* errTips;

@end

/**
 *  UserId 结构，表示一个用户的账号信息
 */
@interface IMUserId : NSObject

@property(nonatomic,strong) NSString* uidtype;
@property(nonatomic,assign) unsigned int userappid;
@property(nonatomic,strong) NSString* userid;
@property(nonatomic,assign) unsigned long long tinyid;
@property(nonatomic,assign) unsigned long long uin;

@end

/**
 *  userid和tinyid 转换回包
 *  userList 存储IMUserId结构
 */
@interface OMUserIdResp : NSObject

@property(nonatomic,strong) NSArray* userList;

@end

/**
 *  音视频回调
 */
@interface OMCommandResp : NSObject

@property(nonatomic,strong) NSData* rspbody;

@end


/**
 *  一般多人音视频操作成功回调
 */
typedef void (^OMMultiSucc)();

/**
 *  一般多人音视频操作失败回调
 *
 *  @param code     错误码
 *  @param err      错误描述
 */
typedef void (^OMMultiFail)(int code, NSString * err);

// relay 回调
typedef int (^OMCommandSucc)(OMCommandResp *resp);

/**
 *  userid转换tinyid回调
 *
 *  @param resp 回包结构
 *
 *  @return 0 处理成功
 */
typedef int (^OMUserIdSucc)(OMUserIdResp *resp);

//请求回调
typedef int (^OMErr)(OMErrResp *resp);

// request 回调
typedef void (^OMRequestSucc)(NSData * data);
typedef void (^OMRequsetFail)(int code, NSString* msg);

#endif



/**
 *  音视频接口
 */
@interface IMSdkInt : NSObject

/**
 *  获取 IMSdkInt 全局对象
 *
 *  @return IMSdkInt 对象
 */
+ (IMSdkInt*)sharedInstance;

#ifdef ENABLE_AVSDK_SUPPORT

/**
 *  获取当前登陆用户 TinyID
 *
 *  @return tinyid
 */
- (unsigned long long)getTinyId;

/**
 *  引入IMBugly.framework时，设置componentId（仅AVSdk使用）
 *
 *  @param componentId 在Buly系统上申请的appid
 *  @param version     版本信息
 */
- (void)setBuglyComponentIdentifier:(NSString*)componentId version:(NSString*)version;

/**
 *  UserId 转 TinyId
 *
 *  @param userIdList userId列表，IMUserId 结构体
 *  @param succ       成功回调
 *  @param err        失败回调
 *
 *  @return 0 成功
 */
- (int)userIdToTinyId:(NSArray*)userIdList okBlock:(OMUserIdSucc)succ errBlock:(OMErr)err;

/**
 *  TinyId 转 UserId
 *
 *  @param tinyIdList tinyId列表，unsigned long long类型
 *  @param succ       成功回调
 *  @param err        失败回调
 *
 *  @return 0 成功
 */
- (int)tinyIdToUserId:(NSArray*)tinyIdList okBlock:(OMUserIdSucc)succ errBlock:(OMErr)err;

/**
 *  发送请求
 *
 *  @param cmd  命令字
 *  @param body 包体
 *  @param succ 成功回调，返回响应数据
 *  @param fail 失败回调，返回错误码
 *
 *  @return 0 发包成功
 */
- (int)request:(NSString*)cmd body:(NSData*)body succ:(OMRequestSucc)succ fail:(OMRequsetFail)fail;

/**
 *  多人音视频请求
 *
 *  @param reqbody 请求二进制数据
 *  @param succ    成功回调
 *  @param err     失败回调
 *
 *  @return 0 成功
 */
- (int)requestMultiVideoApp:(NSData*)reqbody okBlock:(OMCommandSucc)succ errBlock:(OMErr)err;
- (int)requestMultiVideoInfo:(NSData*)reqbody okBlock:(OMCommandSucc)succ errBlock:(OMErr)err;

/**
 *  多人音视频发送请求
 *
 *  @param serviceCmd 命令字
 *  @param reqbody    发送包体
 *  @param succ       成功回调
 *  @param err        失败回调
 *
 *  @return 0 成功
 */
- (int)requestOpenImRelay:(NSString*)serviceCmd req:(NSData*)reqbody okBlock:(OMCommandSucc)succ errBlock:(OMErr)err;

/**
 *  设置超时时间
 *
 *  @param timeout 超时时间（单位:s）
 */
- (void)setReqTimeout:(int)timeout;

/**
 *  发送质量上报请求
 *
 *  @param data  上报的数据
 *  @param type  上报数据类型
 *  @param succ  成功回调
 *  @param fail  失败回调，返回错误码
 *
 *  @return 0 发包成功
 */
- (int)requestQualityReport:(NSData*)data type:(unsigned int)type succ:(OMMultiSucc)succ fail:(OMMultiFail)fail;

/**
 * Crash 日志
 *
 * @param   level    日志级别
 * @param   tag      日志模块分类
 * @param   content  日志内容
 */
- (void)logBugly:(TIMLogLevel)level tag:(NSString*) tag log:(NSString*)content;

#endif

/**
 *  事件上报
 *
 *  @param item 事件信息
 *
 *  @return 0 成功
 */
- (int)reportEvent:(TIMEventReportItem*)item;

@end


#endif /* IMSdkInt_h */
