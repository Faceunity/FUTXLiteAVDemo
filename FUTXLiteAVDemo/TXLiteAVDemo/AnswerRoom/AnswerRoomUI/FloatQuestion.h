//
//  FloatQuestion.h
//  TXLiteAVDemo
//
//  Created by annidyfeng on 2018/1/9.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QuestionModel : NSObject
@property NSString *question;
@property NSArray  *answerList;
@property int       correctIndex;
@property int64_t  timestamp;

- (NSString *)convertToJson;
- (void)convertFromJson:(NSDictionary *)json;

@end

@class FloatQuestion;

@protocol FloatQuestionDelegate <NSObject>
- (void)onMakeQuestion:(FloatQuestion *)view;
- (void)onMakeAnswser:(FloatQuestion *)view answer:(NSString *)answer;
@end

@interface FloatQuestion : UIView

@property (weak, nonatomic) id<FloatQuestionDelegate> delegate;
@property QuestionModel *model;
@property (nonatomic, readonly) NSInteger calcHeight;
@property (getter=isHiddenFooter) BOOL hiddenFooter;
@property (getter=isHiddenHeader) BOOL hiddenHeader;
- (void)setTimeout:(int)timeout;

@end
