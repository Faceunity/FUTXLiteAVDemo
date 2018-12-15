//
//  LiveRoomPusherViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/22.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "LiveRoomPusherViewController.h"
#import "UIView+Additions.h"
#import "TXLiveSDKTypeDef.h"
#import <AVFoundation/AVFoundation.h>
#import "ColorMacro.h"
#import "LiveRoomMsgListTableView.h"
#import "BeautySettingPanel.h"
#import "UIViewController+BackButtonHandler.h"
#import "LiveRoomListViewController.h"
#import "LiveRoomPlayerItemView.h"



#import "FUManager.h"
#import <FUAPIDemoBar/FUAPIDemoBar.h>

typedef NS_ENUM(NSInteger, PKStatus) {
    PKStatus_IDLE,         // 空闲状态
    PKStatus_REQUESTING,   // 请求PK中
    PKStatus_BEING,        // PK中
};

@interface LiveRoomPusherViewController () <
                LiveRoomListener,
                UITextFieldDelegate,
                BeautySettingPanelDelegate,
                UITableViewDelegate,
                UITableViewDataSource,

                FUAPIDemoBarDelegate
                > {
    UIView                   *_pusherView;
    NSMutableDictionary      *_playerViewDic;  // 小主播的画面，[userID, view]
    NSMutableDictionary      *_playerItemDic;  // 小主播的loading画面，[userID, playerItem]
    
    BeautySettingPanel       *_vBeauty;  // 美颜界面组件
    
    UIButton                 *_btnChat;
    UIButton                 *_btnCamera;
    UIButton                 *_btnBeauty;
    UIButton                 *_btnMute;
    UIButton                 *_btnPK;
    UIButton                 *_btnLog;
    
    BOOL                     _camera_switch;
    BOOL                     _beauty_switch;
    BOOL                     _mute_switch;
    
    BOOL                     _appIsInActive;
    BOOL                     _appIsBackground;
    BOOL                     _hasPendingRequest;
    
    UITextView               *_logView;
    UIView                   *_coverView;
    NSInteger                _log_switch;  // 0:隐藏log  1:显示SDK内部的log  2:显示业务层log
    
    // 消息列表展示和输入
    LiveRoomMsgListTableView *_msgListView;
    UIView                   *_msgListCoverView; // 用于盖在消息列表上以监听点击事件
    UIView                   *_msgInputView;
    UITextField              *_msgInputTextField;
    UIButton                 *_msgSendBtn;
    
    CGPoint                  _touchBeginLocation;
    UITextView               *_toastView;
    
    PKStatus                 _pkStatus;             // PK状态
    NSArray                  *_roomCreatorList;     // 所有的房间主播列表(不包括自己），用于作为PK的目标
    UITableView              *_roomCreatorListView; // 用于展示主播列表
}



@property (nonatomic, strong) FUAPIDemoBar *demoBar ;
@end

@implementation LiveRoomPusherViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _playerViewDic = [[NSMutableDictionary alloc] init];
    _playerItemDic = [[NSMutableDictionary alloc] init];
    _roomCreatorList = [[NSArray alloc] init];
    
    _appIsInActive = NO;
    _appIsBackground = NO;
    _hasPendingRequest = NO;
    
    [self initUI];
    [self initRoomLogic];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    
    [[FUManager shareManager] loadItems];
    [self.view addSubview:self.demoBar];
    [FUManager shareManager].showFaceUnityEffect = YES ;
}


