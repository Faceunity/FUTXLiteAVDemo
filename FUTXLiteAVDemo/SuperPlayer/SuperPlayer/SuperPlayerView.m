#import "SuperPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import "SuperPlayer.h"
#import "CFDanmakuView.h"
#import "SuperPlayerControlViewDelegate.h"
#import "J2Obj.h"
#import "SuperPlayerView+Private.h"
#import "DataReport.h"
#import "TXCUrl.h"
#import "StrUtils.h"
#import "UIView+Fade.h"
#import "TXBitrateItemHelper.h"
#import "UIView+MMLayout.h"
#import "SPDefaultControlView.h"

static UISlider * _volumeSlider;

#define CellPlayerFatherViewTag  200

//忽略编译器的警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"




@implementation SuperPlayerView {
    UIView *_fullScreenBlackView;
    SuperPlayerControlView *_controlView;
}


#pragma mark - life Cycle

/**
 *  代码初始化调用此方法
 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self initializeThePlayer]; }
    return self;
}

/**
 *  storyboard、xib加载playerView会调用此方法
 */
- (void)awakeFromNib {
    [super awakeFromNib];
    [self initializeThePlayer];
}

/**
 *  初始化player
 */
- (void)initializeThePlayer {
    
    self.netWatcher = [[NetWatcher alloc] init];
    
    CGRect frame = CGRectMake(0, -100, 10, 0);
    self.volumeView = [[MPVolumeView alloc] initWithFrame:frame];
    [self.volumeView sizeToFit];
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        if (!window.isHidden) {
            [window addSubview:self.volumeView];
            break;
        }
    }
    
    _fullScreenBlackView = [UIView new];
    _fullScreenBlackView.backgroundColor = [UIColor blackColor];
    
    // 单例slider
    _volumeSlider = nil;
    for (UIView *view in [self.volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeSlider = (UISlider *)view;
            break;
        }
    }
    
    _playerConfig = [[SuperPlayerViewConfig alloc] init];
    // 添加通知
    [self addNotifications];
    // 添加手势
    [self createGesture];
}

- (void)dealloc {
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    [self reportPlay];
    [self.netWatcher stopWatch];
    [self.volumeView removeFromSuperview];
}

#pragma mark - 弹幕

- (NSTimeInterval)danmakuViewGetPlayTime:(CFDanmakuView *)danmakuView
{
    return -[self.reportTime timeIntervalSinceNow];
}

- (BOOL)danmakuViewIsBuffering:(CFDanmakuView *)danmakuView
{
    return self.state != StatePlaying;
}

- (void)setDanmakuView:(CFDanmakuView *)danmakuView
{
    if (_danmakuView) {
        [_danmakuView removeFromSuperview];
    }
    _danmakuView = danmakuView;
    
    if (_danmakuView) {
        _danmakuView.delegate = self;
        [self addSubview:_danmakuView];
        
        [_danmakuView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self);
            make.bottom.equalTo(self);
            make.left.equalTo(self);
            make.right.equalTo(self);
        }];
    }
}


#pragma mark - 观察者、通知

/**
 *  添加观察者、通知
 */
- (void)addNotifications {
    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayground) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // 监测设备方向
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationChange)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onStatusBarOrientationChange)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
}

#pragma mark - layoutSubviews

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.subviews.count > 0) {
        UIView *innerView = self.subviews[0];
        if ([innerView isKindOfClass:NSClassFromString(@"TXIJKSDLGLView")] ||
            [innerView isKindOfClass:NSClassFromString(@"TXCAVPlayerView")]) {
            innerView.frame = self.bounds;
        }
    }
}

#pragma mark - Public Method

- (void)playWithModel:(SuperPlayerModel *)playerModel {
    self.imageSprite = nil;
    self.keyFrameDescList = nil;
    self.isShiftPlayback = NO;
    [self reportPlay];
    self.reportTime = [NSDate date];
    [self _removeOldPlayer];
    [self _playWithModel:playerModel];
    self.coverImageView.alpha = 1;
}

- (void)_playWithModel:(SuperPlayerModel *)playerModel {
    _playerModel = playerModel;
    
    [self pause];
    
    NSString *videoURL = playerModel.playingDefinitionUrl;
    if (videoURL != nil) {
        [self configTXPlayer];
    } else if (playerModel.appId != 0 && playerModel.fileId != nil) {
        self.isLive = NO;
        [self getPlayInfo:playerModel.appId withFileId:playerModel.fileId];
    } else {
        NSLog(@"无播放地址");
    }
}

/**
 *  player添加到fatherView上
 */
- (void)addPlayerToFatherView:(UIView *)view {
    [self removeFromSuperview];
    if (view) {
        [view addSubview:self];
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_offset(UIEdgeInsetsZero);
        }];
    }
}

- (void)setFatherView:(UIView *)fatherView {
    if (fatherView != _fatherView) {
        [self addPlayerToFatherView:fatherView];
    }
    _fatherView = fatherView;
}

/**
 *  重置player
 */
- (void)resetPlayer {
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 暂停
    [self pause];
    
    [self.vodPlayer stopPlay];
    [self.vodPlayer removeVideoWidget];
    self.vodPlayer = nil;
    
    [self.livePlayer stopPlay];
    [self.livePlayer removeVideoWidget];
    self.livePlayer = nil;
    
    [self reportPlay];
    
    self.state = StateStopped;
}

/**
 *  播放
 */
- (void)resume {
    [self.controlView setPlayState:YES];
    self.isPauseByUser = NO;
    if (self.isLive) {
        [_livePlayer resume];
    } else {
        [_vodPlayer resume];
    }
}

/**
 * 暂停
 */
- (void)pause {
    [self.controlView setPlayState:NO];
    self.isPauseByUser = YES;
    if (self.isLive) {
        [_livePlayer pause];
    } else {
        [_vodPlayer pause];
    }
}

- (TXVodPlayer *)vodPlayer
{
    if (_vodPlayer == nil) {
        _vodPlayer = [[TXVodPlayer alloc] init];
        TXVodPlayConfig *config = [[TXVodPlayConfig alloc] init];
        config.maxCacheItems = (int)SuperPlayerGlobleConfigShared.maxCacheItem;
        config.cacheFolderPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/TXCache"];
        config.progressInterval = 0.02;
//        config.playerType = PLAYER_AVPLAYER;
        [_vodPlayer setConfig:config];
        _vodPlayer.vodDelegate = self;
    }
    return _vodPlayer;
}

