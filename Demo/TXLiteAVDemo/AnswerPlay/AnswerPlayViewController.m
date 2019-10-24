
//
//  AnswerPlayViewController.m
//  RTMPiOSDemo
//
//  Created by 蓝鲸 on 16/4/1.
//  Copyright © 2016年 tencent. All rights reserved.
//

#import "AnswerPlayViewController.h"
#import "ScanQRController.h"
//#import "TXUGCPublish.h"
#import "TXLiveRecordListener.h"
//#import "TXUGCPublishListener.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <mach/mach.h>
#import "AppLogMgr.h"
#import "AFNetworkReachabilityManager.h"
#import "UIView+Additions.h"
#import "UIImage+Additions.h"
#import "FloatQuestion.h"
#import "AnswerPlayMsgListTableView.h"
#import "ColorMacro.h"
#import "AnswerPlayIMCenter.h"

#define TEST_MUTE   0

//#define ENABLE_IM

#ifdef ENABLE_IM

#define AppId 1400063122
#define AccountType @"21862"
#define ChatGroup @"Chat_Group"
#define IssueGroup @"Issue_Broadcast_Group"
#define UserId @"ios_test"
#define UserSig @"eJxlj11PgzAYhe-5FYRro1CgNSbeOFBG9j2MxpumtB0UhDalbkzjf9-EJZJ4bp-nfU-Ol2XbtpPNtteEUvnRGmyOijv2ne24ztUfVEowTAz2NfsHea*E5pjsDNcD9MIwBK47dgTjrRE7cTGE7LDhnRkZHavxUPP7IjjfQ98DYKyIYoDz*HkyXUcMlp*JTF5ujeqrGxQ3alYkeQURWS*DNH-L6nrRx0-0ITpMi02fVpSXm8V*vqIHqJvsyII613JFEHovzGuUwnKZTvzH7n5UaUTDL5s8CBDyfG9E91x3QraDANyzAnz3J471bZ0AJbFfdQ__"
#endif
/**
 服务端发送消息示例
 
 {
 "GroupId": "Issue_Broadcast_Group",
 "Random": 893345,
 "MsgBody": [
 {
 "MsgType": "TIMCustomElem",
 "MsgContent": {
 "Data": "{\"question\": \"12.\u6211\u56fd\u53e4\u4ee3\u54ea\u4e2a\u671d\u4ee3\u7684\u201c\u72b6\u5143\u201d\u6700\u591a\uff1f\", \"answer_1\": \"A.\u5510\u671d\", \"answer_2\": \"B.\u6e05\u671d\", \"answer_3\": \"C.\u5b8b\u671d\", \"correct_index\": 1 }",
 "Desc": "notification",
 "Ext": "url",
 "Sound": "dingdong.aiff"
 }
 }
 ]
 }
 
 
 */

#define RTMP_URL    @"请输入或扫二维码获取播放地址"//请输入或扫二维码获取播放地址"

typedef struct
{
    unsigned int integer; //1900年以来的秒数
    unsigned int fraction;//小数部份，单位是微秒数的4294.967296(=2^32/10^6)倍
} ntptime ;
#define JAN_1970      0x83aa7e80      // (2208988800) 1900年到1970年的秒数

@interface AnswerPlayViewController ()<
UITextFieldDelegate,
TXLivePlayListener,
ScanQRDelegate,
FloatQuestionDelegate,
AnswerPlayIMCenterDelegate
>

@end

@implementation AnswerPlayViewController
{
    UIImageView *       _loadingImageView;
    BOOL                _appIsInterrupt;

    TX_Enum_PlayType    _playType;
    long long	        _startPlayTS;
    UIView *            mVideoContainer;
    NSString *          _playUrl;

    // 消息列表展示和输入
    AnswerPlayMsgListTableView *_msgListView;
    UIView                   *_msgInputView;
    UITextField              *_msgInputTextField;
    UIButton                 *_msgSendBtn;
    NSString                 *_nickName;
    CGPoint                  _touchBeginLocation;
    NSMutableArray           *_imQuestionArray;
    
    FloatQuestion *     _floatQt;
    AnswerPlayIMCenter *_imCenter;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _imQuestionArray = [NSMutableArray new];
#ifdef ENABLE_IM
    _nickName = UserId;
    _imCenter = [AnswerPlayIMCenter getInstance];
    _imCenter.delegate = self;
    [_imCenter initIMCenter:AppId accountType:AccountType];
    
    TIMLoginParam *param = [[TIMLoginParam alloc] init];
    param.identifier = UserId;
    param.userSig = UserSig;
    param.appidAt3rd = [NSString stringWithFormat:@"%d", AppId];
    
    [_imCenter loginIMUser:param succ:^{
        [_imCenter joinIMGroup:ChatGroup issueGroup:IssueGroup succ:^{
            NSLog(@"join group success");
        } fail:^(int code, NSString *msg) {
            UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"进群失败" message:msg?:@"" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil];
            [alertview show];
        }];
        NSLog(@"login success");
    } fail:^(int code, NSString *msg) {
        UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"登录失败" message:msg?:@"" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil];
        [alertview show];
    }];
