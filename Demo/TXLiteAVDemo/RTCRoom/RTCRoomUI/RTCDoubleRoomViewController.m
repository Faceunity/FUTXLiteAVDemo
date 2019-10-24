//
//  RTCDoubleRoomViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RTCDoubleRoomViewController.h"
#import "UIView+Additions.h"
#import "TXLiveSDKTypeDef.h"
#import <AVFoundation/AVFoundation.h>
#import "ColorMacro.h"
#import "RTCMsgListTableView.h"
#import "UIViewController+BackButtonHandler.h"
#import "RTCDoubleRoomListViewController.h"

@interface RTCDoubleRoomViewController () {
    UIView                   *_pusherView;
    NSMutableDictionary      *_playerViewDic;      // [userID, view]
    NSMutableDictionary      *_playerInfoDic;      // [userID, MemberInfo]
    NSMutableArray           *_placeViewArray;     // 用来界面显示占位,view
    NSMutableArray           *_userNameLabelArray; // 用来显示昵称,UILabel，放在对应的视频view上面
    
    UIButton                 *_btnCamera;
    UIButton                 *_btnBeauty;
    UIButton                 *_btnMute;
    UIButton                 *_btnLog;
    
    BOOL                     _camera_switch;
    BOOL                     _beauty_switch;
    BOOL                     _mute_switch;
    
    BOOL                     _appIsInActive;
    BOOL                     _appIsBackground;
    
    UITextView               *_logView;
    UIView                   *_coverView;
    NSInteger                _log_switch;  // 0:隐藏log  1:显示SDK内部的log  2:显示业务层log
    
    // 消息列表展示和输入
    RTCMsgListTableView      *_msgListView;
    UIView                   *_msgInputView;
    UITextField              *_msgInputTextField;
    UIButton                 *_msgSendBtn;
}
@end

@implementation RTCDoubleRoomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _playerViewDic = [[NSMutableDictionary alloc] init];
    _playerInfoDic = [[NSMutableDictionary alloc] init];
    _placeViewArray = [[NSMutableArray alloc] init];
    _userNameLabelArray = [[NSMutableArray alloc] init];
    
    _appIsInActive = NO;
    _appIsBackground = NO;
    
    [self initUI];
    [self initRoomLogic];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackGround:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];

}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (_rtcRoom) {
        [_rtcRoom exitRoom:^(int errCode, NSString *errMsg) {
            NSLog(@"exitRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
        }];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];

}

// 跳转到列表页
- (BOOL)navigationShouldPopOnBackButton {
    UIViewController *targetVC = nil;
    for (UIViewController *vc in self.navigationController.viewControllers) {
        if ([vc isKindOfClass:[RTCDoubleRoomListViewController class]]) {
            targetVC = vc;
            break;
        }
    }
    if (targetVC) {
        [self.navigationController popToViewController:targetVC animated:YES];
        return NO;
    }
    return YES;
}