-(FUAPIDemoBar *)demoBar {
    if (!_demoBar) {
        
        _demoBar = [[FUAPIDemoBar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 164 -50, self.view.frame.size.width, 164)];
        
        _demoBar.itemsDataSource = [FUManager shareManager].itemsDataSource;
        _demoBar.selectedItem = [FUManager shareManager].selectedItem ;
        
        _demoBar.filtersDataSource = [FUManager shareManager].filtersDataSource ;
        _demoBar.beautyFiltersDataSource = [FUManager shareManager].beautyFiltersDataSource ;
        _demoBar.filtersCHName = [FUManager shareManager].filtersCHName ;
        _demoBar.selectedFilter = [FUManager shareManager].selectedFilter ;
        [_demoBar setFilterLevel:[FUManager shareManager].selectedFilterLevel forFilter:[FUManager shareManager].selectedFilter] ;
        
        _demoBar.skinDetectEnable = [FUManager shareManager].skinDetectEnable;
        _demoBar.blurShape = [FUManager shareManager].blurShape ;
        _demoBar.blurLevel = [FUManager shareManager].blurLevel ;
        _demoBar.whiteLevel = [FUManager shareManager].whiteLevel ;
        _demoBar.redLevel = [FUManager shareManager].redLevel;
        _demoBar.eyelightingLevel = [FUManager shareManager].eyelightingLevel ;
        _demoBar.beautyToothLevel = [FUManager shareManager].beautyToothLevel ;
        _demoBar.faceShape = [FUManager shareManager].faceShape ;
        
        _demoBar.enlargingLevel = [FUManager shareManager].enlargingLevel ;
        _demoBar.thinningLevel = [FUManager shareManager].thinningLevel ;
        _demoBar.enlargingLevel_new = [FUManager shareManager].enlargingLevel_new ;
        _demoBar.thinningLevel_new = [FUManager shareManager].thinningLevel_new ;
        _demoBar.jewLevel = [FUManager shareManager].jewLevel ;
        _demoBar.foreheadLevel = [FUManager shareManager].foreheadLevel ;
        _demoBar.noseLevel = [FUManager shareManager].noseLevel ;
        _demoBar.mouthLevel = [FUManager shareManager].mouthLevel ;
        
        _demoBar.delegate = self;
    }
    return _demoBar ;
}

/**      FUAPIDemoBarDelegate       **/

- (void)demoBarDidSelectedItem:(NSString *)itemName {
    
    [[FUManager shareManager] loadItem:itemName];
}

- (void)demoBarBeautyParamChanged {
    
    [FUManager shareManager].skinDetectEnable = _demoBar.skinDetectEnable;
    [FUManager shareManager].blurShape = _demoBar.blurShape;
    [FUManager shareManager].blurLevel = _demoBar.blurLevel ;
    [FUManager shareManager].whiteLevel = _demoBar.whiteLevel;
    [FUManager shareManager].redLevel = _demoBar.redLevel;
    [FUManager shareManager].eyelightingLevel = _demoBar.eyelightingLevel;
    [FUManager shareManager].beautyToothLevel = _demoBar.beautyToothLevel;
    [FUManager shareManager].faceShape = _demoBar.faceShape;
    [FUManager shareManager].enlargingLevel = _demoBar.enlargingLevel;
    [FUManager shareManager].thinningLevel = _demoBar.thinningLevel;
    [FUManager shareManager].enlargingLevel_new = _demoBar.enlargingLevel_new;
    [FUManager shareManager].thinningLevel_new = _demoBar.thinningLevel_new;
    [FUManager shareManager].jewLevel = _demoBar.jewLevel;
    [FUManager shareManager].foreheadLevel = _demoBar.foreheadLevel;
    [FUManager shareManager].noseLevel = _demoBar.noseLevel;
    [FUManager shareManager].mouthLevel = _demoBar.mouthLevel;
    
    [FUManager shareManager].selectedFilter = _demoBar.selectedFilter ;
    [FUManager shareManager].selectedFilterLevel = _demoBar.selectedFilterLevel;
}


















- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackGround:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (_liveRoom) {
        // 正在PK中就结束PK
        if (_pkStatus == PKStatus_BEING) {
            for (id userID in _playerViewDic) {
                [_liveRoom sendPKFinishRequest:userID];
            }
        }
        
        [_liveRoom exitRoom:^(int errCode, NSString *errMsg) {
            NSLog(@"exitRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
        }];
    }
    
    // 美颜初始化为默认值
    [_vBeauty resetValues];
    [_vBeauty trigglerValues];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 跳转到列表页
- (BOOL)navigationShouldPopOnBackButton {
    UIViewController *targetVC = nil;
    for (UIViewController *vc in self.navigationController.viewControllers) {
        if ([vc isKindOfClass:[LiveRoomListViewController class]]) {
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
    self.title = [NSString stringWithFormat:@"%@(%@)", _roomName, _userName];
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    int ICON_SIZE = size.width / 10;
    
    float startSpace = 30;
    float centerInterVal = (size.width - 2 * startSpace - ICON_SIZE) / 5;
    float iconY = size.height - ICON_SIZE / 2 - 10;
    
    // 聊天
    _btnChat = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnChat.center = CGPointMake(startSpace + ICON_SIZE/2, iconY);
    _btnChat.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnChat setImage:[UIImage imageNamed:@"comment"] forState:UIControlStateNormal];
    [_btnChat addTarget:self action:@selector(clickChat:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnChat];
    
    // 前置后置摄像头切换
    _camera_switch = NO;
    _btnCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnCamera.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 1, iconY);
    _btnCamera.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnCamera setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    [_btnCamera addTarget:self action:@selector(clickCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnCamera];
    
    // 美颜开关按钮
    _beauty_switch = YES;
    _btnBeauty = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnBeauty.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 2, iconY);
    _btnBeauty.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnBeauty setImage:[UIImage imageNamed:@"beauty"] forState:UIControlStateNormal];
    [_btnBeauty addTarget:self action:@selector(clickBeauty:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnBeauty];
    
    // 推流端静音(纯视频推流)
    _mute_switch = NO;
    _btnMute = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnMute.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 3, iconY);
    _btnMute.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnMute setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
    [_btnMute addTarget:self action:@selector(clickMute:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnMute];
    
    // PK按钮
    _pkStatus = PKStatus_IDLE;
    _btnPK = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnPK.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 4, iconY);
    _btnPK.bounds = CGRectMake(0, 0, ICON_SIZE, ICON_SIZE);
    [_btnPK setImage:[UIImage imageNamed:@"pk_start"] forState:UIControlStateNormal];
    [_btnPK addTarget:self action:@selector(clickPK:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnPK];
    
    // log按钮
    _btnLog = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnLog.center = CGPointMake(startSpace + ICON_SIZE/2 + centerInterVal * 5, iconY);
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
    _msgListView = [[LiveRoomMsgListTableView alloc] initWithFrame:CGRectMake(10, self.view.height/3, 300, self.view.height/2) style:UITableViewStyleGrouped];
    _msgListView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_msgListView];
    
    _msgListCoverView = [[UIView alloc] initWithFrame:_msgListView.frame];
    _msgListCoverView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_msgListCoverView];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickMsgListCoverView:)];
    [_msgListCoverView addGestureRecognizer:tapGesture];
    
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
    
    // 美颜
    NSUInteger controlHeight = [BeautySettingPanel getHeight];
    _vBeauty = [[BeautySettingPanel alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - controlHeight, self.view.frame.size.width, controlHeight)];
    _vBeauty.hidden = YES;
    _vBeauty.delegate = self;
    [self.view addSubview:_vBeauty];
    
    // 主播列表(用于PK)
    _roomCreatorListView = [[UITableView alloc] initWithFrame:CGRectMake((_btnPK.left + _btnPK.right) / 2.0 - 50, _btnPK.top-250, 128, 230)];
    _roomCreatorListView.hidden = YES;
    _roomCreatorListView.delegate = self;
    _roomCreatorListView.dataSource = self;
    _roomCreatorListView.backgroundColor = UIColorFromRGB(0X333333);
    _roomCreatorListView.allowsMultipleSelection = NO;
    _roomCreatorListView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _roomCreatorListView.separatorInset = UIEdgeInsetsMake(0, 0, 2, 0);
    [self.view addSubview:_roomCreatorListView];
    
    // 提示
    _toastView = [[UITextView alloc] init];
    _toastView.editable = NO;
    _toastView.selectable = NO;
    
    // 开启推流和本地预览
    _pusherView = [[UIView alloc] initWithFrame:self.view.frame];
    [_pusherView setBackgroundColor:UIColorFromRGB(0x262626)];
    [self.view insertSubview:_pusherView atIndex:0];
    [_liveRoom startLocalPreview:_pusherView];
    
    // 美颜初始化为默认值
    [_vBeauty resetValues];
    [_vBeauty trigglerValues];
}