#endif
    [self initUI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)initUI {
    for (UIView *view in self.view.subviews) {
        [view removeFromSuperview];
    }
    
    [self.view setBackgroundImage:[UIImage imageNamed:@"background.jpg"]];
    
    // remove all subview
    for (UIView *view in [self.view subviews]) {
        [view removeFromSuperview];
    }
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    int icon_size = size.width / 10;
        
    _cover = [[UIView alloc]init];
    _cover.frame  = CGRectMake(10.0f, 55 + 2*icon_size, size.width - 20, size.height - 75 - 3 * icon_size);
    _cover.backgroundColor = [UIColor whiteColor];
    _cover.alpha  = 0.5;
    _cover.hidden = YES;
    [self.view addSubview:_cover];
    
    int logheadH = 65;
    _statusView = [[UITextView alloc] initWithFrame:CGRectMake(10.0f, 55 + 2*icon_size, size.width - 20,  logheadH)];
    _statusView.backgroundColor = [UIColor clearColor];
    _statusView.alpha = 1;
    _statusView.textColor = [UIColor blackColor];
    _statusView.editable = NO;
    _statusView.hidden = YES;
    [self.view addSubview:_statusView];
    
    _logViewEvt = [[UITextView alloc] initWithFrame:CGRectMake(10.0f, 55 + 2*icon_size + logheadH, size.width - 20, size.height - 75 - 3 * icon_size - logheadH)];
    _logViewEvt.backgroundColor = [UIColor clearColor];
    _logViewEvt.alpha = 1;
    _logViewEvt.textColor = [UIColor blackColor];
    _logViewEvt.editable = NO;
    _logViewEvt.hidden = YES;
    [self.view addSubview:_logViewEvt];
    
    CGFloat txtWidth = size.width- 25 - icon_size;
    int rightBtnNum = 1;

    self.txtRtmpUrl = [[UITextField alloc] initWithFrame:CGRectMake(10, 30 + icon_size + 10, txtWidth, icon_size)];
    [self.txtRtmpUrl setBorderStyle:UITextBorderStyleRoundedRect];
    self.txtRtmpUrl.placeholder = RTMP_URL;
    self.txtRtmpUrl.text = @"";
    self.txtRtmpUrl.background = [UIImage imageNamed:@"Input_box"];
    self.txtRtmpUrl.alpha = 0.5;
    self.txtRtmpUrl.autocapitalizationType = UITextAutocorrectionTypeNo;
    self.txtRtmpUrl.delegate = self;
    [self.view addSubview:self.txtRtmpUrl];
    
    UIButton* btnScan = [UIButton buttonWithType:UIButtonTypeCustom];
    btnScan.frame = CGRectMake(size.width - 10 * rightBtnNum - icon_size * rightBtnNum , 30 + icon_size + 10, icon_size, icon_size);
    [btnScan setImage:[UIImage imageNamed:@"QR_code"] forState:UIControlStateNormal];
    [btnScan addTarget:self action:@selector(clickScan:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnScan];

#ifdef ENABLE_IM
    int icon_length = 8;
#else
    int icon_length = 7;
#endif
    int icon_gap = (size.width - icon_size*(icon_length-1))/icon_length;
    
    int btn_index = 0;
    _play_switch = NO;
    _btnPlay = [self createBottomBtnIndex:btn_index++ Icon:@"start" Action:@selector(clickPlay:) Gap:icon_gap Size:icon_size];
#ifdef ENABLE_IM
    [self createBottomBtnIndex:btn_index++ Icon:@"comment" Action:@selector(clickChat:) Gap:icon_gap Size:icon_size];
#endif
    _log_switch = NO;
    [self createBottomBtnIndex:btn_index++ Icon:@"log" Action:@selector(clickLog:) Gap:icon_gap Size:icon_size];

    _screenPortrait = NO;
    [self createBottomBtnIndex:btn_index++ Icon:@"portrait" Action:@selector(clickScreenOrientation:) Gap:icon_gap Size:icon_size];

    _renderFillScreen = NO;
    [self createBottomBtnIndex:btn_index++ Icon:@"fill" Action:@selector(clickRenderMode:) Gap:icon_gap Size:icon_size];
    
    _sdMode = NO;
    _sdBtn = [self createBottomBtnIndex:btn_index++ Icon:@"SD" Action:@selector(clickSDMode:) Gap:icon_gap Size:icon_size];
    
    _txLivePlayer = [[TXLivePlayer alloc] init];
    _txLivePlayer.recordDelegate = self;
    
    _helpBtn = [self createBottomBtnIndex:btn_index++ Icon:@"help.png" Action:@selector(onHelpBtnClicked) Gap:icon_gap Size:icon_size];
    
    //loading imageview
    float width = 34;
    float height = 34;
    float offsetX = (self.view.frame.size.width - width) / 2;
    float offsetY = (self.view.frame.size.height - height) / 2;
    NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:[UIImage imageNamed:@"loading_image0.png"],[UIImage imageNamed:@"loading_image1.png"],[UIImage imageNamed:@"loading_image2.png"],[UIImage imageNamed:@"loading_image3.png"],[UIImage imageNamed:@"loading_image4.png"],[UIImage imageNamed:@"loading_image5.png"],[UIImage imageNamed:@"loading_image6.png"],[UIImage imageNamed:@"loading_image7.png"], nil];
    _loadingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(offsetX, offsetY, width, height)];
    _loadingImageView.animationImages = array;
    _loadingImageView.animationDuration = 1;
    _loadingImageView.hidden = YES;
    [self.view addSubview:_loadingImageView];
    
    CGRect VideoFrame = self.view.bounds;
    mVideoContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, VideoFrame.size.width, VideoFrame.size.height)];
    [self.view insertSubview:mVideoContainer atIndex:0];
    mVideoContainer.center = self.view.center;
    
    // 消息列表展示和输入
    _msgListView = [[AnswerPlayMsgListTableView alloc] initWithFrame:CGRectMake(10, self.view.height/3, 300, self.view.height/2) style:UITableViewStyleGrouped];
    _msgListView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_msgListView];
    
    _msgInputView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.height, self.view.width, 50)];
    _msgInputView.backgroundColor = [UIColor clearColor];
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, _msgInputView.height)];
    _msgInputTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, _msgInputView.width - 80, _msgInputView.height)];
    _msgInputTextField.backgroundColor = UIColorFromRGB(0xfdfdfd);
    _msgInputTextField.returnKeyType = UIReturnKeySend;
    _msgInputTextField.placeholder = @"输入文字内容";
    _msgInputTextField.delegate = self;
    _msgInputTextField.leftView = paddingView;
    _msgInputTextField.leftViewMode = UITextFieldViewModeAlways;
    _msgInputTextField.textColor = [UIColor blackColor];
    _msgInputTextField.font = [UIFont systemFontOfSize:14];
    
    _msgSendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _msgSendBtn.frame = CGRectMake(_msgInputView.width - 80, 0, 80, _msgInputView.height);
    [_msgSendBtn setTitle:@"发送" forState:UIControlStateNormal];
    [_msgSendBtn.titleLabel setFont:[UIFont systemFontOfSize:16]];
    [_msgSendBtn setTitleColor:UIColorFromRGB(0x05a764) forState:UIControlStateNormal];
    [_msgSendBtn setBackgroundColor:UIColorFromRGB(0xfdfdfd)];
    [_msgSendBtn addTarget:self action:@selector(clickSend:) forControlEvents:UIControlEventTouchUpInside];
    
    UIView *vertical_line = [[UIView alloc] initWithFrame:CGRectMake(_msgSendBtn.left - 1, 6, 1, _msgInputView.height - 12)];
    vertical_line.backgroundColor = UIColorFromRGB(0xd8d8d8);
    
    [_msgInputView addSubview:_msgInputTextField];
    [_msgInputView addSubview:vertical_line];
    [_msgInputView addSubview:_msgSendBtn];
    [self.view addSubview:_msgInputView];
    
    self.title = @"答题播放器";
}