- (void)initUI {
    self.title = _roomName;
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    int ICON_SIZE = size.width / 10;
    
    float startSpace = 30;
    float centerInterVal = (size.width - 2 * startSpace - ICON_SIZE) / 3;
    float iconY = size.height - ICON_SIZE / 2 - 10;
    
    // 前置后置摄像头切换
    _camera_switch = NO;
    _btnCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnCamera.center = CGPointMake(startSpace + ICON_SIZE/2, iconY);
    _btnCamera.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnCamera setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    [_btnCamera addTarget:self action:@selector(clickCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnCamera];
    
    // 美颜开关按钮
    _beauty_switch = YES;
    _btnBeauty = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnBeauty.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 1, iconY);
    _btnBeauty.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnBeauty setImage:[UIImage imageNamed:@"beauty"] forState:UIControlStateNormal];
    [_btnBeauty addTarget:self action:@selector(clickBeauty:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnBeauty];
    
    // 推流端静音(纯视频推流)
    _mute_switch = NO;
    _btnMute = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnMute.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 2, iconY);
    _btnMute.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnMute setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
    [_btnMute addTarget:self action:@selector(clickMute:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnMute];
    
    // log按钮
    _btnLog = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnLog.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 3, iconY);
    _btnLog.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnLog setImage:[UIImage imageNamed:@"log"] forState:UIControlStateNormal];
    [_btnLog addTarget:self action:@selector(clickLog:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnLog];
    
    // LOG界面
    _log_switch = 0;
    _logView = [[UITextView alloc] initWithFrame:CGRectMake(0, 80*kScaleY, size.width, size.height - 150*kScaleY)];
    _logView.backgroundColor = [UIColor clearColor];
    _logView.alpha = 1;
    _logView.textColor = [UIColor whiteColor];
    _logView.editable = NO;
    _logView.hidden = YES;
    [self.view addSubview:_logView];
    
    // 半透明浮层，用于方便查看log
    _coverView = [[UIView alloc] init];
    _coverView.frame = _logView.frame;
    _coverView.backgroundColor = [UIColor whiteColor];
    _coverView.alpha = 0.5;
    _coverView.hidden = YES;
    [self.view addSubview:_coverView];
    [self.view sendSubviewToBack:_coverView];
    
    // 消息列表展示和输入
    _msgListView = [[RTCMsgListTableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    [self.view addSubview:_msgListView];
    
    _msgInputView = [[UIView alloc] initWithFrame:CGRectZero];
    _msgInputView.backgroundColor = [UIColor clearColor];
    
    _msgInputTextField = [[UITextField alloc] initWithFrame:CGRectZero];
    _msgInputTextField.backgroundColor = UIColorFromRGB(0x4a4a4a);
    _msgInputTextField.returnKeyType = UIReturnKeySend;
    _msgInputTextField.placeholder = @"输入文字内容";
    _msgInputTextField.delegate = self;
    _msgInputTextField.textColor = UIColorFromRGB(0xb4b4b4);
    _msgInputTextField.font = [UIFont systemFontOfSize:14];
    
    _msgSendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_msgSendBtn setTitle:@"发送" forState:UIControlStateNormal];
    [_msgSendBtn setBackgroundColor:UIColorFromRGB(0x05a764)];
    [_msgSendBtn addTarget:self action:@selector(clickSend:) forControlEvents:UIControlEventTouchUpInside];
    
    [_msgInputView addSubview:_msgInputTextField];
    [_msgInputView addSubview:_msgSendBtn];
    [self.view addSubview:_msgInputView];
    
    
    // 开启推流和本地预览
    _pusherView = [[UIView alloc] initWithFrame:self.view.bounds];
    [_pusherView setBackgroundColor:UIColorFromRGB(0x262626)];
    [self.view insertSubview:_pusherView atIndex:0];
    [_rtcRoom startLocalPreview:_pusherView];
    
    // 设置分辨率和码率, 使用3:4比例，音频使用48K采样率
    [_rtcRoom setBitrateRange:400 max:800];
    [_rtcRoom setHDAudio:YES];
    
    // 设置默认美颜
    [_rtcRoom setBeautyStyle:1 beautyLevel:5 whitenessLevel:5 ruddinessLevel:5];
    
    [self relayout];
}

- (void)relayout {
    // 房间视频布局为rowNum行，colNum列，所有视频的布局范围为videoRectScope
    int rowNum = 1;
    int colNum = 2;
    CGRect videoRectScope = CGRectMake(0, 80*kScaleY, self.view.size.width, self.view.size.height - 150*kScaleY);
    
    int offsetX = 6 * kScaleX;  // 每个视频view之间的间距
    int offsetY = 24 * kScaleY;
    int videoViewWidth = (videoRectScope.size.width - (colNum-1) * offsetX) / colNum;
    int videoViewHeight = videoViewWidth * 4.0 / 3.0;  // 分辨率使用3:4
    if (videoViewHeight * rowNum > videoRectScope.size.height) {
        // 简单兼容下ipad
        videoViewHeight = (videoRectScope.size.height - (rowNum-1) * offsetY) / rowNum;
    }
    
    int row = 0;
    int col = 0;
    int originX = videoRectScope.origin.x + col * (offsetX + videoViewWidth);
    int originY = videoRectScope.origin.y + row * (offsetY + videoViewHeight);
    
    // 重置昵称布局
    for (UILabel *label in _userNameLabelArray) {
        [label removeFromSuperview];
    }
    [_userNameLabelArray removeAllObjects];
    
    // 先设置本地预览
    _pusherView.frame = CGRectMake(originX, originY, videoViewWidth, videoViewHeight);
    
    // 设置自己的昵称
    UIView *nickBackImg = [[UIView alloc] initWithFrame:CGRectMake(0, videoViewHeight - 22, videoViewWidth, 22)];
    [nickBackImg setBackgroundImage:[UIImage imageNamed:@"nick_mask"]];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, nickBackImg.width, nickBackImg.height)];
    label.text = _userName;
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentLeft;
    label.font = [UIFont systemFontOfSize:12];
    [nickBackImg addSubview:label];
    
    [_pusherView addSubview:nickBackImg];
    [_userNameLabelArray addObject:nickBackImg];
    
    
    // 设置其他remoteView
    int index = 1;
    for (id userID in _playerViewDic) {
        row = index / colNum;
        col = index % colNum;
        originX = videoRectScope.origin.x + col * (offsetX + videoViewWidth);
        originY = videoRectScope.origin.y + row * (offsetY + videoViewHeight);
        
        UIView *playerView = [_playerViewDic objectForKey:userID];
        playerView.frame = CGRectMake(originX, originY, videoViewWidth, videoViewHeight);
        ++ index;
        
        // 设置昵称
        PusherInfo *info = [_playerInfoDic objectForKey:userID];
        UIView *nickBackImg = [[UIView alloc] initWithFrame:CGRectMake(0, videoViewHeight - 22, videoViewWidth, 22)];
        [nickBackImg setBackgroundImage:[UIImage imageNamed:@"nick_mask"]];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, nickBackImg.width, nickBackImg.height)];
        label.text = info.userName;
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentLeft;
        label.font = [UIFont systemFontOfSize:12];
        [nickBackImg addSubview:label];
        
        [playerView addSubview:nickBackImg];
        [_userNameLabelArray addObject:nickBackImg];
        
        if (index >= rowNum * colNum) {
            break;
        }
    }
    
    // 设置占位view
    for (UIView *view in _placeViewArray) {
        [view removeFromSuperview];
    }
    [_placeViewArray removeAllObjects];
    
    for (int i = index; i < rowNum * colNum; ++i) {
        row = i / colNum;
        col = i % colNum;
        originX = videoRectScope.origin.x + col * (offsetX + videoViewWidth);
        originY = videoRectScope.origin.y + row * (offsetY + videoViewHeight);
        
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(originX, originY, videoViewWidth, videoViewHeight)];
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, view.width, view.height)];
        [imgView setBackgroundColor:UIColorFromRGB(0x262626)];
        [imgView setImage:[UIImage imageNamed:@"people"]];
        imgView.contentMode = UIViewContentModeCenter;
        imgView.clipsToBounds = YES;
        [view addSubview:imgView];
        
        [self.view addSubview:view];
        [_placeViewArray addObject:view];
    }
    
    
    // 重置功能按钮的位置
    int funcButtonY = originY + videoViewHeight + 10;
    _btnCamera.frame = CGRectMake(_btnCamera.x, funcButtonY, _btnCamera.width, _btnCamera.height);
    _btnBeauty.frame = CGRectMake(_btnBeauty.x, funcButtonY, _btnBeauty.width, _btnBeauty.height);
    _btnMute.frame = CGRectMake(_btnMute.x, funcButtonY, _btnMute.width, _btnMute.height);
    _btnLog.frame = CGRectMake(_btnLog.x, funcButtonY, _btnLog.width, _btnLog.height);
    
    _logView.frame = CGRectMake(0, 80*kScaleY, self.view.width, videoViewHeight);
    _coverView.frame = _logView.frame;
    
    
    // 设置消息列表位置
    int msgListViewY = funcButtonY + _btnCamera.height + 10;
    _msgListView.frame = CGRectMake(0, msgListViewY, self.view.width, self.view.height - msgListViewY - 50);
    
    
    // 消息发送框位置
    CGFloat offset = 0;
    if (@available(iOS 11, *)) {
        offset = [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
    }
    _msgInputView.frame = CGRectMake(0, self.view.height - 50 -offset, self.view.width, 50);
    _msgInputTextField.frame = CGRectMake(0, 0, _msgInputView.width - 100, _msgInputView.height);
    _msgSendBtn.frame = CGRectMake(_msgInputView.width - 100, 0, 100, _msgInputView.height);
}