- (void)relayout {
    // 重新布局小主播的画面
    int index = 0;
    int originX = self.view.width - 110;
    int originY = self.view.height - 250;
    int videoViewWidth = 100;
    int videoViewHeight = 150;
    
    // 区分PK和普通直播(连麦)
    if (_pkStatus == PKStatus_BEING) {
        originX = self.view.width / 2.0;
        originY = 0;
        videoViewWidth = self.view.width / 2.0;
        videoViewHeight = videoViewWidth * 16.0 / 9.0;
        _pusherView.frame = CGRectMake(0, 0, videoViewWidth, videoViewHeight); // 9:16
        _msgListView.frame = CGRectMake(10, videoViewHeight + 6, self.view.width - 20, self.view.height - videoViewHeight - self.view.width / 10 - 30);
 
    } else {
        _pusherView.frame = CGRectMake(0, 0, self.view.width, self.view.height);
        _msgListView.frame = CGRectMake(10, self.view.height/3, 300, self.view.height/2);
    }
    
    for (id userID in _playerViewDic) {
        UIView *playerView = [_playerViewDic objectForKey:userID];
        playerView.frame = CGRectMake(originX, originY - videoViewHeight * index, videoViewWidth, videoViewHeight);
        ++ index;
        
        LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:userID];
        playerItem.frame = CGRectMake(playerView.frame.origin.x+ (playerView.width-16)/2,
                                      playerView.frame.origin.y + (playerView.height-16)/2,
                                      16, 16);
    }
}

- (void)initRoomLogic {
    [_liveRoom createRoom:@"" roomInfo:_roomName withCompletion:^(int errCode, NSString *errMsg) {
        NSLog(@"createRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errCode == 0) {
                [self appendSystemMsg:@"连接成功"];
                
            } else {
                [self alertTips:@"创建直播间失败" msg:errMsg completion:^{
                    [self.navigationController popViewControllerAnimated:YES];
                }];
            }
        });
        
    }];
}

// 聊天
- (void)clickChat:(UIButton *)btn {
    [_msgInputTextField becomeFirstResponder];
}

// 切换摄像头
- (void)clickCamera:(UIButton *)btn {
    _camera_switch = !_camera_switch;
    if (_liveRoom) {
        [_liveRoom switchCamera];
    }
    [btn setImage:[UIImage imageNamed:(_camera_switch? @"camera2" : @"camera")] forState:UIControlStateNormal];
}

// 设置美颜
- (void)clickBeauty:(UIButton *)btn {
    _vBeauty.hidden = NO;
    [self.view bringSubviewToFront:_vBeauty];
    [self hideToolButtons:YES];
}

- (void)hideToolButtons:(BOOL)bHide {
    _btnChat.hidden = bHide;
    _btnCamera.hidden = bHide;
    _btnBeauty.hidden = bHide;
    _btnMute.hidden = bHide;
    _btnLog.hidden = bHide;
    _msgListCoverView.hidden = !bHide;
}

// 静音
- (void)clickMute:(UIButton *)btn {
    _mute_switch = !_mute_switch;
    if (_liveRoom) {
        [_liveRoom setMute:_mute_switch];
    }
    [_btnMute setImage:[UIImage imageNamed:(_mute_switch ? @"mic_dis" : @"mic")] forState:UIControlStateNormal];
}

// PK
- (void)clickPK:(UIButton *)btn {
    // 正在PK中就结束PK
    if (_pkStatus == PKStatus_BEING) {
        for (id userID in _playerViewDic) {
            [_liveRoom sendPKFinishRequest:userID];
        }
        [self deletePKView];
        
        return;
    }
    
    // 正在连麦中(判断有没有player即可)，就返回
    if (_playerViewDic.count) {
        return;
    }
    
    _roomCreatorListView.hidden = !_roomCreatorListView.hidden;
    [_roomCreatorListView reloadData];
    
    [_liveRoom getOnlinePusherList:^(NSArray<PusherInfo *> *pusherInfoArray) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _roomCreatorList = pusherInfoArray;
            [_roomCreatorListView reloadData];
        });
    }];
}