- (UIButton*)createBottomBtnIndex:(int)index Icon:(NSString*)icon Action:(SEL)action Gap:(int)gap Size:(int)size
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake((index+1)*gap + index*size, [[UIScreen mainScreen] bounds].size.height - size - 10, size, size);
    [btn setImage:[UIImage imageNamed:icon] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}

- (UIButton*)createBottomBtnIndexEx:(int)index Icon:(NSString*)icon Action:(SEL)action Gap:(int)gap Size:(int)size
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake((index+1)*gap + index*size, [[UIScreen mainScreen] bounds].size.height - 2*(size + 10), size, size);
    [btn setImage:[UIImage imageNamed:icon] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}

//在低系统（如7.1.2）可能收不到这个回调，请在onAppDidEnterBackGround和onAppWillEnterForeground里面处理打断逻辑
- (void) onAudioSessionEvent: (NSNotification *) notification
{
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        if (_play_switch == YES && _appIsInterrupt == NO) {

            _appIsInterrupt = YES;
        }
    }else{
        AVAudioSessionInterruptionOptions options = [info[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options == AVAudioSessionInterruptionOptionShouldResume) {

        }
    }
}

- (void)onAppDidEnterBackGround:(UIApplication*)app {
    if (_play_switch == YES) {

    }
}

- (void)onAppWillEnterForeground:(UIApplication*)app {
    if (_play_switch == YES) {

    }
}