- (void)initRoomLogic {
    if (_entryType == 1) {  // 房间创建者
        [_rtcRoom createRoom:@"" roomInfo:_roomName withCompletion:^(int errCode, NSString *errMsg) {
            NSLog(@"createRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errCode == 0) {
                    [self appendSystemMsg:@"连接成功"];
                    
                } else {
                    [self alertTips:@"创建会话失败" msg:errMsg completion:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
            });
            
        }];
    }
    else {   // 房间普通成员
        [_rtcRoom enterRoom:_roomID withCompletion:^(int errCode, NSString *errMsg) {
            NSLog(@"enterRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (errCode == 0) {
                    [self appendSystemMsg:@"连接成功"];
                    
                } else {
                    // 进房失败可能是因为人数超过限制，此时要先关闭播放，再弹窗提示
                    [_rtcRoom exitRoom:^(int errCode, NSString *errMsg) {
                        NSLog(@"进入会话失败,先调用exitRoom关闭播放，再弹窗: errCode[%d] errMsg[%@]", errCode, errMsg);
                    }];
                    
                    [self alertTips:@"进入会话失败" msg:errMsg completion:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
            });
        }];
    }
}


//切换摄像头
- (void)clickCamera:(UIButton*)btn {
    _camera_switch = !_camera_switch;
    if (_rtcRoom) {
        [_rtcRoom switchCamera];
    }
    [btn setImage:[UIImage imageNamed:(_camera_switch? @"camera2" : @"camera")] forState:UIControlStateNormal];
}

