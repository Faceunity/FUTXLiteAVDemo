//
//  VideoConfigureViewController.m
//  TXLiteAVDemo
//
//  Created by zhangxiang on 2017/9/12.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "VideoConfigureViewController.h"
#import "VideoRecordViewController.h"
#import "ColorMacro.h"
#import "AppDelegate.h"
@interface VideoConfigureViewController ()<UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *backButtonTop;
@end

@implementation VideoConfigureViewController
{
    VideoConfigure *_videoConfig;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _textFieldKbps.delegate = self;
    _textFieldFps.delegate = self;
    _textFieldDuration.delegate = self;
    _videoConfig = [[VideoConfigure alloc] init];
    if ([UIDevice currentDevice].systemVersion.floatValue < 11) {
        self.backButtonTop.constant += 19;
    }
    [self setBtn:_btn11 selected:NO];
    [self setBtn:_btn43 selected:NO];
    [self setBtn:_btn169 selected:YES];
    [self setBtn:_btnLow selected:NO];
    [self setBtn:_btnMedium selected:YES];
    [self setBtn:_btnHigh selected:NO];
    [self setBtn:_btnCustom selected:NO];
    [self setBtn:_btnResolution selected:NO];
    [self setBtn:_btn360p selected:NO];
    [self setBtn:_btn540p selected:YES];
    [self setBtn:_btn720p selected:NO];
    [self setView:_viewKbps selected:NO];
    [self setView:_viewFps selected:NO];
    [self setView:_viewDuration selected:NO];
    [self setBtnEnable:NO];
    
    [self onClickMedium:nil];

    [_btnResolution setTitleColor:UIColorFromRGB(0x999999) forState:UIControlStateNormal];
    // Do any additional setup after loading the view from its nib.
    self.btn12.tag = Help_视频录制;
    [self.btn12 addTarget:[[UIApplication sharedApplication] delegate] action:@selector(clickHelp:) forControlEvents:UIControlEventTouchUpInside];
}

-(void)setBtn:(UIButton *)btn selected:(BOOL)selected
{
    if (selected) {
        [btn setTitleColor:UIColorFromRGB(0x0ACCAC) forState:UIControlStateNormal];
        btn.layer.borderWidth = 0.5;
        btn.layer.borderColor = UIColorFromRGB(0x0ACCAC).CGColor;
    }else{
        [btn setTitleColor:UIColorFromRGB(0xFFFFFF) forState:UIControlStateNormal];
        btn.layer.borderWidth = 0.5;
        btn.layer.borderColor = UIColorFromRGB(0x999999).CGColor;
    }
}
-(void)setView:(UIView *)view selected:(BOOL)selected
{
    if (selected) {
        view.layer.borderWidth = 0.5;
        view.layer.borderColor = UIColorFromRGB(0x0ACCAC).CGColor;
    }else{
        view.layer.borderWidth = 0.5;
        view.layer.borderColor = UIColorFromRGB(0x999999).CGColor;
    }
}

- (IBAction)popBack:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onClick11:(id)sender {
    [self setBtn:_btn11 selected:YES];
    [self setBtn:_btn43 selected:NO];
    [self setBtn:_btn169 selected:NO];
    _videoConfig.videoRatio = VIDEO_ASPECT_RATIO_1_1;
}

- (IBAction)onClick43:(id)sender {
    [self setBtn:_btn11 selected:NO];
    [self setBtn:_btn43 selected:YES];
    [self setBtn:_btn169 selected:NO];
    _videoConfig.videoRatio = VIDEO_ASPECT_RATIO_3_4;
}

- (IBAction)onClick169:(id)sender {
    [self setBtn:_btn11 selected:NO];
    [self setBtn:_btn43 selected:NO];
    [self setBtn:_btn169 selected:YES];
    _videoConfig.videoRatio = VIDEO_ASPECT_RATIO_9_16;
}

- (IBAction)onClickLow:(id)sender {
    [self setBtn:_btnLow selected:YES];
    [self setBtn:_btnMedium selected:NO];
    [self setBtn:_btnHigh selected:NO];
    [self setBtn:_btnCustom selected:NO];
    _videoConfig.bps = 2400;
    _videoConfig.fps = 30;
    _videoConfig.gop = 3;
    _textFieldKbps.text = [@(_videoConfig.bps) stringValue];
    _textFieldFps.text = [@(_videoConfig.fps) stringValue];
    _textFieldDuration.text = [@(_videoConfig.gop) stringValue];
    [self setBtnEnable:NO];
    [self onClick360:nil];
}