- (TXLivePlayer *)livePlayer
{
    if (_livePlayer == nil) {
        _livePlayer = [[TXLivePlayer alloc] init];
        TXLivePlayConfig *config = [[TXLivePlayConfig alloc] init];
        config.bAutoAdjustCacheTime = NO;
        config.maxAutoAdjustCacheTime = 5.0f;
        config.minAutoAdjustCacheTime = 5.0f;
        [_livePlayer setConfig:config];
        _livePlayer.delegate = self;
    }
    return _livePlayer;
}

#pragma mark - Private Method
/**
 *  设置Player相关参数
 */
- (void)configTXPlayer {
    self.backgroundColor = [UIColor blackColor];
    
    [self.vodPlayer stopPlay];
    [self.vodPlayer removeVideoWidget];
    [self.livePlayer stopPlay];
    [self.livePlayer removeVideoWidget];
    
    self.liveProgressTime = self.maxLiveProgressTime = 0;
    
    int liveType = [self livePlayerType];
    if (liveType >= 0) {
        self.isLive = YES;
    } else {
        self.isLive = NO;
    }
    self.isLoaded = NO;
    
    self.netWatcher.playerModel = self.playerModel;
    if (self.playerModel.playingDefinition == nil) {
        self.playerModel.playingDefinition = self.netWatcher.adviseDefinition;
    }
    NSString *videoURL = self.playerModel.playingDefinitionUrl;
    
    if (self.isLive) {
        self.livePlayer.enableHWAcceleration = self.playerConfig.hwAcceleration;
        [self.livePlayer startPlay:videoURL type:liveType];
        // 时移
        [TXLiveBase setAppID:[NSString stringWithFormat:@"%ld", _playerModel.appId]];
        TXCUrl *curl = [[TXCUrl alloc] initWithString:videoURL];
        [self.livePlayer prepareLiveSeek:SuperPlayerGlobleConfigShared.playShiftDomain bizId:[curl bizid]];
        
        [self.livePlayer setMute:self.playerConfig.mute];
        [self.livePlayer setRenderMode:self.playerConfig.renderMode];
    } else {
        self.vodPlayer.enableHWAcceleration = self.playerConfig.hwAcceleration;
        [self.vodPlayer startPlay:videoURL];
        [self.vodPlayer setBitrateIndex:self.playerModel.playingDefinitionIndex];
        
        [self.vodPlayer setRate:self.playerConfig.playRate];
        [self.vodPlayer setMirror:self.playerConfig.mirror];
        [self.vodPlayer setMute:self.playerConfig.mute];
        [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
    }
    [self.netWatcher startWatch];
    __weak SuperPlayerView *weakSelf = self;
    [self.netWatcher setNotifyTipsBlock:^(NSString *msg) {
        SuperPlayerView *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf showMiddleBtnMsg:msg withAction:ActionSwitch];
            [strongSelf.middleBlackBtn fadeOut:2];
        }
    }];
    self.state = StateBuffering;
    self.isPauseByUser = NO;
    [self.controlView playerBegin:self.playerModel isLive:self.isLive isTimeShifting:self.isShiftPlayback];
    self.controlView.playerConfig = self.playerConfig;
    self.repeatBtn.hidden = YES;
    self.playDidEnd = NO;
}

/**
 *  创建手势
 */
- (void)createGesture {
    // 单击
    self.singleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleTapAction:)];
    self.singleTap.delegate                = self;
    self.singleTap.numberOfTouchesRequired = 1; //手指数
    self.singleTap.numberOfTapsRequired    = 1;
    [self addGestureRecognizer:self.singleTap];
    
    // 双击(播放/暂停)
    self.doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTapAction:)];
    self.doubleTap.delegate                = self;
    self.doubleTap.numberOfTouchesRequired = 1; //手指数
    self.doubleTap.numberOfTapsRequired    = 2;
    [self addGestureRecognizer:self.doubleTap];

    // 解决点击当前view时候响应其他控件事件
    [self.singleTap setDelaysTouchesBegan:YES];
    [self.doubleTap setDelaysTouchesBegan:YES];
    // 双击失败响应单击事件
    [self.singleTap requireGestureRecognizerToFail:self.doubleTap];
    
    // 加载完成后，再添加平移手势
    // 添加平移手势，用来控制音量、亮度、快进快退
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
    panRecognizer.delegate = self;
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelaysTouchesBegan:YES];
    [panRecognizer setDelaysTouchesEnded:YES];
    [panRecognizer setCancelsTouchesInView:YES];
    [self addGestureRecognizer:panRecognizer];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

}

#pragma mark - KVO

/**
 *  设置横屏的约束
 */
- (void)setOrientationLandscapeConstraint:(UIInterfaceOrientation)orientation {
    self.isFullScreen = YES;
    [self toOrientation:orientation];
}

/**
 *  设置竖屏的约束
 */
- (void)setOrientationPortraitConstraint {

    [self addPlayerToFatherView:self.fatherView];
    self.isFullScreen = NO;
    [self toOrientation:UIInterfaceOrientationPortrait];
}

