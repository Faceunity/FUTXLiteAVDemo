//
//  RTCDoubleRoomViewController.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/16.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RTCRoom.h"

@interface RTCDoubleRoomViewController : UIViewController <RTCRoomListener, UITextFieldDelegate>

@property (nonatomic, weak)    RTCRoom*           rtcRoom;
@property (nonatomic, copy)    NSString*          roomName;
@property (nonatomic, copy)    NSString*          roomID;
@property (nonatomic, copy)    NSString*          userName;
@property (nonatomic, assign)  int                entryType;  // UI点击入口， 为1表示从新建房间跳过来的，为2表示从点击房间列表过来的

@end

