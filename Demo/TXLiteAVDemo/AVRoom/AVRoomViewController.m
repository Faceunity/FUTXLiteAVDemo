#import "AVRoomViewController.h"
#import <Foundation/Foundation.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import "UIView+Additions.h"
#import "TXLiveSDKTypeDef.h"


@interface TXCAVRoomPlayerView : NSObject
@property (nonatomic, strong) UIView *view;
@property (nonatomic, assign) CGRect rect;  // 保存view最开始分配的位置
@end

@implementation TXCAVRoomPlayerView
- (instancetype)init {
    if (self = [super init]) {
        self.view = [[UIView alloc] init];
        self.view.layer.borderColor = [[UIColor whiteColor] CGColor];
    }
    return self;
}

- (void)setHighlight:(BOOL)enable {
    self.view.layer.borderWidth = enable ? 2 : 0;
}
@end


@interface TXCAVRoomEventStatus : NSObject
@property (nonatomic, assign) UInt64    userID;
@property (nonatomic, strong) NSString* event;
@property (nonatomic, strong) NSString* status;
@end

@implementation TXCAVRoomEventStatus
- (instancetype)init {
    if (self = [super init]) {
        self.event = @"";
        self.status = @"";
    }
    return self;
}
@end


@interface AVRoomViewController ()<UITextFieldDelegate>

@end

typedef enum : NSUInteger {
    AVROOM_IDLE,
    AVROOM_ENTERING,
    AVROOM_ENTERED,
    AVROOM_EXITING,
} AVRoomStatus;