- (void)toOrientation:(UIInterfaceOrientation)orientation {
    // 获取到当前状态条的方向
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    // 判断如果当前方向和要旋转的方向一致,那么不做任何操作
    if (currentOrientation == orientation) { return; }
    
    // 根据要旋转的方向,使用Masonry重新修改限制
    if (orientation != UIInterfaceOrientationPortrait) {//
        // 这个地方加判断是为了从全屏的一侧,直接到全屏的另一侧不用修改限制,否则会出错;
        if (currentOrientation == UIInterfaceOrientationPortrait) {
            [self removeFromSuperview];
            if (IsIPhoneX) {
                [[UIApplication sharedApplication].keyWindow addSubview:_fullScreenBlackView];
                [_fullScreenBlackView mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.width.equalTo(@(ScreenHeight));
                    make.height.equalTo(@(ScreenWidth));
                    make.center.equalTo([UIApplication sharedApplication].keyWindow);
                }];
            }
            [[UIApplication sharedApplication].keyWindow addSubview:self];
            [self mas_remakeConstraints:^(MASConstraintMaker *make) {
                if (IsIPhoneX) {
                    make.width.equalTo(@(ScreenHeight-88));
                } else {
                    make.width.equalTo(@(ScreenHeight));
                }

                make.height.equalTo(@(ScreenWidth));
                make.center.equalTo([UIApplication sharedApplication].keyWindow);
            }];
        }
    } else {
        [_fullScreenBlackView removeFromSuperview];
    }
    // iOS6.0之后,设置状态条的方法能使用的前提是shouldAutorotate为NO,也就是说这个视图控制器内,旋转要关掉;
    // 也就是说在实现这个方法的时候-(BOOL)shouldAutorotate返回值要为NO
    [[UIApplication sharedApplication] setStatusBarOrientation:orientation animated:NO];
    // 获取旋转状态条需要的时间:
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    // 更改了状态条的方向,但是设备方向UIInterfaceOrientation还是正方向的,这就要设置给你播放视频的视图的方向设置旋转
    // 给你的播放视频的view视图设置旋转
    self.transform = CGAffineTransformIdentity;
    self.transform = [self getTransformRotationAngle];
    
    _fullScreenBlackView.transform = self.transform;
    // 开始旋转
    [UIView commitAnimations];
    
    if ([self.delegate respondsToSelector:@selector(superPlayerFullScreenChanged:)]) {
        [self.delegate superPlayerFullScreenChanged:self];
    }
}

/**
 * 获取变换的旋转角度
 *
 * @return 角度
 */
- (CGAffineTransform)getTransformRotationAngle {
    // 状态条的方向已经设置过,所以这个就是你想要旋转的方向
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    // 根据要进行旋转的方向来计算旋转的角度
    if (orientation == UIInterfaceOrientationPortrait) {
        return CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft){
        return CGAffineTransformMakeRotation(-M_PI_2);
    } else if(orientation == UIInterfaceOrientationLandscapeRight){
        return CGAffineTransformMakeRotation(M_PI_2);
    }
    return CGAffineTransformIdentity;
}

#pragma mark 屏幕转屏相关

/**
 *  屏幕转屏
 *
 *  @param orientation 屏幕方向
 */
- (void)interfaceOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
        // 设置横屏
        [self setOrientationLandscapeConstraint:orientation];
    } else if (orientation == UIInterfaceOrientationPortrait) {
        // 设置竖屏
        [self setOrientationPortraitConstraint];
    }
}

/**
 *  屏幕方向发生变化会调用这里
 */
- (void)onDeviceOrientationChange {
    if (!self.isLoaded) { return; }
    if (self.isLockScreen) { return; }
    if (self.didEnterBackground) { return; };
    if (SuperPlayerWindowShared.isShowing) { return; }
    
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    if (orientation == UIDeviceOrientationFaceUp || orientation == UIDeviceOrientationFaceDown || orientation == UIDeviceOrientationUnknown ) { return; }
    
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:{
        }
            break;
        case UIInterfaceOrientationPortrait:{
            if (self.isFullScreen) {
                self.isFullScreen = NO;
                [self toOrientation:UIInterfaceOrientationPortrait];
            }
        }
            break;
        case UIInterfaceOrientationLandscapeLeft:{
            if (self.isFullScreen == NO) {
                self.isFullScreen = YES;
            }
            [self toOrientation:UIInterfaceOrientationLandscapeLeft];
        }
            break;
        case UIInterfaceOrientationLandscapeRight:{
            if (self.isFullScreen == NO) {
                self.isFullScreen = YES;
            }
            [self toOrientation:UIInterfaceOrientationLandscapeRight];
        }
            break;
        default:
            break;
    }
}

// 状态条变化通知（在前台播放才去处理）
- (void)onStatusBarOrientationChange {
    if (!self.didEnterBackground) {
        // 获取到当前状态条的方向
        UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
        if (currentOrientation == UIInterfaceOrientationPortrait) {
            [self setOrientationPortraitConstraint];
        } else {
            if (currentOrientation == UIInterfaceOrientationLandscapeRight) {
                [self toOrientation:UIInterfaceOrientationLandscapeRight];
            } else if (currentOrientation == UIDeviceOrientationLandscapeLeft){
                [self toOrientation:UIInterfaceOrientationLandscapeLeft];
            }
        }
    }
}



#pragma mark - Action

/**
 *   轻拍方法
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)singleTapAction:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        
        if (self.playDidEnd) {
            return;
        }
        if (SuperPlayerWindowShared.isShowing)
            return;
        
        if (self.controlView.hidden) {
            [[self.controlView fadeShow] fadeOut:5];
        } else {
            [self.controlView fadeOut:0.2];
        }
    }
}

/**
 *  双击播放/暂停
 *
 *  @param gesture UITapGestureRecognizer
 */
- (void)doubleTapAction:(UIGestureRecognizer *)gesture {
    if (self.playDidEnd) { return;  }
    // 显示控制层
    [self.controlView fadeShow];
    if (self.isPauseByUser) {
        [self resume];
    } else {
        [self pause];
    }
}



/** 全屏 */
- (void)_fullScreenAction:(BOOL)fullScreen {
    self.isFullScreen = fullScreen;
    if (fullScreen) {
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        if (orientation == UIDeviceOrientationLandscapeRight) {
            [self interfaceOrientation:UIInterfaceOrientationLandscapeLeft];
        } else {
            [self interfaceOrientation:UIInterfaceOrientationLandscapeRight];
        }
    } else {
        [self interfaceOrientation:UIInterfaceOrientationPortrait];
    }
}

#pragma mark - NSNotification Action

/**
 *  播放完了
 *
 */
- (void)moviePlayDidEnd {
    self.state = StateStopped;
    self.playDidEnd = YES;
    // 播放结束隐藏
    if (SuperPlayerWindowShared.isShowing) {
        [SuperPlayerWindowShared hide];
        [self resetPlayer];
    }
    [self.controlView fadeOut:0.2];
    [self.netWatcher stopWatch];
    self.repeatBtn.hidden = NO;
}

/**
 *  应用退到后台
 */