- (void)onAppDidBecomeActive:(UIApplication*)app {
    if (_play_switch == YES && _appIsInterrupt == YES) {

        _appIsInterrupt = NO;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (_play_switch == YES) {
        [self stopRtmp];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAudioSessionEvent:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackGround:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma -- example code bellow
- (void)clearLog {
    _tipsMsg = @"";
    _logMsg = @"";
    [_statusView setText:@""];
    [_logViewEvt setText:@""];
    _startTime = [[NSDate date]timeIntervalSince1970]*1000;
    _lastTime = _startTime;
}

-(BOOL)checkPlayUrl:(NSString*)playUrl {

    if ([playUrl hasPrefix:@"rtmp:"]) {
        _playType = PLAY_TYPE_LIVE_RTMP;
    } else if (([playUrl hasPrefix:@"https:"] || [playUrl hasPrefix:@"http:"]) && [playUrl rangeOfString:@".flv"].length > 0) {
        _playType = PLAY_TYPE_LIVE_FLV;
    } else{
        [self toastTip:@"播放地址不合法，直播目前仅支持rtmp,flv播放方式!"];
        return NO;
    }

    return YES;
}
-(BOOL)startRtmp{
    NSString* playUrl = self.txtRtmpUrl.text;
    if (playUrl.length == 0) {
        playUrl = @"rtmp://live.hkstv.hk.lxdns.com/live/hks";
    }
    
    if (![self checkPlayUrl:playUrl]) {
        return NO;
    }
    
    [self clearLog];
    
    // arvinwu add. 增加播放按钮事件的时间打印。
    unsigned long long recordTime = [[NSDate date] timeIntervalSince1970]*1000;
    int mil = recordTime%1000;
    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString* time = [format stringFromDate:[NSDate date]];
    NSString* log = [NSString stringWithFormat:@"[%@.%-3.3d] 点击播放按钮", time, mil];
    
    NSString *ver = [TXLiveBase getSDKVersionStr];
    _logMsg = [NSString stringWithFormat:@"liteav sdk version: %@\n%@", ver, log];
    [_logViewEvt setText:_logMsg];

    
    if(_txLivePlayer != nil)
    {
        _txLivePlayer.delegate = self;

        [_txLivePlayer setupVideoWidget:CGRectMake(0, 0, 0, 0) containView:mVideoContainer insertIndex:0];

        
        if (_config == nil)
        {
            _config = [[TXLivePlayConfig alloc] init];
        }
        
        _config.cacheFolderPath = nil;

        //开启消息接受,收不到消息的话就是没打开这个（默认:关）
        _config.enableMessage = YES;
        //
        //设置延迟平衡点为1s(考虑到云端和推流端引入的延迟，实际延迟为2s多，SDK推流：2s, obs推流：3-4秒)
        _config.bAutoAdjustCacheTime = YES;
        _config.maxAutoAdjustCacheTime = 1;
        _config.minAutoAdjustCacheTime = 1;
        _config.cacheTime = 1;
        _config.connectRetryCount = 3;
        _config.connectRetryInterval = 3;
        _config.enableAEC = NO;
        [_txLivePlayer setConfig:_config];
        
#if TARGET_IPHONE_SIMULATOR
        _txLivePlayer.enableHWAcceleration = NO;
#else
        _txLivePlayer.enableHWAcceleration = YES;
#endif
        int result = [_txLivePlayer startPlay:playUrl type:_playType];
        if( result != 0)
        {
            NSLog(@"播放器启动失败");
            return NO;
        }
        
        if (_screenPortrait) {
            [_txLivePlayer setRenderRotation:HOME_ORIENTATION_RIGHT];
        } else {
            [_txLivePlayer setRenderRotation:HOME_ORIENTATION_DOWN];
        }
        if (_renderFillScreen) {
            [_txLivePlayer setRenderMode:RENDER_MODE_FILL_SCREEN];
        } else {
            [_txLivePlayer setRenderMode:RENDER_MODE_FILL_EDGE];
        }
        
        [self startLoadingAnimation];

        [_btnPlay setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
    }
    [self startLoadingAnimation];
    _startPlayTS = [[NSDate date]timeIntervalSince1970]*1000;
    
    _playUrl = playUrl;
    
    return YES;
}


- (void)stopRtmp{
    _playUrl = @"";
    [self stopLoadingAnimation];
    if(_txLivePlayer != nil)
    {
        [_txLivePlayer stopPlay];

        [_txLivePlayer removeVideoWidget];
        _txLivePlayer.delegate = nil;
    }
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:nil];
}

#pragma - ui event response.
- (void) clickPlay:(UIButton*) sender {
    //-[UIApplication setIdleTimerDisabled:]用于控制自动锁屏，SDK内部并无修改系统锁屏的逻辑
    if (_play_switch == YES)
    {
        {
            _play_switch = NO;
            _sdMode = NO;
            [self stopRtmp];
            [sender setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
        }
        
    }
    else
    {
        if (![self startRtmp]) {
            return;
        }
        
        [sender setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
        _play_switch = YES;
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    }
}

- (void) clickLog:(UIButton*) sender {
    if (_log_switch == YES)
    {
        _statusView.hidden = YES;
        _logViewEvt.hidden = YES;
        [sender setImage:[UIImage imageNamed:@"log"] forState:UIControlStateNormal];
        _cover.hidden = YES;
        _log_switch = NO;
    }
    else
    {
        _statusView.hidden = NO;
        _logViewEvt.hidden = NO;
        [sender setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
        _cover.hidden = NO;
        _log_switch = YES;
    }
    
    [_txLivePlayer snapshot:^(UIImage *img) {
        img = img;
    }];
}

- (void) clickScreenOrientation:(UIButton*) sender {
    _screenPortrait = !_screenPortrait;
    
    if (_screenPortrait) {
        [sender setImage:[UIImage imageNamed:@"landscape"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderRotation:HOME_ORIENTATION_RIGHT];
    } else {
        [sender setImage:[UIImage imageNamed:@"portrait"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderRotation:HOME_ORIENTATION_DOWN];
    }
}

- (void) clickRenderMode:(UIButton*) sender {
    _renderFillScreen = !_renderFillScreen;
    
    if (_renderFillScreen) {
        [sender setImage:[UIImage imageNamed:@"adjust"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderMode:RENDER_MODE_FILL_SCREEN];
    } else {
        [sender setImage:[UIImage imageNamed:@"fill"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderMode:RENDER_MODE_FILL_EDGE];
    }
}

- (void) clickSDMode:(UIButton *)sender {
    if (_playUrl.length == 0 || ![_playUrl hasSuffix:@".flv"])
        return;
    
    _sdMode = !_sdMode;
    
    if (_sdMode) {
        [sender setImage:[UIImage imageNamed:@"HD"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"SD"] forState:UIControlStateNormal];
    }
    
    NSString *newUrl = _playUrl;

    if ([newUrl hasSuffix:@"_550.flv"]) {
        if (_sdMode) {
            return;
        }
        newUrl = [[newUrl substringToIndex:newUrl.length-8] stringByAppendingString:@".flv"];
    } else {
        if (!_sdMode) {
            return;
        }
        newUrl = [[newUrl substringToIndex:newUrl.length-4] stringByAppendingString:@"_550.flv"];
    }
    
    [self stopRtmp];
    self.txtRtmpUrl.text = newUrl;
    [self startRtmp];
}

- (void)onHelpBtnClicked
{
    NSURL* helpURL = nil;

    helpURL = [NSURL URLWithString:@"https://cloud.tencent.com/document/product/454/13863"];
    
    UIApplication* myApp = [UIApplication sharedApplication];
    if ([myApp canOpenURL:helpURL]) {
        [myApp openURL:helpURL];
    }
}


-(void) clickScan:(UIButton*) btn
{
    [self stopRtmp];
    _play_switch = NO;
    [_btnPlay setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
    ScanQRController* vc = [[ScanQRController alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:NO];
}

#pragma mark - AnswerPlayIMCenterDelegate
- (void)onRecvChatMessage:(NSString *)message fromUser:(NSString *)userId;
{
    AnswerPlayMsgModel *msgMode = [[AnswerPlayMsgModel alloc] init];
    msgMode.type = AnswerPlayMsgModeTypeOther;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = userId;
    msgMode.userMsg = message;
    
    [_msgListView appendMsg:msgMode];
}

- (void)onRecvIssueMessage:(NSData *)data;
{
    QuestionModel *model = [[QuestionModel alloc] init];
    [model convertFromJson:[NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil]];
    
    if (model.question.length == 0)
        return;
    
    [_imQuestionArray addObject:model];
}

- (void)onIMGroupDelete:(NSString *)groupId;
{
    UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"错误" message:[NSString stringWithFormat:@"群 %@ 已解散", groupId]
                                                       delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil];
    [alertview show];
}

- (void)onForceOffline;
{
    UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"错误" message:@"你已被踢下线，请退出播放器重新进入" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil];
    [alertview show];
}

- (void)onUserSigExpired;
{
    UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"错误" message:@"userSig已过期" delegate:nil cancelButtonTitle:@"好" otherButtonTitles:nil];
    [alertview show];
}

- (void)onReConnFailed:(int)code err:(NSString *)err;
{
    
}
#pragma mark -- ScanQRDelegate
- (void)onScanResult:(NSString *)result
{
    self.txtRtmpUrl.text = result;
}

/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param Width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
- (float) heightForString:(UITextView *)textView andWidth:(float)width{
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height + 10;
}

- (void) toastTip:(NSString*)toastInfo
{
    CGRect frameRC = [[UIScreen mainScreen] bounds];
    frameRC.origin.y = frameRC.size.height - 110;
    frameRC.size.height -= 110;
    __block UITextView * toastView = [[UITextView alloc] init];
    
    toastView.editable = NO;
    toastView.selectable = NO;
    
    frameRC.size.height = [self heightForString:toastView andWidth:frameRC.size.width];
    
    toastView.frame = frameRC;
    
    toastView.text = toastInfo;
    toastView.backgroundColor = [UIColor whiteColor];
    toastView.alpha = 0.5;
    
    [self.view addSubview:toastView];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^(){
        [toastView removeFromSuperview];
        toastView = nil;
    });
}

#pragma ###TXLivePlayListener
-(void) appendLog:(NSString*) evt time:(NSDate*) date mills:(int)mil
{
    if (evt == nil) {
        return;
    }
    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString* time = [format stringFromDate:date];
    NSString* log = [NSString stringWithFormat:@"[%@.%-3.3d] %@", time, mil, evt];
    if (_logMsg == nil) {
        _logMsg = @"";
    }
    _logMsg = [NSString stringWithFormat:@"%@\n%@", _logMsg, log ];
    [_logViewEvt setText:_logMsg];
}

-(void) onPlayEvent:(int)EvtID withParam:(NSDictionary*)param
{
    NSDictionary* dict = param;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {
//            _publishParam = nil;
        }
        else if (EvtID == PLAY_EVT_GET_MESSAGE) {
            [self onPlayerMessage:param[@"EVT_GET_MSG"]];
        } else if (EvtID == PLAY_EVT_PLAY_BEGIN) {
            [self stopLoadingAnimation];
            long long playDelay = [[NSDate date]timeIntervalSince1970]*1000 - _startPlayTS;
            AppDemoLog(@"AutoMonitor:PlayFirstRender,cost=%lld", playDelay);
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT || EvtID == PLAY_EVT_PLAY_END) {
            [self stopRtmp];
            _play_switch = NO;
            [_btnPlay setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
            
            if (EvtID == PLAY_ERR_NET_DISCONNECT) {
                NSString* Msg = (NSString*)[dict valueForKey:EVT_MSG];
                [self toastTip:Msg];
            }
            
        } else if (EvtID == PLAY_EVT_PLAY_LOADING){
            if (!_sdMode && _alertController == nil) {
                _loadingCount++;
                if (_loadingCount >= 3) {
                    _alertController = [UIAlertController alertControllerWithTitle:@"提示" message:@"当前网络不佳，是否切换标清？" preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"否" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
                        _alertController = nil;
                    }];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"是" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                        [self clickSDMode:_sdBtn];
                        _alertController = nil;
                    }];
                    [_alertController addAction:cancelAction];
                    [_alertController addAction:okAction];
                    [self presentViewController:_alertController animated:YES completion:nil];
                    
                    _loadingCount = 0;
                }
            }
            [self startLoadingAnimation];
        }
        else if (EvtID == PLAY_EVT_CONNECT_SUCC) {
            BOOL isWifi = [AFNetworkReachabilityManager sharedManager].reachableViaWiFi;
            if (!isWifi) {
                __weak __typeof(self) weakSelf = self;
                [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
                    if (_playUrl.length == 0) {
                        return;
                    }
                    if (status == AFNetworkReachabilityStatusReachableViaWiFi) {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@""
                                                                                       message:@"您要切换到Wifi再观看吗?"
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"是" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [alert dismissViewControllerAnimated:YES completion:nil];
                            [weakSelf stopRtmp];
                            [weakSelf startRtmp];
                        }]];
                        [alert addAction:[UIAlertAction actionWithTitle:@"否" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                            [alert dismissViewControllerAnimated:YES completion:nil];
                        }]];
                        [weakSelf presentViewController:alert animated:YES completion:nil];
                    }
                }];
            }
        }else if (EvtID == PLAY_EVT_CHANGE_ROATION) {
            return;
        }
//        NSLog(@"evt:%d,%@", EvtID, dict);
        long long time = [(NSNumber*)[dict valueForKey:EVT_TIME] longLongValue];
        int mil = time % 1000;
        NSDate* date = [NSDate dateWithTimeIntervalSince1970:time/1000];
        NSString* Msg = (NSString*)[dict valueForKey:EVT_MSG];
        [self appendLog:Msg time:date mills:mil];
    });
}

