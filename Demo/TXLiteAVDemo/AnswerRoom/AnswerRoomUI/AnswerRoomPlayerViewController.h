//
//  AnswerRoomPlayerViewController.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/22.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AnswerRoom.h"

@interface AnswerRoomPlayerViewController : UIViewController <AnswerRoomListener, UITextFieldDelegate>

@property (nonatomic, weak)    AnswerRoom*          answerRoom;
@property (nonatomic, copy)    NSString*          roomName;
@property (nonatomic, copy)    NSString*          roomID;
@property (nonatomic, copy)    NSString*          nickName;

@end