// 设置log显示
- (void)clickLog:(UIButton *)btn {
    switch (_log_switch) {
        case 0:
            _log_switch = 1;
            [_liveRoom showVideoDebugLog:YES];
            _logView.hidden = YES;
            _coverView.hidden = YES;
            [btn setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
            break;
        case 1:
            _log_switch = 2;
            [_liveRoom showVideoDebugLog:NO];
            _logView.hidden = NO;
            _coverView.hidden = NO;
            [self.view bringSubviewToFront:_logView];
            [btn setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
            break;
        case 2:
            _log_switch = 0;
            [_liveRoom showVideoDebugLog:NO];
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
    [UIView animateWithDuration:0.25 animations:^{
        if (endFrame.origin.y == self.view.height) {
            _msgInputView.y = endFrame.origin.y;
        } else {
            _msgInputView.y =  endFrame.origin.y - _msgInputView.height;
        }
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
    LiveRoomMsgModel *msgMode = [[LiveRoomMsgModel alloc] init];
    msgMode.type = LiveRoomMsgModeTypeSystem;
    msgMode.userMsg = msg;
    [_msgListView appendMsg:msgMode];
}

#pragma mark - LiveRoomListener

- (void)onRoomClose:(NSString *)roomID {
    [self alertTips:@"提示" msg:@"直播间已被解散" completion:^{
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
    LiveRoomMsgModel *msgMode = [[LiveRoomMsgModel alloc] init];
    msgMode.type = LiveRoomMsgModeTypeOther;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = userName;
    msgMode.userMsg = textMsg;
    
    [_msgListView appendMsg:msgMode];
}

/**
   获取房间pusher列表的回调通知
 */
- (void)onGetPusherList:(NSArray<PusherInfo *> *)pusherInfoArray {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 播放其他人的画面
        for (PusherInfo *pusherInfo in pusherInfoArray) {
            UIView *playerView = [[UIView alloc] init];
            [playerView setBackgroundColor:UIColorFromRGB(0x262626)];
            
            // 加入关闭(踢人)按钮
            UIButton *btnKick = [UIButton buttonWithType:UIButtonTypeCustom];
            btnKick.frame = CGRectMake(84, 0, 16, 16);
            [btnKick setBackgroundImage:[UIImage imageNamed:@"linkmic_kickout"] forState:UIControlStateNormal];
            [btnKick setTitleColor:[UIColor clearColor] forState:UIControlStateNormal];
            btnKick.titleLabel.text = pusherInfo.userID;  // 小技巧，保存对应的userID
            [btnKick addTarget:self action:@selector(clickKickoutBtn:) forControlEvents:UIControlEventTouchUpInside];
            
            [playerView addSubview:btnKick];
            [self.view addSubview:playerView];
            
            // loading界面
            LiveRoomPlayerItemView *playerItem = [[LiveRoomPlayerItemView alloc] init];
            [self.view addSubview:playerItem];
            
            [_playerViewDic setObject:playerView forKey:pusherInfo.userID];
            [_playerItemDic setObject:playerItem forKey:pusherInfo.userID];
            
            // 重新布局
            [self relayout];
            [playerItem startLoadingAnimation];
          
            [_liveRoom addRemoteView:playerView withUserID:pusherInfo.userID playBegin:^{
                LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:pusherInfo.userID];
                [playerItem stopLoadingAnimation];
                
            } playError:^(int errCode, NSString *errMsg) {
                [self kickout:pusherInfo.userID];
            }];
            
            //LOG
            [self appendLog:[NSString stringWithFormat:@"播放: userID[%@] userName[%@] playUrl[%@]", pusherInfo.userID, pusherInfo.userName, pusherInfo.playUrl]];
        }
    });
}

/**
   新的pusher加入直播(连麦)
 */
- (void)onPusherJoin:(PusherInfo *)pusherInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 如果正在PK中，则将小主播踢出去
        if (_pkStatus == PKStatus_BEING) {
            [_liveRoom kickoutSubPusher:pusherInfo.userID];
            return;
        }
        
        UIView *playerView = [[UIView alloc] init];
        [playerView setBackgroundColor:UIColorFromRGB(0x262626)];
        
        // 加入关闭(踢人)按钮
        UIButton *btnKick = [UIButton buttonWithType:UIButtonTypeCustom];
        btnKick.frame = CGRectMake(84, 0, 16, 16);
        [btnKick setBackgroundImage:[UIImage imageNamed:@"linkmic_kickout"] forState:UIControlStateNormal];
        [btnKick setTitleColor:[UIColor clearColor] forState:UIControlStateNormal];
        btnKick.titleLabel.text = pusherInfo.userID;  // 小技巧，保存对应的userID
        [btnKick addTarget:self action:@selector(clickKickoutBtn:) forControlEvents:UIControlEventTouchUpInside];
        
        [playerView addSubview:btnKick];
        [self.view addSubview:playerView];
        
        // loading界面
        LiveRoomPlayerItemView *playerItem = [[LiveRoomPlayerItemView alloc] init];
        [self.view addSubview:playerItem];
        
        [_playerViewDic setObject:playerView forKey:pusherInfo.userID];
        [_playerItemDic setObject:playerItem forKey:pusherInfo.userID];
        
        // 重新布局
        [self relayout];
        [playerItem startLoadingAnimation];
        
        [_liveRoom addRemoteView:playerView withUserID:pusherInfo.userID playBegin:^{
            LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:pusherInfo.userID];
            [playerItem stopLoadingAnimation];
            
        } playError:^(int errCode, NSString *errMsg) {
            [self kickout:pusherInfo.userID];
        }];
    });
}

