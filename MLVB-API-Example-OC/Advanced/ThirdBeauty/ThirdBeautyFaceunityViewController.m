//
//  ThirdBeautyViewController.m
//  MLVB-API-Example-OC
//
//  Created by adams on 2021/4/22.
//  Copyright © 2021 Tencent. All rights reserved.
//

/*
 第三方美颜功能示例
 MLVB APP 支持第三方美颜功能
 本文件展示如何集成第三方美颜功能
 1、打开扬声器 API:[self.livePusher startMicrophone];
 2、打开摄像头 API: [self.livePusher startCamera:true];
 3、开始推流 API：[self.livePusher startPush:url];
 4、开启自定义视频处理 API: [self.livePusher enableCustomVideoProcess:true pixelFormat:V2TXLivePixelFormatNV12 bufferType:V2TXLiveBufferTypePixelBuffer];
 5、使用第三方美颜SDK<Demo中使用的是Faceunity>: API: [[FUManager shareManager] renderItemsToPixelBuffer:srcFrame.pixelBuffer];

 参考文档：https://cloud.tencent.com/document/product/647/34066
 第三方美颜：https://github.com/Faceunity/FUTRTCDemo
 */
/*
 Third-Party Beauty Filter Example
 The MLVB app supports third-party beauty filters.
 This document shows how to integrate third-party beauty filters.
 1. Turn speaker on: [self.livePusher startMicrophone]
 2. Turn camera on: [self.livePusher startCamera:true]
 3. Start publishing: [self.livePusher startPush:url]
 4. Enable custom video processing: [self.livePusher enableCustomVideoProcess:true pixelFormat:V2TXLivePixelFormatNV12 bufferType:V2TXLiveBufferTypePixelBuffer]
 5. Use a third-party beauty filter SDK (FaceUnity is used in the demo): [[FUManager shareManager] renderItemsToPixelBuffer:srcFrame.pixelBuffer]

 Documentation: https://cloud.tencent.com/document/product/647/34066
 Third-party beauty filter: https://github.com/Faceunity/FUTRTCDemo
 */

#import "ThirdBeautyFaceunityViewController.h"
#import "FUDemoManager.h"


@interface ThirdBeautyFaceunityViewController () <V2TXLivePusherObserver>

@property (weak, nonatomic) IBOutlet UILabel *streamIdLabel;
@property (weak, nonatomic) IBOutlet UITextField *streamIdTextField;

@property (weak, nonatomic) IBOutlet UIButton *startPushStreamButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@property (strong, nonatomic) V2TXLivePusher *livePusher;

@end

@implementation ThirdBeautyFaceunityViewController

- (V2TXLivePusher *)livePusher {
    if (!_livePusher) {
        _livePusher = [[V2TXLivePusher alloc] initWithLiveMode:V2TXLiveMode_RTMP];
        [_livePusher setObserver:self];
    }
    return _livePusher;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupDefaultUIConfig];
    [self addKeyboardObserver];
    
}

- (void)viewDidAppear:(BOOL)animated{
    
    [self setupBeautySDK];
}

/// 相机切换
- (IBAction)cameraBtnClick:(UIButton *)sender {
    
    sender.selected = !sender.selected;
    [self.livePusher startCamera:!sender.selected];
    [FUDemoManager resetTrackedResult];
    [FUDemoManager shared].stickerH = !sender.selected;
    
}

- (void)setupDefaultUIConfig {
    self.streamIdTextField.text = [NSString generateRandomStreamId];
    
    self.streamIdLabel.text = localize(@"MLVB-API-Example.ThirdBeauty.streamIdInput");
    self.streamIdLabel.adjustsFontSizeToFitWidth = true;
    
    self.startPushStreamButton.backgroundColor = [UIColor themeBlueColor];
    [self.startPushStreamButton setTitle:localize(@"MLVB-API-Example.ThirdBeauty.startPush") forState:UIControlStateNormal];
    [self.startPushStreamButton setTitle:localize(@"MLVB-API-Example.ThirdBeauty.stopPush") forState:UIControlStateSelected];


}