@implementation AVRoomViewController {
    TXCAVRoom*                _avRoom;
    TXCAVRoomPlayerView*      _videoPreview;
    NSMutableDictionary*      _playerViewDic;  // [userID, TXCAVRoomPlayerView]
    UInt64                    _selfUserID;
    
    NSMutableArray*           _evtStatsDataArray;
    int                       _evtStatsDataIndex;
    
    UIView*                   _currEvtStatsView;
    UIView*                   _prevEvtStatsView;
    
    BOOL                      _appIsInActive;
    BOOL                      _appIsBackground;
    AVRoomStatus              _roomStatus;
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
#if !TARGET_IPHONE_SIMULATOR
    //是否有摄像头权限
    AVAuthorizationStatus statusVideo = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (statusVideo == AVAuthorizationStatusDenied) {
        [self toastTip:@"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限"];
        return;
    }
#endif
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackGround:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated; {
    [super viewDidDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _selfUserID = arc4random();
    
    TXCAVRoomConfig *config = [[TXCAVRoomConfig alloc] init]; // 使用默认值即可
    config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
    
    _avRoom = [[TXCAVRoom alloc] initWithConfig:config andAppId:1400044820 andUserID:_selfUserID];
    _avRoom.delegate = self;
    [_avRoom setBeautyLevel:5 whitenessLevel:5 ruddinessLevel:5];   // 设置美颜
    
    _playerViewDic = [[NSMutableDictionary alloc] init];
    
    _evtStatsDataArray = [[NSMutableArray alloc] init];
    _evtStatsDataIndex = 0;
    
    _appIsInActive = NO;
    _appIsBackground = NO;
    _roomStatus = AVROOM_IDLE;
    
    [self initUI];
    [_vBeauty resetValues];
}

#pragma NSNotification
- (void)onAppWillResignActive:(NSNotification*)notification {
    _appIsInActive = YES;
    if (_avRoom) {
        [_avRoom pause];
    }
}

- (void)onAppDidBecomeActive:(NSNotification*)notification {
    _appIsInActive = NO;
    if (!_appIsBackground && !_appIsInActive) {
        if (_avRoom) {
            [_avRoom resume];
        }
    }
}

- (void)onAppDidEnterBackGround:(NSNotification *)notification {
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    _appIsBackground = YES;
    if (_avRoom) {
        [_avRoom pause];
    }
}

- (void)onAppWillEnterForeground:(NSNotification *)notification {
    _appIsBackground = NO;
    if (!_appIsBackground && !_appIsInActive) {
        if (_avRoom) {
            [_avRoom resume];
        }
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    if (_avRoom) {
        [_avRoom stopLocalPreview];
        [_avRoom exitRoom:^(int result) {
            
        }];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - initUI

- (void)initUI {
    //主界面排版
    self.title = @"房间号群聊";
    [self.view setBackgroundImage: [UIImage imageNamed:@"background.jpg"]];
    
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    int ICON_SIZE = size.width / 10;
    
    _txtRoomId = [[UITextField alloc] initWithFrame:CGRectMake(10, 30 + ICON_SIZE + 10, size.width - 25, ICON_SIZE)];
    [_txtRoomId setBorderStyle:UITextBorderStyleRoundedRect];
    _txtRoomId.background = [UIImage imageNamed:@"Input_box"];
    _txtRoomId.placeholder = @"请输入房间号";
    _txtRoomId.delegate = self;
    _txtRoomId.alpha = 0.5;
    [self.view addSubview:_txtRoomId];
    
    float startSpace = 12;
    float centerInterVal = (size.width - 2 * startSpace - ICON_SIZE) / 7;
    float iconY = size.height - ICON_SIZE / 2 - 10;
    
    // 进房和退出按钮
    
    _btnJoin = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnJoin.center = CGPointMake(startSpace + ICON_SIZE / 2, iconY);
    _btnJoin.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnJoin setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
    [_btnJoin addTarget:self action:@selector(clickjoin:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnJoin];
    
    // 前置后置摄像头切换
    _camera_switch = NO;
    _btnCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnCamera.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 1, iconY);
    _btnCamera.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnCamera setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    [_btnCamera addTarget:self action:@selector(clickCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnCamera];
    
    // 美颜开关按钮
    _btnBeauty = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnBeauty.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 2, iconY);
    _btnBeauty.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnBeauty setImage:[UIImage imageNamed:@"beauty"] forState:UIControlStateNormal];
    [_btnBeauty addTarget:self action:@selector(clickBeauty:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnBeauty];
    
    // log显示或隐藏
    _log_switch = NO;
    _btnLog = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnLog.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 3, iconY);
    _btnLog.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnLog setImage:[UIImage imageNamed:@"log"] forState:UIControlStateNormal];
    [_btnLog addTarget:self action:@selector(clickLog:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnLog];
    
    // 填充/适应
    _renderFillScreen = YES;
    _btnRenderFillScreen = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnRenderFillScreen.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 4, iconY);
    _btnRenderFillScreen.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnRenderFillScreen setImage:[UIImage imageNamed:@"adjust"] forState:UIControlStateNormal];
    [_btnRenderFillScreen addTarget:self action:@selector(clickRenderFillScreen:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnRenderFillScreen];
    
    // 镜像
    _mirror_switch = NO;
    _btnMirror = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnMirror.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 5, iconY);
    _btnMirror.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnMirror setTitle:@"镜像" forState:UIControlStateNormal];
    _btnMirror.titleLabel.font = [UIFont systemFontOfSize:15];
    [_btnMirror setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_btnMirror setBackgroundColor:[UIColor whiteColor]];
    _btnMirror.layer.cornerRadius = _btnMirror.frame.size.width / 2;
    [_btnMirror setAlpha:0.5];
    [_btnMirror addTarget:self action:@selector(clickMirror:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnMirror];
    
    // 推流端静音(纯视频推流)
    _mute_switch = NO;
    _btnMute = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnMute.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 6, iconY);
    _btnMute.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnMute setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
    [_btnMute addTarget:self action:@selector(clickMute:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnMute];
    
    // 推流端静画(纯音频推流)
    _pure_switch = NO;
    _btnPure = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnPure.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 7, iconY);
    _btnPure.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnPure setImage:[UIImage imageNamed:@"camera_nol"] forState:UIControlStateNormal];
    [_btnPure addTarget:self action:@selector(clickPure:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnPure];
    
    
    NSUInteger controlHeight = [BeautySettingPanel getHeight];
    _vBeauty = [[BeautySettingPanel alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - controlHeight, self.view.frame.size.width, controlHeight)];
    _vBeauty.hidden = YES;
    _vBeauty.delegate = self;
    [self.view addSubview:_vBeauty];
    
#if TARGET_IPHONE_SIMULATOR
    [self toastTip:@"iOS模拟器不支持推流和播放，请使用真机体验"];
#endif
    
    CGRect previewFrame = self.view.bounds;
    _videoPreview = [[TXCAVRoomPlayerView alloc] init];
    _videoPreview.rect = previewFrame;
    _videoPreview.view.frame = _videoPreview.rect;
    [self.view insertSubview:_videoPreview.view atIndex:0];
    
    _currEvtStatsView = [self createEvtStatsView:0];
    _prevEvtStatsView = [self createEvtStatsView:1];
}


#pragma mark - TXCAVRoomListener
/**
 * 房间成员变化
 * flag为YES: 表示该userID进入房间
 * flag为NO: 表示该userID退出房间
 */
- (void)onMemberChange:(UInt64)userID withFlag:(BOOL)flag {
    if (flag) {
        NSLog(@"%llu enter room", userID);
    } else {
        NSLog(@"%llu exit room", userID);
    }
}

/**
 * 指定userID的视频状态变化通知
 * flag为YES: 表示该userID正在进行视频推流
 * flag为NO: 表示该userID已经停止视频推流
 */
- (void)onVideoStateChange:(UInt64)userID withFlag:(BOOL)flag {
    if (flag) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //
            TXCAVRoomPlayerView *playerView = [[TXCAVRoomPlayerView alloc] init];
            [playerView.view setBackgroundColor:[UIColor blackColor]];
            [self.view addSubview:playerView.view];
            
            [_playerViewDic setObject:playerView forKey:@(userID)];
            
            [self addEventStatusItem:userID];
            
            // 请求视频
            [_avRoom startRemoteView:playerView.view withUserID:userID];
            
            [self relayout];
            
            [self freshCurrentEvtStatsView];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            TXCAVRoomPlayerView *playerView = [_playerViewDic objectForKey:@(userID)];
            [playerView.view removeFromSuperview];
            [_playerViewDic removeObjectForKey:@(userID)];
            [self delEventStatusItem:userID];
            
            [self relayout];
        });
    }
}


