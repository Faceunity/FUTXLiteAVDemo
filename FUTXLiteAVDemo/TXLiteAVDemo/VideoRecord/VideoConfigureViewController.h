//
//  VideoConfigureViewController.h
//  TXLiteAVDemo
//
//  Created by zhangxiang on 2017/9/12.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoConfigureViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIButton *btn11;
@property (weak, nonatomic) IBOutlet UIButton *btn43;
@property (weak, nonatomic) IBOutlet UIButton *btn169;
@property (weak, nonatomic) IBOutlet UIButton *btnLow;
@property (weak, nonatomic) IBOutlet UIButton *btnMedium;
@property (weak, nonatomic) IBOutlet UIButton *btnHigh;
@property (weak, nonatomic) IBOutlet UIButton *btnCustom;
@property (weak, nonatomic) IBOutlet UIButton *btn360p;
@property (weak, nonatomic) IBOutlet UIButton *btn540p;
@property (weak, nonatomic) IBOutlet UIButton *btn720p;
@property (weak, nonatomic) IBOutlet UITextField *textFieldKbps;
@property (weak, nonatomic) IBOutlet UITextField *textFieldFps;
@property (weak, nonatomic) IBOutlet UITextField *textFieldDuration;
@property (weak, nonatomic) IBOutlet UIButton *btnResolution;
@property (weak, nonatomic) IBOutlet UIView *viewKbps;
@property (weak, nonatomic) IBOutlet UIView *viewFps;
@property (weak, nonatomic) IBOutlet UIView *viewDuration;
@property (weak, nonatomic) IBOutlet UIButton *btn12;
@end