-(void) onNetStatus:(NSDictionary*) param
{
    NSDictionary* dict = param;

    dispatch_async(dispatch_get_main_queue(), ^{
        int netspeed  = [(NSNumber*)[dict valueForKey:NET_STATUS_NET_SPEED] intValue];
        int vbitrate  = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_BITRATE] intValue];
        int abitrate  = [(NSNumber*)[dict valueForKey:NET_STATUS_AUDIO_BITRATE] intValue];
        int cachesize = [(NSNumber*)[dict valueForKey:NET_STATUS_CACHE_SIZE] intValue];
        int dropsize  = [(NSNumber*)[dict valueForKey:NET_STATUS_DROP_SIZE] intValue];
        int jitter    = [(NSNumber*)[dict valueForKey:NET_STATUS_NET_JITTER] intValue];
        int fps       = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_FPS] intValue];
        int width     = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_WIDTH] intValue];
        int height    = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_HEIGHT] intValue];
        float cpu_usage = [(NSNumber*)[dict valueForKey:NET_STATUS_CPU_USAGE] floatValue];
        float cpu_app_usage = [(NSNumber*)[dict valueForKey:NET_STATUS_CPU_USAGE_D] floatValue];
        NSString *serverIP = [dict valueForKey:NET_STATUS_SERVER_IP];
        int codecCacheSize = [(NSNumber*)[dict valueForKey:NET_STATUS_CODEC_CACHE] intValue];
        int nCodecDropCnt = [(NSNumber*)[dict valueForKey:NET_STATUS_CODEC_DROP_CNT] intValue];
        int nCahcedSize = [(NSNumber*)[dict valueForKey:NET_STATUS_CACHE_SIZE] intValue]/1000;
        int nSetVideoBitrate = [(NSNumber *) [dict valueForKey:NET_STATUS_SET_VIDEO_BITRATE] intValue];
        int videoCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_CACHE_SIZE] intValue];
        int vDecCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_V_DEC_CACHE_SIZE] intValue];
        int playInterval = [(NSNumber *) [dict valueForKey:NET_STATUS_AV_PLAY_INTERVAL] intValue];
        int avRecvInterval = [(NSNumber *) [dict valueForKey:NET_STATUS_AV_RECV_INTERVAL] intValue];
        float audioPlaySpeed = [(NSNumber *) [dict valueForKey:NET_STATUS_AUDIO_PLAY_SPEED] floatValue];
        NSString * audioInfo = [dict valueForKey:NET_STATUS_AUDIO_INFO];
        int videoGop = (int)([(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_GOP] doubleValue]+0.5f);
        NSString* log = [NSString stringWithFormat:@"CPU:%.1f%%|%.1f%%\tRES:%d*%d\tSPD:%dkb/s\nJITT:%d\tFPS:%d\tGOP:%ds\tARA:%dkb/s\nQUE:%d|%d,%d,%d|%d,%d,%0.1f\tVRA:%dkb/s\nSVR:%@\tAUDIO:%@",
                        cpu_app_usage*100,
                         cpu_usage*100,
                         width,
                         height,
                         netspeed,
                         jitter,
                         fps,
                         videoGop,
                         abitrate,
                         codecCacheSize,
                         cachesize,
                         videoCacheSize,
                         vDecCacheSize,
                         playInterval,
                         avRecvInterval,
                         audioPlaySpeed,
                         vbitrate,
                         serverIP,
                         audioInfo];
        [_statusView setText:log];
        AppDemoLogOnlyFile(@"Current status, VideoBitrate:%d, AudioBitrate:%d, FPS:%d, RES:%d*%d, netspeed:%d", vbitrate, abitrate, fps, width, height, netspeed);
    });
}