/**
   pusher退出直播(连麦)的通知
 */
- (void)onPusherQuit:(PusherInfo *)pusherInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (pusherInfo != nil && pusherInfo.userID != nil) {
            UIView *playerView = [_playerViewDic objectForKey:pusherInfo.userID];
            if (playerView != nil) {
                [playerView removeFromSuperview];
                [_playerViewDic removeObjectForKey:pusherInfo.userID];
            }
        
            LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:pusherInfo.userID];
            if (playerItem != nil) {
                [playerItem removeFromSuperview];
                [_playerItemDic removeObjectForKey:pusherInfo.userID];
            }
        
            [self relayout];
        }
    });
}

/**
   大主播收到连麦请求
 */
- (void)onRecvJoinPusherRequest:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar {
    if (_hasPendingRequest || _pkStatus != PKStatus_IDLE) {
        [_liveRoom rejectJoinPusher:userID reason:@"请稍后，主播正忙"];
        return;
    }
    
    _hasPendingRequest = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [NSString stringWithFormat:@"[%@]请求连麦", userName];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"拒绝" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _hasPendingRequest = NO;
            [_liveRoom rejectJoinPusher:userID reason:@"主播不同意您的连麦"];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"接受" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _hasPendingRequest = NO;
            [_liveRoom acceptJoinPusher:userID];
        }]];

        [self.navigationController presentViewController:alertController animated:YES completion:nil];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _hasPendingRequest = NO;
            [alertController dismissViewControllerAnimated:NO completion:nil];
        });
    });
}

/**
   主播收到PK请求
   @param userID     PK请求者的userID
   @param userName   PK请求者的昵称
   @param userAvatar PK请求者的头像URL
   @param streamUrl  PK请求者的流地址
 */
- (void)onRecvPKRequest:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar streamUrl:(NSString *)streamUrl {
    if (_hasPendingRequest || _pkStatus != PKStatus_IDLE || _playerViewDic.count) {
        [_liveRoom rejectPKRequest:userID reason:@"请稍后，主播正忙"];
        return;
    }
    
    _hasPendingRequest = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [NSString stringWithFormat:@"[%@]请求PK", userName];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"拒绝" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _hasPendingRequest = NO;
            [_liveRoom rejectPKRequest:userID reason:@"主播不同意您的PK"];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"接受" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _hasPendingRequest = NO;
            [_liveRoom acceptPKRequest:userID];
            [self addPKView:userID playUrl:streamUrl];
        }]];
        
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _hasPendingRequest = NO;
            [alertController dismissViewControllerAnimated:NO completion:nil];
        });
    });
}

/**
   主播收到结束PK的请求
   @param userID     PK请求者的userID
 */
- (void)onRecvPKFinishRequest:(NSString *)userID {
    [self deletePKView];
    [self toastTip:@"对方结束PK" time:2];
}

