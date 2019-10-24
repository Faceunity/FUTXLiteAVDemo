//
//  RTCMsgListTableView.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/16.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RTCMsgListTableViewCell.h"


@interface RTCMsgListTableView : UITableView <UITableViewDelegate, UITableViewDataSource>

// 给消息列表发送一条消息用于展示
- (void)appendMsg:(RTCMsgModel *)msgModel;

@end