- (void)appDidEnterBackground {
    NSLog(@"appDidEnterBackground");
    self.didEnterBackground     = YES;
    if (self.state == StatePlaying && !self.isLive) {
        [_vodPlayer pause];
        self.state                  = StatePause;
    }
}

/**
 *  应用进入前台
 */
- (void)appDidEnterPlayground {
    NSLog(@"appDidEnterPlayground");
    self.didEnterBackground     = NO;
    if (!self.isPauseByUser && self.state == StatePause && !self.isLive) {
        self.state         = StatePlaying;
        self.isPauseByUser = NO;
        [self resume];
    }
}

/**
 *  从xx秒开始播放视频跳转
 *
 *  @param dragedSeconds 视频跳转的秒数
 */
- (void)seekToTime:(NSInteger)dragedSeconds {
    if (!self.isLoaded || self.state == StateStopped) {
        return;
    }
    if (self.isLive) {
        [DataReport report:@"timeshift" param:nil];
        int ret = [self.livePlayer seek:dragedSeconds];
        if (ret != 0) {
            [self showMiddleBtnMsg:kStrTimeShiftFailed withAction:ActionNone];
            [self.middleBlackBtn fadeOut:2];
            [self.controlView playerBegin:self.playerModel isLive:self.isLive isTimeShifting:self.isShiftPlayback];
        } else {
            self.isShiftPlayback = YES;
            self.state = StateBuffering;
            self.isLoaded = NO;
            [self.controlView playerBegin:self.playerModel isLive:YES isTimeShifting:self.isShiftPlayback];    //时移播放不能切码率
        }
    } else {
        [self.vodPlayer seek:dragedSeconds];
        self.seekTime = 0;
        [self.vodPlayer resume];
    }
}

#pragma mark - UIPanGestureRecognizer手势方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return YES;
    }

    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (!self.isLoaded) { return NO; }
        if (self.isLockScreen) { return NO; }
        if (SuperPlayerWindowShared.isShowing) { return NO; }
        
        if (self.disableGesture) {
            if (!self.isFullScreen) {
                return NO;
            }
        }
        return YES;
    }
    
    return NO;
}
/**
 *  pan手势事件
 *
 *  @param pan UIPanGestureRecognizer
 */
- (void)panDirection:(UIPanGestureRecognizer *)pan {

    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [pan locationInView:self];
    
    // 我们要响应水平移动和垂直移动
    // 根据上次和本次移动的位置，算出一个速率的point
    CGPoint veloctyPoint = [pan velocityInView:self];
    
    // 判断是垂直移动还是水平移动
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ // 开始移动
            // 使用绝对值来判断移动的方向
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { // 水平移动
                // 取消隐藏
                self.panDirection = PanDirectionHorizontalMoved;
                self.sumTime      = [self getCurrentTime];
            }
            else if (x < y){ // 垂直移动
                self.panDirection = PanDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.bounds.size.width / 2) {
                    self.isVolume = YES;
                }else { // 状态改为显示亮度调节
                    self.isVolume = NO;
                }
            }
            self.isDragging = YES;
            [self.controlView fadeOut:0.2];
            break;
        }
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    break;
                }
                case PanDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
                default:
                    break;
            }
            self.isDragging = YES;
            break;
        }
        case UIGestureRecognizerStateEnded:{ // 移动停止
            // 移动结束也需要判断垂直或者平移
            // 比如水平移动结束时，要快进到指定位置，如果这里没有判断，当我们调节音量完之后，会出现屏幕跳动的bug
            switch (self.panDirection) {
                case PanDirectionHorizontalMoved:{
                    self.isPauseByUser = NO;
                    [self seekToTime:self.sumTime];
                    // 把sumTime滞空，不然会越加越多
                    self.sumTime = 0;
                    break;
                }
                case PanDirectionVerticalMoved:{
                    // 垂直移动结束后，把状态改为不再控制音量
                    self.isVolume = NO;
                    break;
                }
                default:
                    break;
            }
            [self fastViewUnavaliable];
            self.isDragging = NO;
            break;
        }
        default:
            break;
    }
}

/**
 *  pan垂直移动的方法
 *
 *  @param value void
 */
- (void)verticalMoved:(CGFloat)value {
   
    self.isVolume ? ([[self class] volumeViewSlider].value -= value / 10000) : ([UIScreen mainScreen].brightness -= value / 10000);

    if (self.isVolume) {
        [self fastViewImageAvaliable:SuperPlayerImage(@"sound_max") progress:[[self class] volumeViewSlider].value];
    } else {
        [self fastViewImageAvaliable:SuperPlayerImage(@"light_max") progress:[UIScreen mainScreen].brightness];
    }
}

/**
 *  pan水平移动的方法
 *
 *  @param value void
 */
- (void)horizontalMoved:(CGFloat)value {
    // 每次滑动需要叠加时间
    CGFloat totalMovieDuration = [self getTotalTime];
    self.sumTime += value / 10000 * totalMovieDuration;
    
    if (self.sumTime > totalMovieDuration) { self.sumTime = totalMovieDuration;}
    if (self.sumTime < 0) { self.sumTime = 0; }
    
    [self fastViewProgressAvaliable:self.sumTime];
}