//设置美颜
- (void)clickBeauty:(UIButton *)btn {
    if (_rtcRoom && _beauty_switch) {
        _beauty_switch = NO;
        [btn setImage:[UIImage imageNamed:@"beauty_dis"] forState:UIControlStateNormal];
        [_rtcRoom setBeautyStyle:0 beautyLevel:0 whitenessLevel:0 ruddinessLevel:0];
    } else if (_rtcRoom && !_beauty_switch) {
        _beauty_switch = YES;
        [btn setImage:[UIImage imageNamed:@"beauty"] forState:UIControlStateNormal];
        [_rtcRoom setBeautyStyle:1 beautyLevel:5 whitenessLevel:5 ruddinessLevel:5];
    }
}

//静音
- (void)clickMute:(UIButton *)btn {
    _mute_switch = !_mute_switch;
    if (_rtcRoom) {
        [_rtcRoom setMute:_mute_switch];
    }
    [_btnMute setImage:[UIImage imageNamed:(_mute_switch ? @"mic_dis" : @"mic")] forState:UIControlStateNormal];
}

// 设置log显示
- (void)clickLog:(UIButton *)btn {
    switch (_log_switch) {
        case 0:
            _log_switch = 1;
            [_rtcRoom showVideoDebugLog:YES];
            _logView.hidden = YES;
            _coverView.hidden = YES;
            [btn setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
            break;
        case 1:
            _log_switch = 2;
            [_rtcRoom showVideoDebugLog:NO];
            _logView.hidden = NO;
            _coverView.hidden = NO;
            [self.view bringSubviewToFront:_logView];
            [btn setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
            break;
        case 2:
            _log_switch = 0;
            [_rtcRoom showVideoDebugLog:NO];
            _logView.hidden = YES;
            _coverView.hidden = YES;
            [btn setImage:[UIImage imageNamed:@"log"] forState:UIControlStateNormal];
            break;
        default:
            break;
    }
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
    CGFloat offset = 0;
    if (@available(iOS 11, *)) {
        if (endFrame.origin.y >= self.view.window.height) {
            offset = self.view.window.safeAreaInsets.bottom;
        }
    }
    [UIView animateWithDuration:0.25 animations:^{
        _msgInputView.y =  endFrame.origin.y - _msgInputView.height - offset;
    }];
}

- (void)appendLog:(NSString *)msg {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString *time = [format stringFromDate:[NSDate date]];
    NSString *log = [NSString stringWithFormat:@"[%@] %@", time, msg];
    NSString *logMsg = [NSString stringWithFormat:@"%@\n%@", _logView.text, log];
    [_logView setText:logMsg];
}

- (void)appendSystemMsg:(NSString *)msg {
    RTCMsgModel *msgMode = [[RTCMsgModel alloc] init];
    msgMode.type = RTCMsgModeTypeSystem;
    msgMode.userMsg = msg;
    [_msgListView appendMsg:msgMode];
}

#pragma mark - RTCRoomListener

- (void)onGetPusherList:(NSArray<PusherInfo *> *)pusherInfoArray {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 播放其他人的画面
        for (PusherInfo *pusherInfo in pusherInfoArray) {
            UIView *playerView = [[UIView alloc] init];
            [playerView setBackgroundColor:UIColorFromRGB(0x262626)];
            [self.view addSubview:playerView];
            
            [_playerViewDic setObject:playerView forKey:pusherInfo.userID];
            [_playerInfoDic setObject:pusherInfo forKey:pusherInfo.userID];
            
            [_rtcRoom addRemoteView:playerView withUserID:pusherInfo.userID playBegin:nil playError:^(int errCode, NSString *errMsg) {
                [self onPusherQuit:pusherInfo];
            }];
            
            [self relayout];
            
            //LOG
            [self appendLog:[NSString stringWithFormat:@"播放: userID[%@] userName[%@] playUrl[%@]", pusherInfo.userID, pusherInfo.userName, pusherInfo.playUrl]];
        }
    });
}

