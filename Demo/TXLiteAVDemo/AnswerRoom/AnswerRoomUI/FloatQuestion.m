//
//  FloatQuestion.m
//  TXLiteAVDemo
//
//  Created by annidyfeng on 2018/1/9.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "FloatQuestion.h"
#import "Masonry.h"
#import "CircleProgressBar.h"

@implementation QuestionModel

- (NSString *)convertToJson {
    NSMutableString *str = [NSMutableString new];
    [str appendString:@"{"];
    [str appendFormat:@"\"question\":\"%@\",",self.question];
    for (int i = 0; i < self.answerList.count; i++) {
        [str appendFormat:@"\"answer_%d\":\"%@\",",i+1, self.answerList[i]];
    }
    [str appendFormat:@"\"correct_index\":\"%d\"",self.correctIndex];
    [str appendString:@"}"];
    return str;
}

- (void)convertFromJson:(NSDictionary *)json {
    
    self.question = json[@"question"];
    NSMutableArray *answer = [NSMutableArray new];
    if ([json objectForKey:@"answer_1"]) {
        [answer addObject:[json objectForKey:@"answer_1"]];
    }
    if ([json objectForKey:@"answer_2"]) {
        [answer addObject:[json objectForKey:@"answer_2"]];
    }
    if ([json objectForKey:@"answer_3"]) {
        [answer addObject:[json objectForKey:@"answer_3"]];
    }
    self.answerList = answer;
    self.timestamp = [[json objectForKey:@"timestamp"] intValue];
    self.correctIndex = [[json objectForKey:@"correct_index"] intValue];
    
    return;
}

@end


@interface FQHeaderView : UIView
@property UILabel *mainLabel;
@property CircleProgressBar *circleProgressBar;
@property int calcHeight;
@property int totoal;
@end

@implementation FQHeaderView
- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
//    self.mainLabel = [[UILabel alloc] initWithFrame:CGRectZero];
//    [self addSubview:self.mainLabel];
//    self.mainLabel.font = [UIFont systemFontOfSize:15];
//    self.mainLabel.textColor = [UIColor blueColor];
//    [self.mainLabel mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.center.equalTo(self);
//    }];
    
    self.circleProgressBar = [[CircleProgressBar alloc] initWithFrame:CGRectZero];
    
    [self addSubview:self.circleProgressBar];
    [self customizeAccording];
    [self.circleProgressBar setProgress:1 animated:NO];
    [self.circleProgressBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.width.mas_offset(@60);
        make.height.mas_offset(@60);
    }];
    
    self.calcHeight = 80;
    
    return self;
}

- (void)setShowTime:(int)pt {
    [self.circleProgressBar setProgress:(float)pt/self.totoal animated:YES duration:1];
}

- (void)customizeAccording {

    // Progress Bar Customization
    [_circleProgressBar setStartAngle:270];
    [_circleProgressBar setBackgroundColor:[UIColor clearColor]];
    [_circleProgressBar setProgressBarWidth:(3.0f)];
    [_circleProgressBar setProgressBarProgressColor:[UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:0.8]];
    [_circleProgressBar setProgressBarTrackColor:[UIColor lightTextColor]];
    // Hint View Customization
    [_circleProgressBar setHintViewSpacing:(3.0f)];
    [_circleProgressBar setHintViewBackgroundColor:[UIColor colorWithWhite:1.000 alpha:0.800]];
    [_circleProgressBar setHintTextFont:[UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:30.0f]];
    [_circleProgressBar setHintTextColor:[UIColor blackColor]];
    [_circleProgressBar setHintTextGenerationBlock:^NSString *(CGFloat progress) {
        return [NSString stringWithFormat:@"%d", (int)(progress * self.totoal)];
    }];
    
    // Attributed String
    [_circleProgressBar setHintAttributedGenerationBlock:^NSAttributedString *(CGFloat progress) {
        NSString *formatString = [NSString stringWithFormat:@"%d", (int)(progress * self.totoal)];
        NSMutableAttributedString * string = [[NSMutableAttributedString alloc] initWithString:formatString];
        [string addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-CondensedBlack" size:30.0f] range:NSMakeRange(0, string.length)];
        return string;
    }];
}


@end

@interface FQFooterView : UIView
@property UIButton *closeBtn;
@property int calcHeight;
@end

@implementation FQFooterView
- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    self.closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self addSubview:self.closeBtn];
    [self.closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
    
    self.calcHeight = 80;
    
    return self;
}
@end

// AnswerListView

@interface AnswerListView : UIView
@property int calcHeight;
@property (nonatomic) NSArray *answers;
@property (weak) id<FloatQuestionDelegate> delegate;
@property UIView *selectView;
@end

@implementation AnswerListView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.calcHeight = 150 + 24;
    
    return self;
}

- (void)setAnswers:(NSArray *)answers {
    
    for (UIView *view in [self.subviews copy]) {
        [view removeFromSuperview];
    }
    _answers = [answers copy];
    
    for (int i = 0; i < answers.count; i++) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
        view.layer.borderColor = [UIColor colorWithRed:0xe7/255.0 green:0xe7/255.0 blue:0xe7/255.0 alpha:1].CGColor;
        view.layer.borderWidth = 1;
        view.layer.cornerRadius = 25;
        view.layer.masksToBounds = YES;
        view.tag = i;
        UITapGestureRecognizer *singleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handleSingleTap:)];
        [view addGestureRecognizer:singleFingerTap];

        [self addSubview:view];
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(self);
            make.height.mas_equalTo(@50);
            make.top.mas_equalTo(@(i*(12+50)));
            make.centerX.equalTo(self);
        }];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        [view addSubview:label];
        label.text = answers[i];
        label.font = [UIFont systemFontOfSize:16];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(view).offset(30);
            make.centerY.equalTo(view);
        }];
    }
}