-(void) startLoadingAnimation
{
    if (_loadingImageView != nil) {
        _loadingImageView.hidden = NO;
        [_loadingImageView startAnimating];
    }
}

-(void) stopLoadingAnimation
{
    if (_loadingImageView != nil) {
        _loadingImageView.hidden = YES;
        [_loadingImageView stopAnimating];
    }
}

-(long)byteArrayToInt:(NSData *)data {
    Byte *byteArray = (Byte *)data.bytes;
    int a_len = 8;
    Byte *a = (Byte *)malloc(a_len);
    int i = a_len - 1;
    int j = (int)data.length - 1;
    for (; i >= 0; i--, j--) {// 从b的尾部(即int值的低位)开始copy数据
        if (j >= 0)
            a[i] = byteArray[j];
        else
            a[i] = 0;// 如果b.length不足4,则将高位补0
    }
    // 注意此处和byte数组转换成int的区别在于，下面的转换中要将先将数组中的元素转换成long型再做移位操作，
    // 若直接做位移操作将得不到正确结果，因为Java默认操作数字时，若不加声明会将数字作为int型来对待，此处必须注意。
    long v0 = (long) (a[0] & 0xff) << 56;// &0xff将byte值无差异转成int,避免Java自动类型提升后,会保留高位的符号位
    long v1 = (long) (a[1] & 0xff) << 48;
    long v2 = (long) (a[2] & 0xff) << 40;
    long v3 = (long) (a[3] & 0xff) << 32;
    long v4 = (long) (a[4] & 0xff) << 24;
    long v5 = (long) (a[5] & 0xff) << 16;
    long v6 = (long) (a[6] & 0xff) << 8;
    long v7 = (long) (a[7] & 0xff);
    free(a);
    return v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7;
}