- (void)onAVRoomEvent:(UInt64)userID withEventID:(int)eventID andParam:(NSDictionary *)param {
    if (eventID == AVROOM_EVT_UP_CHANGE_BITRATE) {
        // 这个事件会比较频繁，如果频繁刷新UI界面会导致主线程卡住
        return;
    }
    
    [self appendEventMsg:userID withEventID:eventID andParam:param];
    
    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
    
    if (eventID == AVROOM_WARNING_DISCONNECT)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_avRoom exitRoom:^(int result) {
                _roomStatus = AVROOM_IDLE;
                [_btnJoin setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            }];
        });
    }
}

- (void)onAVRoomStatus:(NSArray *)array {
    for (NSDictionary * statusItem in array) {
        [self getStatusDescription:statusItem];
    }
    
    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
}


#pragma mark - button
//加入或退出房间
- (void)clickjoin:(UIButton *)btn {
    
    if (_roomStatus == AVROOM_EXITING || _roomStatus == AVROOM_ENTERING) {
        return;
    }
    
    
    if (_roomStatus == AVROOM_IDLE) {
        _roomStatus = AVROOM_ENTERING;
        NSString *roomid = _txtRoomId.text;
        if (roomid == nil || [roomid  isEqual: @""]) {
            roomid = @"11";
            _txtRoomId.text = roomid;
        }
        
        //是否有摄像头权限
        AVAuthorizationStatus statusVideo = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (statusVideo == AVAuthorizationStatusDenied) {
            [self toastTip:@"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限"];
            return;
        }
        
        //是否有麦克风权限
        AVAuthorizationStatus statusAudio = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (statusAudio == AVAuthorizationStatusDenied) {
            [self toastTip:@"获取麦克风权限失败，请前往隐私-麦克风设置里面打开应用权限"];
            return;
        }
        
        [_evtStatsDataArray removeAllObjects];
        _evtStatsDataIndex = 0;
        
        [self addEventStatusItem:_selfUserID];
        
        _videoPreview.rect = self.view.frame;
        _videoPreview.view.frame = _videoPreview.rect;
        
        // 保留上次的设置
        if (!_pure_switch) {
            [_avRoom startLocalPreview:_videoPreview.view];
        }
        if (_mirror_switch) {
            [_avRoom setMirror:YES];
        }
        if (_renderFillScreen) {
            [_avRoom setRenderMode:AVROOM_RENDER_MODE_FILL_SCREEN];
        } else {
            [_avRoom setRenderMode:AVROOM_RENDER_MODE_FILL_EDGE];
        }
        
        //获取进房密钥
        NSString *urlStr = [NSString stringWithFormat:@"http://119.29.173.130:8000/getKey?account=%llu&appId=%d&authId=%d&privilegeMap=%d", _selfUserID ,1400044820, [roomid intValue], -1];
        NSURL *url = [[NSURL alloc] initWithString:urlStr];
        
        NSURLSession *session = [NSURLSession sharedSession];
        
        NSURLSessionTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if(error || httpResponse.statusCode != 200 || data == nil){
                //请求sig出错
                _roomStatus = AVROOM_IDLE;
                dispatch_async(dispatch_get_main_queue(), ^{
                     [self toastTip:@"sig拉取出错"];
                     [_avRoom stopLocalPreview];
                });
               
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                TXCAVRoomParam *avroomParam = [[TXCAVRoomParam alloc] init];
                avroomParam.roomID = [roomid intValue];
                avroomParam.authBits = AVROOM_AUTH_BITS_DEFAULT;
                avroomParam.authBuffer = data;
                
                
                [_avRoom enterRoom:avroomParam withCompletion:^(int result) {
                    NSLog(@"enterRoom result: %d", result);
                    if (result == 0) {//进房成功
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _roomStatus = AVROOM_ENTERED;
                            [self toastTip:@"进房成功!"];
                            [_btnJoin setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
                            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
                            
                            // 保留上次的设置
                            if (_mute_switch) {
                                [_avRoom setLocalMute:YES];
                            }
                            
                        });
                    }
                    else{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _roomStatus = AVROOM_IDLE;
                            [self toastTip:@"进房失败!"];
                            
                            [_avRoom exitRoom:^(int result) {
                            }];
                        });
                    }
                }];
            });
            
            
        }];
        [task resume];
        
        
        
    }
    else {
        _roomStatus = AVROOM_EXITING;
        [_avRoom exitRoom:^(int result) {
            _roomStatus = AVROOM_IDLE;
            dispatch_async(dispatch_get_main_queue(), ^{
                [_vBeauty resetValues];
                [_btnJoin setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
                [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
                
                [_evtStatsDataArray removeAllObjects];
                _evtStatsDataIndex = 0;
                
                for (id userID in _playerViewDic) {
                    TXCAVRoomPlayerView *playerView = [_playerViewDic objectForKey:userID];
                    [playerView.view removeFromSuperview];
                }
                [_playerViewDic removeAllObjects];
            });
        }];
        
    }
    
}





//切换摄像头
- (void)clickCamera:(UIButton*)btn {
    _camera_switch = !_camera_switch;
    [btn setImage:[UIImage imageNamed:(_camera_switch? @"camera2" : @"camera")] forState:UIControlStateNormal];
    if (_avRoom) {
        [_avRoom switchCamera];
    }
}

//设置美颜
- (void)clickBeauty:(UIButton *)btn {
    _vBeauty.hidden = NO;
    [self hideToolButtons:YES];
}


//设置镜像
- (void)clickMirror:(UIButton *)btn {
    _mirror_switch = !_mirror_switch;
    [_avRoom setMirror:_mirror_switch];
    
    if (_mirror_switch) {
        [_btnMirror setAlpha:1];
    } else {
        [_btnMirror setAlpha:0.5];
    }
}
//静音
- (void)clickMute:(UIButton *)btn {
    _mute_switch = !_mute_switch;
    [_avRoom setLocalMute:_mute_switch];
    
    if (_mute_switch) {
        [_btnMute setImage:[UIImage imageNamed:@"mic_dis"] forState:UIControlStateNormal];
    } else {
        [_btnMute setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
    }
}
//静画
- (void)clickPure:(UIButton *)btn {
    _pure_switch = !_pure_switch;
    if (_pure_switch) {
        [_btnPure setImage:[UIImage imageNamed:@"camera_dis"] forState:UIControlStateNormal];
        [_avRoom stopLocalPreview];
    } else {
        [_btnPure setImage:[UIImage imageNamed:@"camera_nol"] forState:UIControlStateNormal];
        if (_roomStatus == AVROOM_ENTERED) {
            [_avRoom startLocalPreview:_videoPreview.view];
        }
    }
}

- (void)clickLog:(UIButton *)btn {
    if (_log_switch) {
        _currEvtStatsView.hidden = YES;
        [btn setImage:[UIImage imageNamed:@"log"] forState:UIControlStateNormal];
        _log_switch = NO;
        
        [self setPlayerViewHighlight:-1];
    }
    else {
        _currEvtStatsView.hidden = NO;
        [btn setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
        _log_switch = YES;
        
        [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
        
        if (_evtStatsDataIndex < _evtStatsDataArray.count) {
            TXCAVRoomEventStatus* item = [_evtStatsDataArray objectAtIndex:_evtStatsDataIndex];
            [self setPlayerViewHighlight:item.userID];
        }
    }
    
    [self freshCurrentEvtStatsView];
}



- (void)hideToolButtons:(BOOL)bHide
{
    _btnJoin.hidden = bHide;
    _btnCamera.hidden = bHide;
    _btnBeauty.hidden = bHide;
    _btnLog.hidden = bHide;
    _btnMirror.hidden = bHide;
    _btnRenderFillScreen.hidden = bHide;
    _btnMute.hidden = bHide;
    _btnPure.hidden = bHide;
}

- (void)handleSwipes:(UISwipeGestureRecognizer *)sender {
    if (sender.direction == UISwipeGestureRecognizerDirectionLeft) {
        [self slideEvtStatsView:YES];
    }
    
    if (sender.direction == UISwipeGestureRecognizerDirectionRight) {
        [self slideEvtStatsView:NO];
    }
}

- (void)slideEvtStatsView:(BOOL)direction {
    _currEvtStatsView.hidden = NO;
    [_currEvtStatsView removeFromSuperview];
    [self.view addSubview:_currEvtStatsView];
    
    _prevEvtStatsView.hidden = NO;
    [_prevEvtStatsView removeFromSuperview];
    [self.view addSubview:_prevEvtStatsView];
    
    CGRect currFrame = _currEvtStatsView.frame;
    CGRect leftFrame = currFrame;
    CGRect rightFrame = currFrame;
    leftFrame.origin.x = -CGRectGetMaxX(currFrame);
    rightFrame.origin.x = [[UIScreen mainScreen] bounds].size.width;
    
    int evtStatsCount = (int)_evtStatsDataArray.count;
    int evtStatsIndex = ((direction ? _evtStatsDataIndex + 1 : _evtStatsDataIndex - 1) + evtStatsCount) % evtStatsCount;
    
    printf("slide count = %d currentIndex = %d nextIndex = %d\n", evtStatsCount, _evtStatsDataIndex, evtStatsIndex);
    
    _prevEvtStatsView.frame = direction ? rightFrame : leftFrame;
    [self updateEvtAndStats:_prevEvtStatsView index:evtStatsIndex];
    
    [UIView animateWithDuration:0.5f animations:^{
        _prevEvtStatsView.frame = currFrame;
        _currEvtStatsView.frame = direction ? leftFrame : rightFrame;
    } completion:^(BOOL finished) {
        if (finished) {
            UIView* tempView = _currEvtStatsView;
            _currEvtStatsView = _prevEvtStatsView;
            _prevEvtStatsView = tempView;
            
            _evtStatsDataIndex = evtStatsIndex;
            [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
            
            if (_evtStatsDataIndex < _evtStatsDataArray.count) {
                TXCAVRoomEventStatus* item = [_evtStatsDataArray objectAtIndex:_evtStatsDataIndex];
                [self setPlayerViewHighlight:item.userID];
            }
        }
    }];
}



- (void)clickRenderFillScreen:(UIButton *)btn {
    _renderFillScreen = !_renderFillScreen;
    
    if (_renderFillScreen) {
        [btn setImage:[UIImage imageNamed:@"adjust"] forState:UIControlStateNormal];
        [_avRoom setRenderMode:AVROOM_RENDER_MODE_FILL_SCREEN];
    } else {
        [btn setImage:[UIImage imageNamed:@"fill"] forState:UIControlStateNormal];
        [_avRoom setRenderMode:AVROOM_RENDER_MODE_FILL_EDGE];
    }
}



- (UIView *)createEvtStatsView:(int)index {
    CGSize size = [[UIScreen mainScreen] bounds].size;
    int ICON_SIZE = size.width / 10;
    
    UIView * view = [[UIView alloc] init];
    view.frame = CGRectMake(index == 0 ? 10.0f : size.width, 55 + 2 * ICON_SIZE, size.width - 20, size.height - 75 - 3 * ICON_SIZE);
    view.backgroundColor = [UIColor whiteColor];
    view.alpha = 0.5;
    view.hidden = YES;
    [self.view addSubview:view];
    
    int logheadH = 90;
    UITextView * statusView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, size.width - 20, logheadH)];
    statusView.backgroundColor = [UIColor clearColor];
    statusView.alpha = 1;
    statusView.textColor = [UIColor blackColor];
    statusView.editable = NO;
    statusView.tag = 0;
    [view addSubview:statusView];
    
    UITextView * eventView = [[UITextView alloc] initWithFrame:CGRectMake(0, logheadH, size.width - 20, size.height - 75 - 3 * ICON_SIZE - logheadH)];
    eventView.backgroundColor = [UIColor clearColor];
    eventView.alpha = 1;
    eventView.textColor = [UIColor blackColor];
    eventView.editable = NO;
    eventView.tag = 1;
    [view addSubview:eventView];
    
    UISwipeGestureRecognizer *recognizerLeft;
    recognizerLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
    [recognizerLeft setDirection:(UISwipeGestureRecognizerDirectionLeft)];
    [eventView addGestureRecognizer:recognizerLeft];
    
    UISwipeGestureRecognizer *recognizerRight;
    recognizerRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
    [recognizerRight setDirection:(UISwipeGestureRecognizerDirectionRight)];
    [eventView addGestureRecognizer:recognizerRight];
    
    return view;
}


- (void)updateEvtAndStats:(UIView*)view index: (int)index {
    if (_evtStatsDataArray.count == 0) {
        return;
    }
    
    if (index >= _evtStatsDataArray.count) {
        index = 0;
    }
    
    TXCAVRoomEventStatus * eventStatus = [_evtStatsDataArray objectAtIndex:index];
    
    for (UITextView * item in [view subviews]) {
        if (item.tag == 0) {
            [item setText:eventStatus.status];
        }
        else if (item.tag == 1) {
            [item setText:eventStatus.event];
        }
    }
}

- (void)freshCurrentEvtStatsView {
    if (_currEvtStatsView.hidden == NO) {
        [_currEvtStatsView removeFromSuperview];
        [self.view addSubview:_currEvtStatsView];
    }
}

- (void)setPlayerViewHighlight:(UInt64)userID {
    for (id item in _playerViewDic) {
        if (userID == [item unsignedLongLongValue]) {
            [_playerViewDic[item] setHighlight:YES];
        }
        else {
            [_playerViewDic[item] setHighlight:NO];
        }
    }
}



// 布局房间所有的视频画面
- (void)relayout {
    NSArray *userList = [_avRoom getRoomVideoList];  // 注意该函数获取的成员列表不包括自己
    
    if ([userList count] == 0) {
        _videoPreview.rect = self.view.frame;
        _videoPreview.view.frame = _videoPreview.rect;
        [self.view sendSubviewToBack:_videoPreview.view];
        
        [_avRoom setVideoBitrate:600 videoAspect:AVROOM_VIDEO_ASPECT_9_16];
        return;
    }
    else {
        // 如果房间里的人数为偶数，则自己在右下角，如果是奇数，则在下方。
        
        int rowNum = (int)[userList count] / 2 + 1 ;  // 行数
        int colNum = 2;    // 两列
        
        if ([userList count] == 1) {
            // 总共只有两个人的时候，一上一下
            rowNum = 2;
            colNum = 1;
        }
        
        int videoViewWidth = (self.view.size.width / colNum);
        int videoViewHeight = (self.view.size.height / rowNum);
        
        
        //
        int index = 0;
        for(id _tinyID in userList) {
            TXCAVRoomPlayerView *playerView = [_playerViewDic objectForKey:_tinyID];
            if (playerView) {
                playerView.rect = CGRectMake(videoViewWidth * (index % colNum), videoViewHeight * (index / colNum), videoViewWidth, videoViewHeight);
                playerView.view.frame = playerView.rect;
                
                [self.view sendSubviewToBack:playerView.view];
            }
            index ++;
            NSLog(@"----------- index == %d", index);
        }
        
        // [userList count] 为1或者为偶数的时候，本地预览在下面独占一行
        if ([userList count] == 1 || [userList count] % 2 == 0) {
            _videoPreview.rect = CGRectMake(0, videoViewHeight * (index / colNum), self.view.size.width, videoViewHeight);
            _videoPreview.view.frame = _videoPreview.rect;
        }
        else {
            _videoPreview.rect = CGRectMake(videoViewWidth, videoViewHeight * (index / colNum), videoViewWidth, videoViewHeight);
            _videoPreview.view.frame = _videoPreview.rect;
        }
        [self.view sendSubviewToBack:_videoPreview.view];
    }
    
    
    // 根据房间人数来设置上行码率，AVROOM内部的QOS模块会根据码率来自动调整分辨率
    // 视频编码分辨率可以按如下设置：
    // 人数   分辨率        分辨率比例
    // 1     360 * 640      9:16
    // 2     480 * 480      1:1
    // 3     270 * 480      9:16
    // 4     270 * 480      9:16
    // 5     270 * 270      1:1
    // 6     270 * 270      1:1
    // 7     160 * 160      1:1
    // 8     160 * 160      1:1
    
    unsigned long numPeople = 1 + [userList count];
    int videoBitrate = 600;
    int videoAspect = AVROOM_VIDEO_ASPECT_9_16;
    
    if (numPeople == 1) {
        videoBitrate = 600;
        videoAspect = AVROOM_VIDEO_ASPECT_9_16;
    } else if(numPeople == 2) {
        videoBitrate = 600;
        videoAspect = AVROOM_VIDEO_ASPECT_1_1;
    } else if (numPeople == 3 || numPeople == 4) {
        videoBitrate = 400;
        videoAspect = AVROOM_VIDEO_ASPECT_9_16;
    } else if (numPeople == 5 || numPeople == 6) {
        videoBitrate = 300;
        videoAspect = AVROOM_VIDEO_ASPECT_1_1;
    } else if (numPeople == 7 || numPeople == 8) {
        videoBitrate = 200;
        videoAspect = AVROOM_VIDEO_ASPECT_1_1;
    }
    
    [_avRoom setVideoBitrate:videoBitrate videoAspect:videoAspect];
}

- (NSString*)getStatusDescription: (NSDictionary*)dict {
    UInt64 userID = [(NSNumber *)[dict valueForKey:NET_STATUS_USER_ID] unsignedLongLongValue];
    int netspeed = [(NSNumber *) [dict valueForKey:NET_STATUS_NET_SPEED] intValue];
    int vbitrate = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_BITRATE] intValue];
    int abitrate = [(NSNumber *) [dict valueForKey:NET_STATUS_AUDIO_BITRATE] intValue];
    int cachesize = [(NSNumber *) [dict valueForKey:NET_STATUS_CACHE_SIZE] intValue];
    int dropsize = [(NSNumber *) [dict valueForKey:NET_STATUS_DROP_SIZE] intValue];
    int jitter = [(NSNumber *) [dict valueForKey:NET_STATUS_NET_JITTER] intValue];
    int fps = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_FPS] intValue];
    int width = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_WIDTH] intValue];
    int height = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_HEIGHT] intValue];
    float cpu_usage = [(NSNumber *) [dict valueForKey:NET_STATUS_CPU_USAGE] floatValue];
    float cpu_usage_ = [(NSNumber *) [dict valueForKey:NET_STATUS_CPU_USAGE_D] floatValue];
    int codecCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_CODEC_CACHE] intValue];
    int nCodecDropCnt = [(NSNumber *) [dict valueForKey:NET_STATUS_CODEC_DROP_CNT] intValue];
    NSString *serverIP = [dict valueForKey:NET_STATUS_SERVER_IP];
    int nSetVideoBitrate = [(NSNumber *) [dict valueForKey:NET_STATUS_SET_VIDEO_BITRATE] intValue];
    int videoCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_CACHE_SIZE] intValue];
    int vDecCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_V_DEC_CACHE_SIZE] intValue];
    int avPlayInterval = [(NSNumber *) [dict valueForKey:NET_STATUS_AV_PLAY_INTERVAL] intValue];
    int avRecvInterval = [(NSNumber *) [dict valueForKey:NET_STATUS_AV_RECV_INTERVAL] intValue];
    float audioPlaySpeed = [(NSNumber *) [dict valueForKey:NET_STATUS_AUDIO_PLAY_SPEED] floatValue];
    int videoGop = (int)([(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_GOP] doubleValue]+0.5f);
    NSString * audioInfo = [dict valueForKey:NET_STATUS_AUDIO_INFO];
    NSString *log = [NSString stringWithFormat:@"USER ID:%llu\n\nCPU:%.1f%%|%.1f%%\tRES:%d*%d\tSPD:%dkb/s\nJITT:%d\tFPS:%d\tGOP:%ds\tARA:%dkb/s\nQUE:%d|%d,%d,%d|%d,%d,%0.1f\tDRP:%d|%d\tVRA:%dkb/s\nSVR:%@\tAUDIO:%@",
                     userID,
                     cpu_usage_ * 100,
                     cpu_usage * 100,
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
                     avRecvInterval,
                     avPlayInterval,
                     audioPlaySpeed,
                     nCodecDropCnt,
                     dropsize,
                     vbitrate,
                     serverIP,
                     audioInfo];
    
    
    for (TXCAVRoomEventStatus * item in _evtStatsDataArray) {
        if (userID == item.userID) {
            item.status = log;
            break;
        }
    }
    
    return log;
}