- (void)volumeChanged:(NSNotification *)notification
{
    if (self.isDragging)
        return; // 正在拖动，不响应音量事件
    
    if (![[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"] isEqualToString:@"ExplicitVolumeChange"]) {
        return;
    }
    float volume = [[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    [self fastViewImageAvaliable:SuperPlayerImage(@"sound_max") progress:volume];
    [self.fastView fadeOut:1];
}

- (SuperPlayerFastView *)fastView
{
    if (_fastView == nil) {
        _fastView = [[SuperPlayerFastView alloc] init];
        [self addSubview:_fastView];
        [_fastView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(UIEdgeInsetsZero);
        }];
    }
    return _fastView;
}

- (void)fastViewImageAvaliable:(UIImage *)image progress:(CGFloat)draggedValue {
    [self.fastView showImg:image withProgress:draggedValue];
    [self.fastView fadeShow];
}

- (void)fastViewProgressAvaliable:(NSInteger)draggedTime
{
    NSInteger totalTime = [self getTotalTime];
    NSString *currentTimeStr = [StrUtils timeFormat:draggedTime];
    NSString *totalTimeStr   = [StrUtils timeFormat:totalTime];
    NSString *timeStr        = [NSString stringWithFormat:@"%@ / %@", currentTimeStr, totalTimeStr];
    if (self.isLive) {
        timeStr = [NSString stringWithFormat:@"%@", currentTimeStr];
    }
    
    UIImage *thumbnail;
    if (self.isFullScreen) {
        thumbnail = [self.imageSprite getThumbnail:self.sumTime];
    }
    if (thumbnail) {
        self.fastView.videoRatio = self.videoRatio;
        [self.fastView showThumbnail:thumbnail withText:timeStr];
    } else {
        CGFloat sliderValue = 1;
        if (totalTime > 0) {
            sliderValue = (CGFloat)draggedTime/totalTime;
        }
        if (self.isLive && totalTime > MAX_SHIFT_TIME) {
            CGFloat base = totalTime - MAX_SHIFT_TIME;
            if (self.sumTime < base)
                self.sumTime = base;
            sliderValue = (self.sumTime - base) / MAX_SHIFT_TIME;
            NSLog(@"%f",sliderValue);
        }
        [self.fastView showText:timeStr withText:sliderValue];
    }
    [self.fastView fadeShow];
}

- (void)fastViewUnavaliable
{
    [self.fastView fadeOut:0.1];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    

    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (self.playDidEnd){
            return NO;
        }
    }

    if ([touch.view isKindOfClass:[UISlider class]] || [touch.view.superview isKindOfClass:[UISlider class]]) {
        return NO;
    }
    
    if (SuperPlayerWindowShared.isShowing)
        return NO;

    return YES;
}

#pragma mark - Setter 


/**
 *  设置播放的状态
 *
 *  @param state ZFPlayerState
 */
- (void)setState:(SuperPlayerState)state {
    _state = state;
    // 控制菊花显示、隐藏
    if (state == StateBuffering) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
    if (state == StatePlaying || state == StateBuffering) {

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(volumeChanged:)         name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                   object:nil];
        
        if (self.coverImageView.alpha == 1) {
            [UIView animateWithDuration:0.2 animations:^{
                self.coverImageView.alpha = 0;
            }];
        }
    } else if (state == StateFailed) {
        
    } else if (state == StateStopped) {
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                      object:nil];
        
        self.coverImageView.alpha = 1;
        
    } else if (state == StatePause) {

    }
}

- (void)setControlView:(SuperPlayerControlView *)controlView {
    _controlView = controlView;
    controlView.delegate = self;
    [self addSubview:controlView];
    [controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsZero);
    }];
}

- (SuperPlayerControlView *)controlView
{
    if (_controlView == nil) {
        self.controlView = [[SPDefaultControlView alloc] initWithFrame:CGRectZero];
    }
    return _controlView;
}

- (void)setDragging:(BOOL)dragging
{
    _isDragging = dragging;
    if (dragging) {
        [[NSNotificationCenter defaultCenter]
         removeObserver:self name:@"AVSystemController_SystemVolumeDidChangeNotification"
         object:nil];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(volumeChanged:)
             name:@"AVSystemController_SystemVolumeDidChangeNotification"
             object:nil];
        });
    }
}

#pragma mark - Getter

- (CGFloat)getTotalTime {
    if (self.isLive) {
        return self.maxLiveProgressTime;
    }
    
    return self.vodPlayer.duration;
}

- (CGFloat)getCurrentTime {
    if (self.isLive) {
        if (self.isShiftPlayback) {
            return self.liveProgressTime;
        }
        return self.maxLiveProgressTime;
    }
    
    return self.vodPlayer.currentPlaybackTime;
}

+ (UISlider *)volumeViewSlider {
    return _volumeSlider;
}
#pragma mark - SuperPlayerControlViewDelegate

- (void)controlViewPlay:(SuperPlayerControlView *)controlView
{
    [self resume];
    if (self.state == StatePause) { self.state = StatePlaying; }
}

- (void)controlViewPause:(SuperPlayerControlView *)controlView
{
    [self pause];
    if (self.state == StatePlaying) { self.state = StatePause;}
}

- (void)controlViewBack:(SuperPlayerControlView *)controlView {
    if ([self.delegate respondsToSelector:@selector(superPlayerBackAction:)]) {
        [self.delegate superPlayerBackAction:self];
    }
}

- (void)controlViewChangeScreen:(SuperPlayerControlView *)controlView withFullScreen:(BOOL)isFullScreen {
    [self _fullScreenAction:isFullScreen];
}

- (void)controlViewLockScreen:(SuperPlayerControlView *)controlView withLock:(BOOL)isLock {
    self.isLockScreen = isLock;
}

- (void)controlViewSwitch:(SuperPlayerControlView *)controlView withDefinition:(NSString *)definition {
    if ([self.playerModel.playingDefinition isEqualToString:definition])
        return;
    
    self.playerModel.playingDefinition = definition;
    NSString *url = self.playerModel.playingDefinitionUrl;
    if (self.isLive) {
        [self.livePlayer switchStream:url];
        [self showMiddleBtnMsg:[NSString stringWithFormat:@"正在切换到%@...", definition] withAction:ActionNone];
    } else {
        if ([self.vodPlayer supportedBitrates].count > 0) {
            [self.vodPlayer setBitrateIndex:self.playerModel.playingDefinitionIndex];
        } else {
            self.seekTime = [self.vodPlayer currentPlaybackTime];
            [self.vodPlayer startPlay:url];
        }
    }
}

- (void)controlViewConfigUpdate:(SuperPlayerView *)controlView {
    if (self.isLive) {
        [self.livePlayer setMute:self.playerConfig.mute];
        [self.livePlayer setRenderMode:self.playerConfig.renderMode];
    } else {
        [self.vodPlayer setRate:self.playerConfig.playRate];
        [self.vodPlayer setMirror:self.playerConfig.mirror];
        [self.vodPlayer setMute:self.playerConfig.mute];
        [self.vodPlayer setRenderMode:self.playerConfig.renderMode];
    }
    if (self.playerConfig.hwAccelerationChanged) {
        if (!self.isLive)
            self.seekTime = [self.vodPlayer currentPlaybackTime];
        [self configTXPlayer]; // 软硬解需要重启
    }
}


