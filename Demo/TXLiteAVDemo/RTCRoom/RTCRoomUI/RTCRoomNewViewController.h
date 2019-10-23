//
//  RTCRoomNewViewController.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/10.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RTCRoom.h"

@interface RTCRoomNewViewController : UIViewController

@property (nonatomic, weak)    RTCRoom*          rtcRoom;
@property (nonatomic, copy)    NSString*         userName;
@property (nonatomic, assign)  NSInteger         roomType;  // 1表示双人房间，2表示多人房间

@end
