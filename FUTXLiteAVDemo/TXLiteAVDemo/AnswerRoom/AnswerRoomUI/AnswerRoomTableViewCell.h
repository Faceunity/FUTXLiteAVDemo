//
//  AnswerRoomTableViewCell.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/22.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AnswerRoomTableViewCell : UITableViewCell

@property (nonatomic, copy)   NSString   *roomName;
@property (nonatomic, copy)   NSString   *roomID;
@property (nonatomic, assign) NSInteger  memberNum;

@end
