//
//  RTCMsgListTableViewCell.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/17.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RTCMsgModeType) {
    RTCMsgModeTypeSystem    =  1,    // 系统消息
    RTCMsgModeTypeOneself   =  2,    // 自己端发送的消息
    RTCMsgModeTypeOther     =  3,    // 其他人发送的消息
};


/**
   在双人房间消息列表用到
 */
@interface RTCMsgModel : NSObject
@property (nonatomic, assign)  RTCMsgModeType  type;      // 消息类型
@property (nonatomic, assign)  NSTimeInterval  time;      // 时间戳
@property (nonatomic, strong)  NSString*       userName;  // 用户昵称
@property (nonatomic, strong)  NSString*       userMsg;   // 用户消息
@property (nonatomic, assign)  NSInteger       msgHeight; // 布局时的消息高度
@property (nonatomic, strong)  NSAttributedString* attributedMsgText;
@end


/**
   消息列表cell，用于展示消息
 */
@interface RTCMsgListTableViewCell : UITableViewCell

// 刷新cell内容信息
- (void)refreshWithModel:(RTCMsgModel *)msgModel;

// 通过msgModel 获取消息列表每行的内容信息，通过返回的AttributedString计算cell的高度
+ (NSAttributedString *)getAttributedStringFromModel:(RTCMsgModel *)msgModel;

@end



