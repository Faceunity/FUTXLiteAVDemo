//
//  RTCRoomTableViewCell.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/9.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RTCRoomTableViewCell : UITableViewCell

@property (nonatomic, copy)   NSString   *roomInfo;
@property (nonatomic, copy)   NSString   *roomID;
@property (nonatomic, assign) NSInteger  memberNum;

@end
