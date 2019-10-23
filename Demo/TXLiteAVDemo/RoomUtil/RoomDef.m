//
//  RoomDef.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/21.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RoomDef.h"

@implementation LoginInfo
@end

@implementation SelfAccountInfo
@end

@implementation PusherInfo
- (NSString *)description {
    return [NSString stringWithFormat:@"userID[%@] playUrl:[%@]", _userID, _playUrl];
}
@end

@implementation AudienceInfo
@end

@implementation RoomInfo
- (instancetype)init {
    if (self = [super init]) {
        _pusherInfoArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"roomID[%@] roomName[%@] roomCreator[%@] mixedPlayURL[%@] pusherInfoArray[%@]", _roomID, _roomName, _roomCreator, _mixedPlayURL, _pusherInfoArray];
}
@end