- (void)setupBeautySDK {

    [FUDemoManager setupFUSDK];
    [FUDemoManager shared].stickerH = YES;
    [[FUDemoManager shared] addDemoViewToView:self.view originY:CGRectGetHeight(self.view.frame) - FUBottomBarHeight - FUSafaAreaBottomInsets() - 160];
}


- (void)startPush:(NSString*)streamId {
    self.title = streamId;
    [self.livePusher setRenderView:self.view];
    [self.livePusher startCamera:true];
    [self.livePusher startMicrophone];
    V2TXLiveVideoEncoderParam *param = [[V2TXLiveVideoEncoderParam alloc] init];
    param.videoFps = 30;
    param.videoBitrate = 1800;
    param.minVideoBitrate = 1000;
    param.videoResolution = V2TXLiveVideoResolution1280x720;
    param.videoResolutionMode = V2TXLiveVideoResolutionModePortrait;
    [self.livePusher setVideoQuality:param];

    [self.livePusher enableCustomVideoProcess:true pixelFormat:V2TXLivePixelFormatNV12 bufferType:V2TXLiveBufferTypePixelBuffer];
//    [self.livePusher startPush:@""];
    [self.livePusher startPush:[URLUtils generateRtmpPushUrl:streamId]];
}

- (void)stopPush {
    [self.livePusher stopCamera];
    [self.livePusher stopMicrophone];
    [self.livePusher stopPush];
}

#pragma mark - IBActions
- (IBAction)onPushStreamClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self startPush:self.streamIdTextField.text];
    } else {
        [self stopPush];
    }
}

#pragma mark - V2TXLivePusherObserver
- (void)onProcessVideoFrame:(V2TXLiveVideoFrame *)srcFrame dstFrame:(V2TXLiveVideoFrame *)dstFrame {
//    [[FUManager shareManager] renderItemsToPixelBuffer:srcFrame.pixelBuffer];
    
    if([FUDemoManager shared].shouldRender){
        
        [[FUTestRecorder shareRecorder] processFrameWithLog];
        [FUDemoManager updateBeautyBlurEffect];
        [[FUDemoManager shared] checkAITrackedResult];

        FURenderInput *input = [[FURenderInput alloc] init];
        // 处理效果对比问题
        input.renderConfig.imageOrientation = FUImageOrientationUP;
        input.pixelBuffer = srcFrame.pixelBuffer;
        input.renderConfig.isFromFrontCamera = [FUDemoManager shared].stickerH;
//        input.renderConfig.isFromMirroredCamera = [FUDemoManager shared].stickerH;
        input.renderConfig.stickerFlipH = [FUDemoManager shared].stickerH;
        //开启重力感应，内部会自动计算正确方向，设置fuSetDefaultRotationMode，无须外面设置
        input.renderConfig.gravityEnable = YES;
        FURenderOutput *outPut = [[FURenderKit shareRenderKit] renderWithInput:input];
        if(outPut){
            srcFrame.pixelBuffer = outPut.pixelBuffer;
        }
    }
    
    dstFrame.bufferType = V2TXLiveBufferTypePixelBuffer;
    dstFrame.pixelFormat = V2TXLivePixelFormatNV12;
    dstFrame.pixelBuffer = srcFrame.pixelBuffer;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:true];
}

- (void)dealloc {
    
    [FUDemoManager destory];
    [self removeKeyboardObserver];
}

#pragma mark - Notification
- (void)addKeyboardObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)removeKeyboardObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (BOOL)keyboardWillShow:(NSNotification *)noti {
    CGFloat animationDuration = [[[noti userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    CGRect keyboardBounds = [[[noti userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [UIView animateWithDuration:animationDuration animations:^{
        self.bottomConstraint.constant = keyboardBounds.size.height;
    }];
    return YES;
}

- (BOOL)keyboardWillHide:(NSNotification *)noti {
     CGFloat animationDuration = [[[noti userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
     [UIView animateWithDuration:animationDuration animations:^{
         self.bottomConstraint.constant = 25;
     }];
     return YES;
}


@end
