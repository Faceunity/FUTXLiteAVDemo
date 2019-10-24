//
//  RoomUtil.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/12/11.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TXLivePlayListener.h"

@interface RoomUtil : NSObject
+ (NSString *)getDeviceModelName;
@end


/**
   播放开始的回调
 */
typedef void (^IPlayBeginBlock)();

/**
   播放过程中发生错误时的回调
 */
typedef void (^IPlayErrorBlock)(int errCode, NSString *errMsg);


@protocol IRoomLivePlayListener <NSObject>
@optional
-(void)onLivePlayEvent:(NSString*) userID withEvtID:(int)evtID andParam:(NSDictionary*)param;

@optional
-(void)onLivePlayNetStatus:(NSString*) userID withParam: (NSDictionary*) param;
@end


@interface RoomLivePlayListenerWrapper : NSObject <TXLivePlayListener>
@property (nonatomic, strong) NSString*   userID;
@property (nonatomic, weak) id<IRoomLivePlayListener> delegate;
@property (nonatomic, strong) IPlayBeginBlock playBeginBlock;
@property (nonatomic, strong) IPlayErrorBlock playErrorBlock;

- (void)clear;

@end


@protocol RoomReportDelegate <NSObject>
-(void)onReportStatisticInfo:(NSDictionary*)statisticInfo;
@end


@interface RoomStatisticInfo : NSObject
@property (nonatomic, weak) id<RoomReportDelegate> delegate;

@property(atomic, retain) NSString*  str_appid;
@property(atomic, retain) NSString*  str_platform;
@property(atomic, retain) NSString*  str_userid;
@property(atomic, retain) NSString*  str_roomid;
@property(atomic, retain) NSString*  str_room_creator;
@property(atomic, retain) NSString*  str_streamid;
@property(atomic, assign) SInt64     int64_ts_enter_room;
@property(atomic, assign) SInt64     int64_tc_join_group;
@property(atomic, assign) SInt64     int64_tc_get_pushers;
@property(atomic, assign) SInt64     int64_tc_play_stream;
@property(atomic, assign) SInt64     int64_tc_get_pushurl;
@property(atomic, assign) SInt64     int64_tc_push_stream;
@property(atomic, assign) SInt64     int64_tc_add_pusher;
@property(atomic, assign) SInt64     int64_tc_enter_room;
@property(atomic, retain) NSString*  str_appversion;
@property(atomic, retain) NSString*  str_sdkversion;
@property(atomic, retain) NSString*  str_common_version;    //公共库版本号，微信专用
@property(atomic, retain) NSString*  str_username;
@property(atomic, retain) NSString*  str_device;
@property(atomic, retain) NSString*  str_device_type;       //设备及OS版本号，微信专用
@property(atomic, retain) NSString*  str_play_info;
@property(atomic, retain) NSString*  str_push_info;
@property(atomic, assign) SInt32     int32_report_type;     //0：RTCRoom     1：RoomService

@property(atomic, assign) SInt64     int64_ts_push_stream;
@property(atomic, assign) SInt64     int64_ts_play_stream;

-(void) clean;
-(void) setStreamPushUrl: (NSString*) strStreamUrl;
-(void) setPlayStreamBeginTS: (SInt64)ts;
-(void) updatePlayStreamSuccessTS: (SInt64)ts;
-(void) updateAddPusherSuccessTS: (SInt64)ts;
-(void) reportStatisticInfo;
@end

