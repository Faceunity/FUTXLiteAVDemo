//
//  RoomUtil.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/12/11.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RoomUtil.h"
#import "TXLiveSDKTypeDef.h"
#import <sys/utsname.h>
#import "TXLiveBase.h"

@implementation RoomUtil
+ (NSString *)getDeviceModelName
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    //iPhone 系列
    if ([deviceModel isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([deviceModel isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([deviceModel isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([deviceModel isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([deviceModel isEqualToString:@"iPhone3,2"])    return @"Verizon iPhone 4";
    if ([deviceModel isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([deviceModel isEqualToString:@"iPhone5,1"])    return @"iPhone 5";
    if ([deviceModel isEqualToString:@"iPhone5,2"])    return @"iPhone 5";
    if ([deviceModel isEqualToString:@"iPhone5,3"])    return @"iPhone 5C";
    if ([deviceModel isEqualToString:@"iPhone5,4"])    return @"iPhone 5C";
    if ([deviceModel isEqualToString:@"iPhone6,1"])    return @"iPhone 5S";
    if ([deviceModel isEqualToString:@"iPhone6,2"])    return @"iPhone 5S";
    if ([deviceModel isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    if ([deviceModel isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([deviceModel isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([deviceModel isEqualToString:@"iPhone8,2"])    return @"iPhone 6s Plus";
    if ([deviceModel isEqualToString:@"iPhone9,1"])    return @"iPhone 7 (CDMA)";
    if ([deviceModel isEqualToString:@"iPhone9,3"])    return @"iPhone 7 (GSM)";
    if ([deviceModel isEqualToString:@"iPhone9,2"])    return @"iPhone 7 Plus (CDMA)";
    if ([deviceModel isEqualToString:@"iPhone9,4"])    return @"iPhone 7 Plus (GSM)";
    
    //iPod 系列
    if ([deviceModel isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([deviceModel isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([deviceModel isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([deviceModel isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([deviceModel isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    
    //iPad 系列
    if ([deviceModel isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([deviceModel isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([deviceModel isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([deviceModel isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([deviceModel isEqualToString:@"iPad2,4"])      return @"iPad 2 (32nm)";
    if ([deviceModel isEqualToString:@"iPad2,5"])      return @"iPad mini (WiFi)";
    if ([deviceModel isEqualToString:@"iPad2,6"])      return @"iPad mini (GSM)";
    if ([deviceModel isEqualToString:@"iPad2,7"])      return @"iPad mini (CDMA)";
    
    if ([deviceModel isEqualToString:@"iPad3,1"])      return @"iPad 3(WiFi)";
    if ([deviceModel isEqualToString:@"iPad3,2"])      return @"iPad 3(CDMA)";
    if ([deviceModel isEqualToString:@"iPad3,3"])      return @"iPad 3(4G)";
    if ([deviceModel isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    if ([deviceModel isEqualToString:@"iPad3,5"])      return @"iPad 4 (4G)";
    if ([deviceModel isEqualToString:@"iPad3,6"])      return @"iPad 4 (CDMA)";
    
    if ([deviceModel isEqualToString:@"iPad4,1"])      return @"iPad Air";
    if ([deviceModel isEqualToString:@"iPad4,2"])      return @"iPad Air";
    if ([deviceModel isEqualToString:@"iPad4,3"])      return @"iPad Air";
    if ([deviceModel isEqualToString:@"iPad5,3"])      return @"iPad Air 2";
    if ([deviceModel isEqualToString:@"iPad5,4"])      return @"iPad Air 2";
    if ([deviceModel isEqualToString:@"i386"])         return @"Simulator";
    if ([deviceModel isEqualToString:@"x86_64"])       return @"Simulator";
    
    if ([deviceModel isEqualToString:@"iPad4,4"]
        ||[deviceModel isEqualToString:@"iPad4,5"]
        ||[deviceModel isEqualToString:@"iPad4,6"])      return @"iPad mini 2";
    
    if ([deviceModel isEqualToString:@"iPad4,7"]
        ||[deviceModel isEqualToString:@"iPad4,8"]
        ||[deviceModel isEqualToString:@"iPad4,9"])      return @"iPad mini 3";
    
    return deviceModel;
}
@end


@implementation RoomLivePlayListenerWrapper

- (void)clear {
    _userID = nil;
    _delegate = nil;
    _playBeginBlock = nil;
    _playErrorBlock = nil;
}

- (void)onPlayEvent:(int)EvtID withParam:(NSDictionary*)param {
    if (EvtID == PLAY_EVT_PLAY_BEGIN) {
        if (_playBeginBlock) {
            _playBeginBlock();
            _playBeginBlock = nil;
        }
        
    } else if (EvtID == PLAY_ERR_NET_DISCONNECT || EvtID == PLAY_ERR_GET_RTMP_ACC_URL_FAIL) {  // 在实时模式下(连麦或者PK模式)下拉取加速流失败,将其当做网络断开来处理
        if (_playErrorBlock) {
            _playErrorBlock(PLAY_ERR_NET_DISCONNECT, [param valueForKey:EVT_MSG]);
            _playErrorBlock = nil;
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(onLivePlayEvent:withEvtID:andParam:)]) {
        [self.delegate onLivePlayEvent:self.userID withEvtID:EvtID andParam:param];
    }
}

- (void)onNetStatus:(NSDictionary*)param {
    if (self.delegate && [self.delegate respondsToSelector:@selector(onLivePlayNetStatus:withParam:)]) {
        [self.delegate onLivePlayNetStatus:self.userID withParam:param];
    }
}

@end




@implementation RoomStatisticInfo
- (instancetype)init {
    if (self = [super init]) {
        _str_appid                 = @"";
        _str_platform              = @"ios";
        _str_userid                = @"";
        _str_appversion            = [TXLiveBase getSDKVersionStr];
        _str_sdkversion            = [TXLiveBase getSDKVersionStr];
        _str_device                = [RoomUtil getDeviceModelName];
        _int32_report_type         = 0;    //0：RTCRoom     1：RoomService
        [self clean];
    }
    return self;
}

-(void) clean {
    _str_roomid                = @"";
    _str_room_creator          = @"";
    _str_streamid              = @"";
    _int64_ts_enter_room       = -1;
    _int64_tc_join_group       = -1;
    _int64_tc_get_pushers      = -1;
    _int64_tc_play_stream      = -1;
    _int64_tc_get_pushurl      = -1;
    _int64_tc_push_stream      = -1;
    _int64_tc_add_pusher       = -1;
    _int64_tc_enter_room       = -1;
    _str_common_version        = @"";   //公共库版本号，微信专用
    _str_username              = @"";
    _str_device_type           = @"";   //设备及OS版本号，微信专用
    _str_play_info             = @"";
    _str_push_info             = @"";
    
    _int64_ts_push_stream      = -1;
    _int64_ts_play_stream      = -1;
}

-(void) setStreamPushUrl: (NSString*) strStreamUrl {
    if (strStreamUrl == nil || strStreamUrl.length == 0) {
        return;
    }
    
    //推流地址格式：rtmp://8888.livepush.myqcloud.com/path/8888_test_12345_test?txSecret=aaaa&txTime=bbbb
    //拉流地址格式：rtmp://8888.liveplay.myqcloud.com/path/8888_test_12345_test
    //            http://8888.liveplay.myqcloud.com/path/8888_test_12345_test.flv
    //            http://8888.liveplay.myqcloud.com/path/8888_test_12345_test.m3u8
    
    NSString * strSubString = strStreamUrl;
    
    {
        //1 截取第一个 ？之前的子串
        NSString * strFind = @"?";
        NSRange range = [strSubString rangeOfString:strFind];
        if (range.location != NSNotFound) {
            strSubString = [strSubString substringToIndex:range.location];
        }
        if (strSubString == nil || strSubString.length == 0) {
            return;
        }
    }
    
    {
        //2 截取最后一个 / 之后的子串
        NSString * strFind = @"/";
        NSRange range = [strSubString rangeOfString:strFind options:NSBackwardsSearch];
        if (range.location != NSNotFound) {
            strSubString = [strSubString substringFromIndex:range.location + range.length];
        }
        if (strSubString == nil || strSubString.length == 0) {
            return;
        }
    }
    
    {
        //3 截取第一个 . 之前的子串
        NSString * strFind = @".";
        NSRange range = [strSubString rangeOfString:strFind];
        if (range.location != NSNotFound) {
            strSubString = [strSubString substringToIndex:range.location];
        }
        if (strSubString == nil || strSubString.length == 0) {
            return;
        }
    }
    
    _str_streamid = strSubString;
}

-(void) setPlayStreamBeginTS: (SInt64)ts {
    _int64_ts_play_stream = ts;
}

-(void) updatePlayStreamSuccessTS: (SInt64)ts {
    if (_int64_tc_play_stream == -1) {
        if (_int64_ts_play_stream != -1) {
            _int64_tc_play_stream = ts - _int64_ts_play_stream;
        }
        
        _int64_tc_enter_room = ts - _int64_ts_enter_room;
        
        if (_int64_tc_add_pusher != -1 && _int64_tc_play_stream != -1) { //加入房间成功
            [self reportStatisticInfo];
        }
    }
}

-(void) updateAddPusherSuccessTS: (SInt64)ts {
    _int64_tc_enter_room = ts - _int64_ts_enter_room;
    
    if (_int64_tc_add_pusher != -1 && _int64_tc_play_stream != -1) { //加入房间成功
        [self reportStatisticInfo];
    }
}

-(void) reportStatisticInfo {
    if (_str_appid.length == 0 || _str_userid.length == 0 || _str_roomid.length == 0) {
        return;
    }
    
    if (_int64_tc_add_pusher == -1 || _int64_tc_play_stream == -1) { //加入房间成功
        _int64_tc_enter_room = -1;
    }
    
    NSDictionary * param = @{
                             @"str_appid":               _str_appid,
                             @"str_platform":            _str_platform,
                             @"str_userid":              _str_userid,
                             @"str_roomid":              _str_roomid,
                             @"str_room_creator":        _str_room_creator,
                             @"str_streamid":            _str_streamid,
                             @"int64_ts_enter_room":     @(_int64_ts_enter_room),
                             @"int64_tc_join_group":     @(_int64_tc_join_group),
                             @"int64_tc_get_pushers":    @(_int64_tc_get_pushers),
                             @"int64_tc_play_stream":    @(_int64_tc_play_stream),
                             @"int64_tc_get_pushurl":    @(_int64_tc_get_pushurl),
                             @"int64_tc_push_stream":    @(_int64_tc_push_stream),
                             @"int64_tc_add_pusher":     @(_int64_tc_add_pusher),
                             @"int64_tc_enter_room":     @(_int64_tc_enter_room),
                             @"str_appversion":          _str_appversion,
                             @"str_sdkversion":          _str_sdkversion,
                             @"str_common_version":      _str_common_version,
                             @"str_nickname":            _str_username,
                             @"str_device":              _str_device,
                             @"str_device_type":         _str_device_type,
                             @"str_play_info":           _str_play_info,
                             @"str_push_info":           _str_push_info,
                             @"int32_report_type":       @(_int32_report_type),
                             };
    
    if (_delegate != nil && [_delegate respondsToSelector:@selector(onReportStatisticInfo:)]) {
        [_delegate onReportStatisticInfo: param];
    }
    
    [self clean];
}
@end