- (void)controlViewReload:(UIView *)controlView {
    if (self.isLive) {
        self.isShiftPlayback = NO;
        self.isLoaded = NO;
        [self.livePlayer resumeLive];
        [self.controlView playerBegin:self.playerModel isLive:self.isLive isTimeShifting:self.isShiftPlayback];
    } else {
        self.seekTime = [self.vodPlayer currentPlaybackTime];
        [self configTXPlayer];
    }
}

- (void)controlViewSnapshot:(SuperPlayerControlView *)controlView {
    
    void (^block)(UIImage *img) = ^(UIImage *img) {
        [self.fastView showSnapshot:img];
        
        if ([self.fastView.snapshotView gestureRecognizers].count == 0) {
            UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPhotos)];
            singleTap.numberOfTapsRequired = 1;
            [self.fastView.snapshotView setUserInteractionEnabled:YES];
            [self.fastView.snapshotView addGestureRecognizer:singleTap];
        }
        [self.fastView fadeShow];
        [self.fastView fadeOut:2];
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
    };
    
    if (_isLive) {
        [_livePlayer snapshot:block];
    } else {
        [_vodPlayer snapshot:block];
    }
}

-(void)openPhotos {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"photos-redirect://"]];
}

- (void)controlViewDanmaku:(SuperPlayerControlView *)controlView withShow:(BOOL)show {
    if (show) {
        [_danmakuView start];
        _danmakuView.hidden = NO;
    } else {
        [_danmakuView pause];
        _danmakuView.hidden = YES;
    }
}

- (void)controlViewSeek:(SuperPlayerControlView *)controlView where:(CGFloat)pos {
    // 视频总时间长度
    CGFloat total = [self getTotalTime];
    //计算出拖动的当前秒数
    NSInteger dragedSeconds = floorf(total * pos);
    [self seekToTime:dragedSeconds];
    [self fastViewUnavaliable];
}

- (void)controlViewPreview:(SuperPlayerControlView *)controlView where:(CGFloat)pos {
    // 视频总时间长度
    CGFloat totalTime = [self getTotalTime];
    //计算出拖动的当前秒数
    CGFloat dragedSeconds = floorf(totalTime * pos);
    if (self.isLive && totalTime > MAX_SHIFT_TIME) {
        CGFloat base = totalTime - MAX_SHIFT_TIME;
        dragedSeconds = floor(MAX_SHIFT_TIME * pos) + base;
    }

    if (totalTime > 0) { // 当总时长 > 0时候才能拖动slider
        [self fastViewProgressAvaliable:dragedSeconds];
    }
}


#pragma clang diagnostic pop
#pragma mark - 点播回调

- (void)_removeOldPlayer
{
    for (UIView *w in [self subviews]) {
        if ([w isKindOfClass:NSClassFromString(@"TXCRenderView")])
            [w removeFromSuperview];
        if ([w isKindOfClass:NSClassFromString(@"TXIJKSDLGLView")])
            [w removeFromSuperview];
        if ([w isKindOfClass:NSClassFromString(@"TXCAVPlayerView")])
            [w removeFromSuperview];
    }
}

-(void) onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary*)param
{
    NSDictionary* dict = param;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {
            [self setNeedsLayout];
            [self layoutIfNeeded];
            self.isLoaded = YES;
            [self _removeOldPlayer];
            [self.vodPlayer setupVideoWidget:self insertIndex:0];
            [self layoutSubviews];  // 防止横屏状态下添加view显示不全
            self.state = StatePlaying;
            
            if (self.playerModel.playDefinitions.count == 0) {
                [self updateBitrates:player.supportedBitrates];
            }
            [self updatePlayerPoint];
        }
        if (EvtID == PLAY_EVT_VOD_PLAY_PREPARED) {
            if (self.seekTime > 0) {
                [player seek:self.seekTime];
                self.seekTime = 0;
            }
        }
        
        if (EvtID == PLAY_EVT_PLAY_BEGIN) {
            if (self.state == StateBuffering)
                self.state = StatePlaying;
        } else if (EvtID == PLAY_EVT_PLAY_PROGRESS) {
            if (self.state == StateStopped)
                return;

            NSInteger currentTime = player.currentPlaybackTime;
            CGFloat totalTime     = player.duration;
            CGFloat value         = player.currentPlaybackTime / player.duration;

            [self.controlView setProgressTime:currentTime totalTime:totalTime progressValue:value playableValue:player.playableDuration / player.duration];

        } else if (EvtID == PLAY_EVT_PLAY_END) {
            self.state = StateStopped;
            [self moviePlayDidEnd];
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT || EvtID == PLAY_ERR_FILE_NOT_FOUND || EvtID == PLAY_ERR_HLS_KEY) {
            if (EvtID == PLAY_ERR_NET_DISCONNECT) {
                [self showMiddleBtnMsg:kStrBadNetRetry withAction:ActionReplay];
            } else {
                [self showMiddleBtnMsg:kStrLoadFaildRetry withAction:ActionReplay];
            }
            self.state = StateFailed;
            [player stopPlay];
        } else if (EvtID == PLAY_EVT_PLAY_LOADING){
            // 当缓冲是空的时候
            self.state = StateBuffering;
        } else if (EvtID == PLAY_EVT_CHANGE_RESOLUTION) {
            if (player.height != 0) {
                self.videoRatio = (GLfloat)player.width / player.height;
            }
        }
     });
}

- (void)updateBitrates:(NSArray<TXBitrateItem *> *)bitrates;
{
    if (bitrates.count > 0) {
        NSArray *titles = [TXBitrateItemHelper sortWithBitrate:bitrates];
        _playerModel.multiVideoURLs = titles;
        self.netWatcher.playerModel = _playerModel;
        _playerModel.playingDefinition = self.netWatcher.adviseDefinition;
        [self.controlView playerBegin:_playerModel isLive:self.isLive isTimeShifting:self.isShiftPlayback];
        [self.vodPlayer setBitrateIndex:_playerModel.playingDefinitionIndex];
    }
}