// 播放PK主播的画面
- (void)addPKView:(NSString *)userID playUrl:(NSString *)playUrl {
    UIView *playerView = [[UIView alloc] init];
    [playerView setBackgroundColor:UIColorFromRGB(0x262626)];
    [self.view addSubview:playerView];
    
    // loading界面
    LiveRoomPlayerItemView *playerItem = [[LiveRoomPlayerItemView alloc] init];
    [self.view addSubview:playerItem];
    
    [_playerViewDic setObject:playerView forKey:userID];
    [_playerItemDic setObject:playerItem forKey:userID];
    
    _pkStatus = PKStatus_BEING;  // PK中
    [_btnPK setImage:[UIImage imageNamed:@"pk_stop"] forState:UIControlStateNormal];
    
    // 重新布局
    _roomCreatorListView.hidden = YES;
    [self relayout];
    [playerItem startLoadingAnimation];
    
    [_liveRoom startPlayPKStream:playUrl view:playerView playBegin:^{
        LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:userID];
        [playerItem stopLoadingAnimation];
        
    } playError:^(int errCode, NSString *errMsg) {
        [_liveRoom sendPKFinishRequest:userID];
        [self deletePKView];
    }];
}

// 删除PK主播的画面
- (void)deletePKView {
    [_liveRoom stopPlayPKStream];
    
    for (id userID in _playerViewDic) {
        UIView *playerView = [_playerViewDic objectForKey:userID];
        [playerView removeFromSuperview];
        
        LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:userID];
        [playerItem removeFromSuperview];
    }
    
    [_playerViewDic removeAllObjects];
    [_playerItemDic removeAllObjects];
    
    _pkStatus = PKStatus_IDLE;  // 空闲状态
    [_btnPK setImage:[UIImage imageNamed:@"pk_start"] forState:UIControlStateNormal];
    [self relayout];
}

// 连麦模式，大主播踢掉小主播
- (void)clickKickoutBtn:(UIButton *)btn {
    NSString *userID = btn.titleLabel.text;
    [self kickout:userID];
}

- (void)kickout:(NSString *)userID {
    [_liveRoom kickoutSubPusher:userID];
    
    UIView *playerView = [_playerViewDic objectForKey:userID];
    [playerView removeFromSuperview];
    [_playerViewDic removeObjectForKey:userID];
    
    LiveRoomPlayerItemView *playerItem = [_playerItemDic objectForKey:userID];
    [playerItem removeFromSuperview];
    [_playerItemDic removeObjectForKey:userID];
    
    [self relayout];
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
    if (_liveRoom) {
        [_liveRoom switchToBackground:[UIImage imageNamed:@"pause_publish.jpg"]];
    }
}

- (void)onAppDidBecomeActive:(NSNotification*)notification {
    _appIsInActive = NO;
    if (!_appIsBackground && !_appIsInActive) {
        if (_liveRoom) {
            [_liveRoom switchToForeground];
        }
    }
}

- (void)onAppDidEnterBackGround:(NSNotification *)notification {
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    _appIsBackground = YES;
    if (_liveRoom) {
        [_liveRoom switchToBackground:[UIImage imageNamed:@"pause_publish.jpg"]];
    }
}