//The event handling method
- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
    int idx = (int)recognizer.view.tag;
    self.selectView.backgroundColor = [UIColor whiteColor];
    self.selectView = recognizer.view;
    self.selectView.backgroundColor = [UIColor colorWithRed:0xe7/255.0 green:0xe7/255.0 blue:0xe7/255.0 alpha:1];
    
    if (idx < self.answers.count) {
        if ([self.delegate respondsToSelector:@selector(onMakeAnswser:answer:)]) {
            [self.delegate onMakeAnswser:self.superview answer:self.answers[idx]];
        }
    }
}
@end


@interface FloatQuestion()
@property FQHeaderView *headerView;
@property UILabel *questionLabel;
@property AnswerListView *answerList;
@property FQFooterView *footerView;
@property NSTimer *countTimer;
@property int countSeconds;
@end

@implementation FloatQuestion

- (instancetype)initWithFrame:(CGRect)frame {
   
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    self.layer.cornerRadius = 18;
    self.layer.masksToBounds = YES;
    
    self.headerView = [[FQHeaderView alloc] initWithFrame:CGRectZero];
    [self addSubview:self.headerView];
    
    self.questionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.questionLabel.font = [UIFont systemFontOfSize:18];
    [self addSubview:self.questionLabel];
    
    self.answerList = [[AnswerListView alloc] initWithFrame:CGRectZero];
    [self addSubview:self.answerList];

    self.footerView = [[FQFooterView alloc] initWithFrame:CGRectZero];
    [self addSubview:self.footerView];
    
    [self.footerView.closeBtn addTarget:self action:@selector(onClose:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self);
        make.left.equalTo(self);
        make.right.equalTo(self);
        make.height.mas_equalTo(@(self.headerView.calcHeight));
    }];
    
    [self.questionLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.height.mas_greaterThanOrEqualTo(@80);
        make.top.mas_equalTo(self.headerView.mas_bottom);
    }];
    
    [self.answerList mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.mas_left).offset(10);
        make.right.mas_equalTo(self.mas_right).offset(-10);
        make.height.mas_equalTo(@(150+12*2));
        make.top.mas_equalTo(self.questionLabel.mas_bottom);
    }];
    
    [self.footerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.answerList.mas_bottom);
        make.left.equalTo(self);
        make.right.equalTo(self);
        make.height.mas_equalTo(@(self.footerView.calcHeight));
    }];
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
}

- (void)setModel:(QuestionModel *)model {
    _model = model;
    
    self.questionLabel.text = model.question;
    [self.answerList setAnswers:model.answerList];

    self.hidden = NO;
}

- (void)setTimeout:(int)timeout {
    self.countSeconds = timeout;
    self.headerView.totoal = timeout;
    [self.headerView.circleProgressBar setProgress:1 animated:NO];
    [self invalidateTimer];
    self.headerView.mainLabel.text = [NSString stringWithFormat:@"%d", timeout];
    self.countTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(countDown) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.countTimer forMode:NSDefaultRunLoopMode];
}

- (void)invalidateTimer {
    if (self.countTimer) {
        [self.countTimer invalidate];
    }
    self.countTimer = nil;
}

- (void)countDown {
    self.countSeconds --;
    if (self.countSeconds == 0) {
        [self invalidateTimer];
        self.hidden = YES;
    }
}

- (void)setCountSeconds:(int)countSeconds {
    _countSeconds = countSeconds;
    [self.headerView setShowTime:_countSeconds];
}

- (NSInteger)calcHeight {
    int height = 0;
    
    height += self.headerView.calcHeight;
    
    [self.questionLabel layoutIfNeeded];
    height += self.questionLabel.frame.size.height;
    
    height += self.answerList.calcHeight;
    
    if (self.hiddenFooter) {
        height += 30;
    } else {
        height += self.footerView.calcHeight;
    }
    
    return height;
}

- (void)setHiddenFooter:(BOOL)hiddenFooter {
    if (hiddenFooter) {
        [self.footerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(0);
        }];
    } else {
        [self.footerView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.mas_equalTo(@(self.footerView.calcHeight));
        }];
    }
    self.footerView.hidden = hiddenFooter;
}

- (BOOL)isHiddenFooter {
    return self.footerView.hidden;
}

- (void)setHiddenHeader:(BOOL)hiddenHeader {
    self.headerView.hidden = hiddenHeader;
}

- (BOOL)isHiddenHeader {
    return self.headerView.hidden;
}

- (void)setDelegate:(id<FloatQuestionDelegate>)delegate {
    _delegate = delegate;
    _answerList.delegate = delegate;
}

- (void)onQuestion:(UIButton *)btn {
    if ([self.delegate respondsToSelector:@selector(onMakeQuestion:)]) {
        [self.delegate onMakeQuestion:self];
    }
}

- (void)onClose:(UIButton *)btn {
    self.hidden = YES;
}
@end