- (void)updatePlayerPoint {
    [self.controlView removeAllVideoPoints];
    
    for (NSDictionary *keyFrameDesc in self.keyFrameDescList) {
        NSInteger time = [J2Num([keyFrameDesc valueForKeyPath:@"timeOffset"]) intValue];
        NSString *content = J2Str([keyFrameDesc valueForKeyPath:@"content"]);
        [self.controlView addVideoPoint:time/1000.0/([self getTotalTime]+1)
                                   text:[content stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                   time:time];
    }
}
#pragma mark - 直播回调

- (void)onPlayEvent:(int)EvtID withParam:(NSDictionary *)param {
    NSDictionary* dict = param;
    
    dispatch_async(dispatch_get_main_queue(), ^{

        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME && !self.isLoaded) {
            [self setNeedsLayout];
            [self layoutIfNeeded];
            self.isLoaded = YES;
            [self _removeOldPlayer];
            [self.livePlayer setupVideoWidget:CGRectZero containView:self insertIndex:0];
            [self layoutSubviews];  // 防止横屏状态下添加view显示不全
            self.state = StatePlaying;
            [self updatePlayerPoint];
        }
        
        if (EvtID == PLAY_EVT_PLAY_BEGIN) {
            if (self.state == StateBuffering)
                self.state = StatePlaying;
            [self.netWatcher loadingEndEvent];
        } else if (EvtID == PLAY_EVT_PLAY_END) {
            self.state = StateStopped;
            [self moviePlayDidEnd];
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT) {
            if (self.isShiftPlayback) {
                [self controlViewReload:self.controlView];
                [self showMiddleBtnMsg:kStrTimeShiftFailed withAction:ActionReplay];
                [self.middleBlackBtn fadeOut:2];
            } else {
                [self showMiddleBtnMsg:kStrBadNetRetry withAction:ActionReplay];
                self.state = StateFailed;
            }
        } else if (EvtID == PLAY_EVT_PLAY_LOADING){
            // 当缓冲是空的时候
            self.state = StateBuffering;
            if (!self.isShiftPlayback) {
                [self.netWatcher loadingEvent];
            }
        } else if (EvtID == PLAY_EVT_STREAM_SWITCH_SUCC) {
            [self showMiddleBtnMsg:[@"已切换为" stringByAppendingString:self.playerModel.playingDefinition] withAction:ActionNone];
            [self.middleBlackBtn fadeOut:1];
        } else if (EvtID == PLAY_ERR_STREAM_SWITCH_FAIL) {
            [self showMiddleBtnMsg:kStrHDSwitchFailed withAction:ActionReplay];
            self.state = StateFailed;
        } else if (EvtID == PLAY_EVT_PLAY_PROGRESS) {
            if (self.state == StateStopped)
                return;
            NSInteger progress = [dict[EVT_PLAY_PROGRESS] intValue];
            self.liveProgressTime = progress;
            self.maxLiveProgressTime = MAX(self.maxLiveProgressTime, self.liveProgressTime);
            
            if (self.isShiftPlayback) {
                CGFloat sv = 0;
                if (self.maxLiveProgressTime > MAX_SHIFT_TIME) {
                    CGFloat base = self.maxLiveProgressTime - MAX_SHIFT_TIME;
                    sv = (self.liveProgressTime - base) / MAX_SHIFT_TIME;
                } else {
                    sv = self.liveProgressTime / (self.maxLiveProgressTime + 1);
                }
                [self.controlView setProgressTime:self.liveProgressTime totalTime:-1 progressValue:sv playableValue:0];
            } else {
                [self.controlView setProgressTime:self.maxLiveProgressTime totalTime:-1 progressValue:1 playableValue:0];
            }
        }
    });
}

#pragma mark - Net
- (void)getPlayInfo:(NSInteger)appid withFileId:(NSString *)fileId {
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSString *url = [NSString stringWithFormat:@"https://playvideo.qcloud.com/getplayinfo/v2/%ld/%@", appid, fileId];
    
    __weak SuperPlayerView *weakSelf = self;
    SuperPlayerModel *theModel = _playerModel;
    self.getInfoHttpTask = [manager GET:url parameters:nil progress:nil
                                success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                    
                                    __strong SuperPlayerView *strongSelf = weakSelf;
                                    
                                    NSString *masterUrl = J2Str([responseObject valueForKeyPath:@"videoInfo.masterPlayList.url"]);
                                    //    masterUrl = nil;
                                    if (masterUrl.length > 0) {
                                        theModel.videoURL = masterUrl;
                                    } else {
                                        NSString *mainDefinition = J2Str([responseObject valueForKeyPath:@"playerInfo.defaultVideoClassification"]);
                                        
                                        
                                        NSArray *videoClassification = J2Array([responseObject valueForKeyPath:@"playerInfo.videoClassification"]);
                                        NSArray *transcodeList = J2Array([responseObject valueForKeyPath:@"videoInfo.transcodeList"]);
                                        
                                        NSMutableArray<SuperPlayerUrl *> *result = [NSMutableArray new];
                                        
                                        for (NSDictionary *transcode in transcodeList) {
                                            SuperPlayerUrl *subModel = [SuperPlayerUrl new];
                                            subModel.url = J2Str(transcode[@"url"]);
                                            NSNumber *theDefinition = J2Num(transcode[@"definition"]);
                                            
                                            
                                            for (NSDictionary *definition in videoClassification) {
                                                for (NSObject *definition2 in J2Array([definition valueForKeyPath:@"definitionList"])) {
                                                    
                                                    if ([definition2 isEqual:theDefinition]) {
                                                        subModel.title = J2Str([definition valueForKeyPath:@"name"]);
                                                        NSString *definitionId = J2Str([definition valueForKeyPath:@"id"]);
                                                        // 初始播放清晰度
                                                        if ([definitionId isEqualToString:mainDefinition]) {
                                                            if (![theModel.videoURL containsString:@".mp4"])
                                                                theModel.videoURL = subModel.url;
                                                        }
                                                        break;
                                                    }
                                                }
                                            }
                                            // 同一个清晰度可能存在多个转码格式，这里只保留一种格式，且优先mp4类型
                                            for (SuperPlayerUrl *item in result) {
                                                if ([item.title isEqual:subModel.title]) {
                                                    if (![item.url containsString:@".mp4"]) {
                                                        item.url = subModel.url;
                                                    }
                                                    subModel = nil;
                                                    break;
                                                }
                                            }
                                            
                                            if (subModel) {
                                                [result addObject:subModel];
                                            }
                                        }
                                        theModel.multiVideoURLs = result;
                                    }
                                    if (theModel.videoURL == nil) {
                                        NSString *source = J2Str([responseObject valueForKeyPath:@"videoInfo.sourceVideo.url"]);
                                        theModel.videoURL = source;
                                    }
                                    
                                    NSArray *imageSprites = J2Array([responseObject valueForKeyPath:@"imageSpriteInfo.imageSpriteList"]);
                                    if (imageSprites.count > 0) {
                                        //                 id imageSpriteObj = imageSprites[0];
                                        id imageSpriteObj = imageSprites.lastObject;
                                        NSString *vtt = J2Str([imageSpriteObj valueForKeyPath:@"webVttUrl"]);
                                        NSArray *imgUrls = J2Array([imageSpriteObj valueForKeyPath:@"imageUrls"]);
                                        NSMutableArray *imgUrlArray = @[].mutableCopy;
                                        for (NSString *url in imgUrls) {
                                            NSURL *nsurl = [NSURL URLWithString:url];
                                            if (nsurl) {
                                                [imgUrlArray addObject:nsurl];
                                            }
                                        }
                                        
                                        TXImageSprite *imageSprite = [[TXImageSprite alloc] init];
                                        [imageSprite setVTTUrl:[NSURL URLWithString:vtt] imageUrls:imgUrlArray];
                                        strongSelf.imageSprite = imageSprite;
                                        
                                        [DataReport report:@"image_sprite" param:nil];
                                    }
                                    
                                    NSArray *keyFrameDescList = J2Array([responseObject valueForKeyPath:@"keyFrameDescInfo.keyFrameDescList"]);
                                    if (keyFrameDescList.count > 0) {
                                        strongSelf.keyFrameDescList = keyFrameDescList;
                                    } else {
                                        strongSelf.keyFrameDescList = nil;
                                    }
                                    
                                    [strongSelf _playWithModel:theModel];
                                    
                                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                    // error 错误信息
                                    [self showMiddleBtnMsg:kStrLoadFaildRetry withAction:ActionIgnore];
                                }];
    [manager invalidateSessionCancelingTasks:NO];
}