- (void)onPusherJoin:(PusherInfo *)pusherInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *playerView = [[UIView alloc] init];
        [playerView setBackgroundColor:UIColorFromRGB(0x262626)];
        [self.view addSubview:playerView];
        
        [_playerViewDic setObject:playerView forKey:pusherInfo.userID];
        [_playerInfoDic setObject:pusherInfo forKey:pusherInfo.userID];
        
        [_rtcRoom addRemoteView:playerView withUserID:pusherInfo.userID playBegin:nil playError:^(int errCode, NSString *errMsg) {
            [self onPusherQuit:pusherInfo];
        }];
        
        [self relayout];
    });
}

- (void)onPusherQuit:(PusherInfo *)pusherInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *playerView = [_playerViewDic objectForKey:pusherInfo.userID];
        [playerView removeFromSuperview];
        [_playerViewDic removeObjectForKey:pusherInfo.userID];
        [_playerInfoDic removeObjectForKey:pusherInfo.userID];
        
        [self relayout];
    });
}

- (void)onRoomClose:(NSString *)roomID {
    [self alertTips:@"提示" msg:@"会话已被解散" completion:^{
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (void)onDebugMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendLog:msg];
    });
}

- (void)onError:(int)errCode errMsg:(NSString *)errMsg {
    [self alertTips:@"提示" msg:errMsg completion:^{
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (void)onRecvRoomTextMsg:(NSString *)roomID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar textMsg:(NSString *)textMsg {
    RTCMsgModel *msgMode = [[RTCMsgModel alloc] init];
    msgMode.type = RTCMsgModeTypeOther;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = userName;
    msgMode.userMsg = textMsg;
    
    [_msgListView appendMsg:msgMode];
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

#pragma NSNotification
- (void)onAppWillResignActive:(NSNotification*)notification {
    _appIsInActive = YES;
    if (_rtcRoom) {
        [_rtcRoom switchToBackground:[UIImage imageNamed:@"pause_publish.jpg"]];
    }
}

- (void)onAppDidBecomeActive:(NSNotification*)notification {
    _appIsInActive = NO;
    if (!_appIsBackground && !_appIsInActive) {
        if (_rtcRoom) {
            [_rtcRoom switchToForeground];
        }
    }
}

- (void)onAppDidEnterBackGround:(NSNotification *)notification {
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    _appIsBackground = YES;
    if (_rtcRoom) {
        [_rtcRoom switchToBackground:[UIImage imageNamed:@"pause_publish.jpg"]];
    }
}

- (void)onAppWillEnterForeground:(NSNotification *)notification {
    _appIsBackground = NO;
    if (!_appIsBackground && !_appIsInActive) {
        if (_rtcRoom) {
            [_rtcRoom switchToForeground];
        }
    }
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
    NSString *textMsg = [textField.text stringByTrimmingCharactersInSet:[NSMutableCharacterSet whitespaceCharacterSet]];
    if (textMsg.length <= 0) {
        textField.text = @"";
        [self alertTips:@"提示" msg:@"消息不能为空" completion:nil];
        return YES;
    }
    
    RTCMsgModel *msgMode = [[RTCMsgModel alloc] init];
    msgMode.type = RTCMsgModeTypeOneself;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = _userName;
    msgMode.userMsg = textMsg;
    
    [_msgListView appendMsg:msgMode];
    
    _msgInputTextField.text = @"";
    [_msgInputTextField resignFirstResponder];
    
    // 发送
    [_rtcRoom sendRoomTextMsg:textMsg];
    
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_msgInputTextField resignFirstResponder];
}


@end