- (IBAction)onClickMedium:(id)sender {
    [self setBtn:_btnLow selected:NO];
    [self setBtn:_btnMedium selected:YES];
    [self setBtn:_btnHigh selected:NO];
    [self setBtn:_btnCustom selected:NO];
    [self setView:_viewKbps selected:NO];
    [self setView:_viewFps selected:NO];
    [self setView:_viewDuration selected:NO];
    [self setBtnEnable:NO];
    [self onClick540:nil];
    _videoConfig.bps = 6500;
    _videoConfig.fps = 30;
    _videoConfig.gop = 3;
    _textFieldKbps.text = [@(_videoConfig.bps) stringValue];
    _textFieldFps.text = [@(_videoConfig.fps) stringValue];
    _textFieldDuration.text = [@(_videoConfig.gop) stringValue];
}

- (IBAction)onClickHigh:(id)sender {
    [self setBtn:_btnLow selected:NO];
    [self setBtn:_btnMedium selected:NO];
    [self setBtn:_btnHigh selected:YES];
    [self setBtn:_btnCustom selected:NO];
    [self setView:_viewKbps selected:NO];
    [self setView:_viewFps selected:NO];
    [self setView:_viewDuration selected:NO];
    [self setBtnEnable:NO];
    [self onclick720:nil];
    _videoConfig.bps = 9600;
    _videoConfig.fps = 30;
    _videoConfig.gop = 3;
    _textFieldKbps.text = [@(_videoConfig.bps) stringValue];
    _textFieldFps.text = [@(_videoConfig.fps) stringValue];
    _textFieldDuration.text = [@(_videoConfig.gop) stringValue];
}

- (IBAction)onclickCustom:(id)sender {
    [self setBtn:_btnLow selected:NO];
    [self setBtn:_btnMedium selected:NO];
    [self setBtn:_btnHigh selected:NO];
    [self setBtn:_btnCustom selected:YES];
    [self setBtn:_btn360p selected:NO];
    [self setBtn:_btn540p selected:YES];
    [self setBtn:_btn720p selected:NO];
    [self setView:_viewKbps selected:YES];
    [self setView:_viewFps selected:NO];
    [self setView:_viewDuration selected:NO];
    [self setBtnEnable:YES];
    _textFieldKbps.text = @"600 ~ 12000";
    _textFieldFps.text = @"15 ~ 30";
    _textFieldDuration.text = @"1 ~ 10";
    _videoConfig.bps = 2400;
    _videoConfig.fps = 20;
    _videoConfig.gop = 3;
}

-(void)setBtnEnable:(BOOL)enabled
{
    _textFieldKbps.enabled = enabled;
    _textFieldFps.enabled = enabled;
    _textFieldDuration.enabled = enabled;
    _btn360p.enabled = enabled;
    _btn540p.enabled = enabled;
    _btn720p.enabled = enabled;
}

- (IBAction)onClick360:(id)sender {
    [self setBtn:_btn360p selected:YES];
    [self setBtn:_btn540p selected:NO];
    [self setBtn:_btn720p selected:NO];
    _videoConfig.videoResolution = VIDEO_RESOLUTION_360_640;
}

- (IBAction)onClick540:(id)sender {
    [self setBtn:_btn360p selected:NO];
    [self setBtn:_btn540p selected:YES];
    [self setBtn:_btn720p selected:NO];    _videoConfig.videoResolution = VIDEO_RESOLUTION_540_960;
}

- (IBAction)onclick720:(id)sender {
    [self setBtn:_btn360p selected:NO];
    [self setBtn:_btn540p selected:NO];
    [self setBtn:_btn720p selected:YES];
    _videoConfig.videoResolution = VIDEO_RESOLUTION_720_1280;
}

- (IBAction)startRecord:(id)sender {
    VideoRecordViewController *vc = [[VideoRecordViewController alloc] initWithConfigure:_videoConfig];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if ([textField isEqual:_textFieldKbps]) {
        [self setView:_viewKbps selected:YES];
        [self setView:_viewFps selected:NO];
        [self setView:_viewDuration selected:NO];
        _textFieldKbps.text = @"";
    }
    else if ([textField isEqual:_textFieldFps]){
        [self setView:_viewKbps selected:NO];
        [self setView:_viewFps selected:YES];
        [self setView:_viewDuration selected:NO];
        _textFieldFps.text = @"";
    }
    else if ([textField isEqual:_textFieldDuration]){
        [self setView:_viewKbps selected:NO];
        [self setView:_viewFps selected:NO];
        [self setView:_viewDuration selected:YES];
        _textFieldDuration.text = @"";
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    _videoConfig.bps = [_textFieldKbps.text intValue];
    _videoConfig.fps = [_textFieldFps.text intValue];
    _videoConfig.gop = [_textFieldDuration.text intValue];
    [_textFieldKbps resignFirstResponder];
    [_textFieldFps resignFirstResponder];
    [_textFieldDuration resignFirstResponder];
    return YES;
}

@end