- (int)livePlayerType {
    int playType = -1;
    if (self.playerModel.fileId != nil)
        return -1;
    NSString *videoURL = self.playerModel.playingDefinitionUrl;
    if ([videoURL hasPrefix:@"rtmp:"]) {
        playType = PLAY_TYPE_LIVE_RTMP;
    } else if (([videoURL hasPrefix:@"https:"] || [videoURL hasPrefix:@"http:"]) && ([videoURL rangeOfString:@".flv"].length > 0)) {
        playType = PLAY_TYPE_LIVE_FLV;
    }
    return playType;
}

- (void)reportPlay {
    if (self.reportTime == nil)
        return;
    int usedtime = -[self.reportTime timeIntervalSinceNow];
    if (self.isLive) {
        [DataReport report:@"superlive" param:@{@"usedtime":@(usedtime)}];
    } else {
        [DataReport report:@"supervod" param:@{@"usedtime":@(usedtime), @"fileid":@(self.playerModel.fileId?1:0)}];
    }
    self.reportTime = nil;
}

#pragma mark - middle btn

- (UIButton *)middleBlackBtn
{
    if (_middleBlackBtn == nil) {
        _middleBlackBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_middleBlackBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _middleBlackBtn.titleLabel.font = [UIFont systemFontOfSize:14.0];
        _middleBlackBtn.backgroundColor = RGBA(0, 0, 0, 0.7);
        [_middleBlackBtn addTarget:self action:@selector(middleBlackBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_middleBlackBtn];
        [_middleBlackBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.height.mas_equalTo(33);
        }];
    }
    return _middleBlackBtn;
}

- (void)showMiddleBtnMsg:(NSString *)msg withAction:(ButtonAction)action {
    [self.middleBlackBtn setTitle:msg forState:UIControlStateNormal];
    self.middleBlackBtn.titleLabel.text = msg;
    self.middleBlackBtnAction = action;
    CGFloat width = self.middleBlackBtn.titleLabel.attributedText.size.width;
    
    [self.middleBlackBtn mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(width+10));
    }];
    [self.middleBlackBtn fadeShow];
}

- (void)middleBlackBtnClick:(UIButton *)btn
{
    switch (self.middleBlackBtnAction) {
        case ActionNone:
            break;
        case ActionReplay:
            [self configTXPlayer];
        case ActionSwitch:
            [self controlViewSwitch:self.controlView withDefinition:self.netWatcher.adviseDefinition];
            [self.controlView playerBegin:self.playerModel isLive:self.isLive isTimeShifting:self.isShiftPlayback];
        case ActionIgnore:
            return;
        default:
            break;
    }
    [btn fadeOut:0.2];
}

- (UIButton *)repeatBtn {
    if (!_repeatBtn) {
        _repeatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_repeatBtn setImage:SuperPlayerImage(@"repeat_video") forState:UIControlStateNormal];
        [_repeatBtn addTarget:self action:@selector(repeatBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_repeatBtn];
        [_repeatBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
        }];
    }
    return _repeatBtn;
}

- (void)repeatBtnClick:(UIButton *)sender {
    [self configTXPlayer];
}

- (MMMaterialDesignSpinner *)spinner {
    if (!_spinner) {
        _spinner = [[MMMaterialDesignSpinner alloc] init];
        _spinner.lineWidth = 1;
        _spinner.duration  = 1;
        _spinner.hidden    = YES;
        _spinner.hidesWhenStopped = YES;
        _spinner.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        [self addSubview:_spinner];
        [_spinner mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.with.height.mas_equalTo(45);
        }];
    }
    return _spinner;
}

- (UIImageView *)coverImageView {
    if (!_coverImageView) {
        _coverImageView = [[UIImageView alloc] init];
        _coverImageView.userInteractionEnabled = YES;
        _coverImageView.contentMode = UIViewContentModeScaleAspectFit;
        _coverImageView.alpha = 0;
        [self addSubview:_coverImageView];
        [_coverImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(UIEdgeInsetsZero);
        }];
    }
    return _coverImageView;
}

@end