- (void)appendEventMsg:(UInt64)userID withEventID:(int)eventID andParam:(NSDictionary *)param {
    long long time = [(NSNumber *)[param valueForKey:EVT_TIME] longLongValue];
    NSString *msg  = (NSString *)[param valueForKey:EVT_MSG];
    
    int millisecond = (int) (time % 1000);
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time / 1000];
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString *strTime = [format stringFromDate:date];
    
    NSString *eventMsg = [NSString stringWithFormat:@"[%@.%-3.3d] %@", strTime, millisecond, msg];
    
    for (TXCAVRoomEventStatus * item in _evtStatsDataArray) {
        if (userID == item.userID) {
            item.event = [NSString stringWithFormat:@"%@\n%@", item.event, eventMsg];
            break;
        }
    }
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _vBeauty.hidden = YES;
    [self hideToolButtons:NO];
}


/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param Width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
#pragma mark - misc func

- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

- (void)toastTip:(NSString*)toastInfo {
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
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^(){
        [toastView removeFromSuperview];
        toastView = nil;
    });
}

// iphone 6 及以上机型适合开启720p, 否则20帧的帧率可能无法达到, 这种"流畅不足,清晰有余"的效果并不好
- (BOOL)isSuitableMachine:(int)targetPlatNum {
    int mib[2] = {CTL_HW, HW_MACHINE};
    size_t len = 0;
    char *machine;
    
    sysctl(mib, 2, NULL, &len, NULL, 0);
    
    machine = (char *) malloc(len);
    sysctl(mib, 2, machine, &len, NULL, 0);
    
    NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];
    free(machine);
    
    NSRange range = [platform rangeOfString:@"iPhone"];
    if ([platform length] > 6 && range.location != NSNotFound) {
        NSRange range2 = [platform rangeOfString:@","];
        NSString *platNum = [platform substringWithRange:NSMakeRange(range.location + range.length, range2.location - range.location - range.length)];
        return ([platNum intValue] >= targetPlatNum);
    } else {
        return YES;
    }
}