- (void)onPlayerMessage:(NSData *)msg {
    if (_floatQt == nil) {
        _floatQt = [[FloatQuestion alloc] initWithFrame:CGRectZero];
        [self.view addSubview:_floatQt];
        _floatQt.hiddenFooter = YES;
        _floatQt.delegate = self;
    }
    
    if (msg.length == 8) {
        long tv = [self byteArrayToInt:msg];
        long sv = tv / 1000;    // 服务器返回的是毫秒Unix timestamp，这里转换成秒
        [self testInImArray:sv];
//        NSLog(@"time %ld", sv);
        return;
    }
    
    QuestionModel *model = [[QuestionModel alloc] init];
    
    [model convertFromJson:[NSJSONSerialization JSONObjectWithData:msg options:kNilOptions error:nil]];
    
    if (model.question.length == 0)
        return;
    
    [_floatQt setModel:model];
    _floatQt.frame = CGRectMake(8, 150, self.view.width-16, _floatQt.calcHeight);
    [_floatQt setTimeout:12];
}

- (void)testInImArray:(int64_t)timestamp {
    QuestionModel *latest = nil;
    for (QuestionModel *model in [_imQuestionArray copy]) {
        if (model.timestamp <= timestamp)
            latest = model;
    }
    
    if (latest) {
        [_floatQt setModel:latest];
        _floatQt.frame = CGRectMake(8, 150, self.view.width-16, _floatQt.calcHeight);
        [_floatQt setTimeout:12];
        [_imQuestionArray removeObject:latest];
    }
}