- (void)onAppWillEnterForeground:(NSNotification *)notification {
    _appIsBackground = NO;
    if (!_appIsBackground && !_appIsInActive) {
        if (_liveRoom) {
            [_liveRoom switchToForeground];
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
    
    LiveRoomMsgModel *msgMode = [[LiveRoomMsgModel alloc] init];
    msgMode.type = LiveRoomMsgModeTypeOther;
    msgMode.time = [[NSDate date] timeIntervalSince1970];
    msgMode.userName = _userName;
    msgMode.userMsg = textMsg;
    
    [_msgListView appendMsg:msgMode];
    
    _msgInputTextField.text = @"";
    [_msgInputTextField resignFirstResponder];
    
    // 发送
    [_liveRoom sendRoomTextMsg:textMsg];
    
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_msgInputTextField resignFirstResponder];
    _vBeauty.hidden = YES;
    _roomCreatorListView.hidden = YES;
    [self hideToolButtons:NO];
    
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

- (void)clickMsgListCoverView:(UITapGestureRecognizer *)gestureRecognizer {
    _msgListCoverView.hidden = YES;
    
    [_msgInputTextField resignFirstResponder];
    _vBeauty.hidden = YES;
    _roomCreatorListView.hidden = YES;
    [self hideToolButtons:NO];
}

#pragma mark - BeautySettingPanelDelegate

- (void)onSetBeautyStyle:(int)beautyStyle beautyLevel:(float)beautyLevel whitenessLevel:(float)whitenessLevel ruddinessLevel:(float)ruddinessLevel{
    [_liveRoom setBeautyStyle:beautyStyle beautyLevel:beautyLevel whitenessLevel:whitenessLevel ruddinessLevel:ruddinessLevel];
}

- (void)onSetEyeScaleLevel:(float)eyeScaleLevel {
    [_liveRoom setEyeScaleLevel:eyeScaleLevel];
}

- (void)onSetFaceScaleLevel:(float)faceScaleLevel {
    [_liveRoom setFaceScaleLevel:faceScaleLevel];
}

- (void)onSetFilter:(UIImage *)filterImage {
    [_liveRoom setFilter:filterImage];
}


- (void)onSetGreenScreenFile:(NSURL *)file {
    [_liveRoom setGreenScreenFile:file];
}

- (void)onSelectMotionTmpl:(NSString *)tmplName inDir:(NSString *)tmplDir {
    [_liveRoom selectMotionTmpl:tmplName inDir:tmplDir];
}

- (void)onSetFaceVLevel:(float)vLevel{
    [_liveRoom setFaceVLevel:vLevel];
}

- (void)onSetFaceShortLevel:(float)shortLevel{
    [_liveRoom setFaceShortLevel:shortLevel];
}

- (void)onSetNoseSlimLevel:(float)slimLevel{
    [_liveRoom setNoseSlimLevel:slimLevel];
}

- (void)onSetChinLevel:(float)chinLevel{
    [_liveRoom setChinLevel:chinLevel];
}

- (void)onSetMixLevel:(float)mixLevel{
    [_liveRoom setSpecialRatio:mixLevel / 10.0];
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"请选择主播";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _roomCreatorList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"RoomCreatorCellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    
    if (indexPath.row >= _roomCreatorList.count) {
        return cell;
    }
    
    PusherInfo *pusherInfo = _roomCreatorList[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"昵称: %@", pusherInfo.userName];
    cell.backgroundColor = [UIColor blackColor];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= _roomCreatorList.count) {
        return;
    }
    
    _roomCreatorListView.hidden = !_roomCreatorListView.hidden;
    
    PusherInfo *pusherInfo = _roomCreatorList[indexPath.row];
    [self sendPKRequest:pusherInfo.userID];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 20;
}

- (void)sendPKRequest:(NSString *)userID {
    if (userID == nil) {
        return;
    }
    
    if (_pkStatus == PKStatus_IDLE) {  // 空闲状态
        _pkStatus = PKStatus_REQUESTING;  // 请求PK中
        [self toastTip:@"PK请求已发出，等待对方的接受..." time:10];
        [_liveRoom sendPKReques:userID timeout:10 withCompletion:^(int errCode, NSString *errMsg, NSString *streamUrl) {
            if (errCode == 0) {
                _pkStatus = PKStatus_BEING; // PK中
                [self addPKView:userID playUrl:streamUrl];
                [self toastTip:@"对方接受了您的请求，开始PK" time:2];
            } else {
                _pkStatus = PKStatus_IDLE;  // 空闲状态
                [self toastTip:errMsg time:2];
            }
        }];
    }
}

/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

- (void)toastTip:(NSString *)toastInfo time:(NSInteger)time {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_toastView removeFromSuperview];
        
        CGRect frameRC = [[UIScreen mainScreen] bounds];
        frameRC.origin.y = frameRC.size.height - 110;
        frameRC.size.height -= 110;
        frameRC.size.height = [self heightForString:_toastView andWidth:frameRC.size.width];
        
        _toastView.frame = frameRC;
        
        _toastView.text = toastInfo;
        _toastView.backgroundColor = [UIColor whiteColor];
        _toastView.alpha = 0.5;
        
        [self.view addSubview:_toastView];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        
        dispatch_after(popTime, dispatch_get_main_queue(), ^() {
            [_toastView removeFromSuperview];
        });
    });
}

@end