- (void)addEventStatusItem:(UInt64)userID {
    for (TXCAVRoomEventStatus* item in _evtStatsDataArray) {
        if (item.userID == userID) {
            return;
        }
    }
    
    TXCAVRoomEventStatus* eventStatus = [[TXCAVRoomEventStatus alloc] init];
    eventStatus.userID = userID;
    [_evtStatsDataArray addObject:eventStatus];
}

- (void)delEventStatusItem:(UInt64)userID {
    for (TXCAVRoomEventStatus* item in _evtStatsDataArray) {
        if (item.userID == userID) {
            [_evtStatsDataArray removeObject:item];
            break;
        }
    }
}

#pragma mark - BeautySettingPanelDelegate
- (void)onSetBeautyStyle:(int)beautyStyle beautyLevel:(float)beautyLevel whitenessLevel:(float)whitenessLevel ruddinessLevel:(float)ruddinessLevel{
    [_avRoom setBeautyLevel:beautyLevel whitenessLevel:whitenessLevel ruddinessLevel:ruddinessLevel];
}

- (void)onSetEyeScaleLevel:(float)eyeScaleLevel {
    [_avRoom setEyeScaleLevel:eyeScaleLevel];
}

- (void)onSetFaceScaleLevel:(float)faceScaleLevel {
    [_avRoom setFaceScaleLevel:faceScaleLevel];
}

- (void)onSetFilter:(UIImage *)filterImage {
    [_avRoom setFilter:filterImage];
}


- (void)onSetGreenScreenFile:(NSURL *)file {
    [_avRoom setGreenScreenFile:file];
}

- (void)onSelectMotionTmpl:(NSString *)tmplName inDir:(NSString *)tmplDir {
    [_avRoom selectMotionTmpl:tmplName inDir:tmplDir];
}

- (void)onSetFaceVLevel:(float)vLevel{
    [_avRoom setFaceVLevel:vLevel];
}

- (void)onSetFaceShortLevel:(float)shortLevel{
    [_avRoom setFaceShortLevel:shortLevel];
}

- (void)onSetNoseSlimLevel:(float)slimLevel{
    [_avRoom setNoseSlimLevel:slimLevel];
}

- (void)onSetChinLevel:(float)chinLevel{
    [_avRoom setChinLevel:chinLevel];
}

- (void)onSetBeautyStyle:(int)style{
    [_avRoom setBeautyStyle:style];
}

- (void)onSetMixLevel:(float)mixLevel{
    [_avRoom setFilterMixLevel:mixLevel / 10.0];
}

- (void)onSetFaceBeautyLevel:(float)beautyLevel{
    
}
@end