- (void)onMakeAnswser:(FloatQuestion *)view answer:(NSString *)answer {
    _floatQt.hidden = YES;
}

- (void)onMakeQuestion:(FloatQuestion *)view {
    
}


- (void)alertTips:(NSString *)title msg:(NSString *)msg completion:(void(^)())completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (completion) {
                completion();
            }
        }]];
        
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void)clickChat:(id)sender {
    [_msgInputTextField becomeFirstResponder];
}

// 发送消息
- (void)clickSend:(UIButton *)btn {
    [self textFieldShouldReturn:_msgInputTextField];
}

// 监听键盘高度变化
- (void)keyboardFrameDidChange:(NSNotification *)notice {
    NSDictionary * userInfo = notice.userInfo;
    NSValue * endFrameValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect endFrame = endFrameValue.CGRectValue;
    [UIView animateWithDuration:0.25 animations:^{
        if (endFrame.origin.y == self.view.height) {
            _msgInputView.y = endFrame.origin.y;
        } else {
            _msgInputView.y =  endFrame.origin.y - _msgInputView.height;
        }
    }];
}


- (void)appendSystemMsg:(NSString *)msg {
    AnswerPlayMsgModel *msgMode = [[AnswerPlayMsgModel alloc] init];
    msgMode.type = AnswerPlayMsgModeTypeSystem;
    msgMode.userMsg = msg;
    [_msgListView appendMsg:msgMode];
}

- (void)onRecvRoomTextMsg:(NSString *)roomID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar textMsg:(NSString *)textMsg {
    AnswerPlayMsgModel *msgMode = [[AnswerPlayMsgModel alloc] init];
    msgMode.type = AnswerPlayMsgModeTypeOther;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = userName;
    msgMode.userMsg = textMsg;
    
    [_msgListView appendMsg:msgMode];
}

#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
    _msgInputTextField.text = @"";
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    _msgInputTextField.text = textField.text;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _txtRtmpUrl) {
        [textField resignFirstResponder];
        return YES;
    }
    
    NSString *textMsg = [textField.text stringByTrimmingCharactersInSet:[NSMutableCharacterSet whitespaceCharacterSet]];
    if (textMsg.length <= 0) {
        textField.text = @"";
        [self alertTips:@"提示" msg:@"消息不能为空" completion:nil];
        return YES;
    }
    
    AnswerPlayMsgModel *msgMode = [[AnswerPlayMsgModel alloc] init];
    msgMode.type = AnswerPlayMsgModeTypeOther;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = _nickName;
    msgMode.userMsg = textMsg;
    
    [_msgListView appendMsg:msgMode];
    
    _msgInputTextField.text = @"";
    [_msgInputTextField resignFirstResponder];
    
    // 发送
    [_imCenter sendChatMessage:textMsg succ:nil fail:nil];
    
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.txtRtmpUrl resignFirstResponder];
    [_msgInputTextField resignFirstResponder];
    
    _touchBeginLocation = [[[event allTouches] anyObject] locationInView:self.view];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint location = [[[event allTouches] anyObject] locationInView:self.view];
    [self endMove:location.x - _touchBeginLocation.x];
}

// 滑动隐藏UI控件
- (void)endMove:(CGFloat)moveX {
    // 目前只需要隐藏消息列表控件
    [UIView animateWithDuration:0.2 animations:^{
        if (moveX > 10) {
            for (UIView *view in self.view.subviews) {
                if (![view isEqual:_msgListView]) {
                    continue;
                }
                
                CGRect rect = view.frame;
                if (rect.origin.x >= 0 && rect.origin.x < [UIScreen mainScreen].bounds.size.width) {
                    rect = CGRectOffset(rect, self.view.width, 0);
                    view.frame = rect;
                }
            }
            
        } else if (moveX < -10) {
            for (UIView *view in self.view.subviews) {
                if (![view isEqual:_msgListView]) {
                    continue;
                }
                
                CGRect rect = view.frame;
                if (rect.origin.x >= [UIScreen mainScreen].bounds.size.width) {
                    rect = CGRectOffset(rect, -self.view.width, 0);
                    view.frame = rect;
                }
            }
        }
    }];
}

@end
