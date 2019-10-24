//
//  RTCDoubleRoomListViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/31.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RTCDoubleRoomListViewController.h"
#import "RTCRoom.h"
#import "UIView+Additions.h"
#import "RTCDoubleRoomViewController.h"
#import "AFNetworking.h"
#import "ColorMacro.h"
#import "RTCRoomTableViewCell.h"
#import "RTCRoomNewViewController.h"
#import "AppDelegate.h"

#define kHttpServerAddrDomain           @"https://room.qcloud.com/weapp/double_room"
#define kHttpServerAddr_GetLoginInfo    @"https://room.qcloud.com/weapp/utils/get_login_info"

@interface RTCDoubleRoomListViewController () <UITableViewDelegate, UITableViewDataSource, RTCRoomListener> {
    NSArray<RoomInfo *>  	 *_roomInfoArray;
    
    UILabel                  *_tipLabel;
    UITableView              *_roomlistView;
    UIButton                 *_createBtn;
    UIButton                 *_helpBtn;
    
    UIButton                 *_btnLog;
    UITextView               *_logView;
    BOOL                     _log_switch;
    UIView                   *_coverView;
    
    NSArray<NSString*>       *_userNameArray;
    NSString                 *_userName;
}

@property (nonatomic, strong) RTCRoom *rtcRoom;
@property (nonatomic, assign) BOOL    initSucc;

@end

@implementation RTCDoubleRoomListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _rtcRoom = [[RTCRoom alloc] init];
    _rtcRoom.delegate = self;
    
    _roomInfoArray = [[NSArray alloc] init];
    _userNameArray = [[NSArray alloc] initWithObjects:@"李元芳", @"刘备", @"梦奇", @"王昭君", @"周瑜", @"鲁班", @"后裔", @"安其拉", @"亚瑟", @"曹操",
                      @"百里守约", @"东皇太一", @"花木兰", @"诸葛亮", @"黄忠", @"不知火舞", @"钟馗", @"李白", @"娜可露露", @"张飞", nil];
    _userName = _userNameArray[arc4random() % _userNameArray.count];
    
    _initSucc = NO;
    
    [self initUI];
    
    __block NSString * userID = [[NSUserDefaults standardUserDefaults] objectForKey: @"userID"];
    NSString * strCgiUrl = kHttpServerAddr_GetLoginInfo;
    if (userID != nil && userID.length > 0) {
        strCgiUrl = [NSString stringWithFormat:@"%@?userID=%@", kHttpServerAddr_GetLoginInfo, userID];
    }
    
    // 从后台获取随机产生的userID，以及IMSDK所需要的appid、account_type, sig等信息
    AFHTTPSessionManager *httpSession = [AFHTTPSessionManager manager];
    [httpSession setRequestSerializer:[AFJSONRequestSerializer serializer]];
    [httpSession setResponseSerializer:[AFJSONResponseSerializer serializer]];
    [httpSession.requestSerializer willChangeValueForKey:@"timeoutInterval"];
    httpSession.requestSerializer.timeoutInterval = 5.0;
    [httpSession.requestSerializer didChangeValueForKey:@"timeoutInterval"];
    httpSession.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/xml", @"text/plain", nil];

    __weak __typeof(self) weakSelf = self;
    __weak AFHTTPSessionManager *weakManager = httpSession;
    [httpSession GET:strCgiUrl parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        NSNumber * sdkAppID = responseObject[@"sdkAppID"];
        NSString * userSig = responseObject[@"userSig"];
        NSString * accType = responseObject[@"accType"];
        if (errCode != 0) {
            NSLog(@"request login info failed: errCode[%d] errMsg[%@]", errCode, errMsg);
            [weakSelf alertTips:@"获取登录信息失败" msg:errMsg];
            return;
        }
        
        if (userID == nil || userID.length == 0) {
            userID = responseObject[@"userID"];
            if (userID == nil || userID.length == 0) {
                NSLog(@"request login info failed: invalid userID");
                [weakSelf alertTips:@"获取登录信息失败" msg: @"用户账号非法"];
                return;
            }
            else {
                [[NSUserDefaults standardUserDefaults] setObject:userID forKey:@"userID"];
            }
        }

        LoginInfo *loginInfo = [LoginInfo new];
        loginInfo.sdkAppID = [sdkAppID intValue];
        loginInfo.userID = userID;
        loginInfo.userName = _userName;
        loginInfo.userAvatar = @"headpic.png";
        loginInfo.userSig = userSig;
        loginInfo.accType = accType;
        
        // 初始化RTCRoom
        [weakSelf.rtcRoom login:kHttpServerAddrDomain loginInfo:loginInfo withCompletion:^(int errCode, NSString *errMsg) {
            NSLog(@"init RTCRoom errCode[%d] errMsg[%@]", errCode, errMsg);
            if (errCode == 0) {
                weakSelf.initSucc = YES;
            } else {
                [weakSelf alertTips:@"rtcRoom init失败" msg:errMsg];
            }
        }];
        [weakManager invalidateSessionCancelingTasks:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"request login info failed: err[%@]", [error description]);
        [weakSelf alertTips:@"提示" msg:@"网络请求超时，请检查网络设置"];
        [weakManager invalidateSessionCancelingTasks:YES];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [_rtcRoom setDelegate:self];
    
    // 请求房间列表
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self requestRoomList];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    [_rtcRoom logout:nil];
}

- (void)initUI {
    self.title = @"双人音视频";
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(70*kScaleX, 200*kScaleY, self.view.width - 140*kScaleX, 60*kScaleY)];
    _tipLabel.textColor = UIColorFromRGB(0x999999);
    _tipLabel.text = @"当前没有进行中的会话\r\n请点击新建会话";
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.numberOfLines = 2;
    _tipLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_tipLabel];
    
    _roomlistView = [[UITableView alloc] initWithFrame:CGRectMake(12*kScaleX, 120*kScaleY, self.view.width - 24*kScaleX, 400*kScaleY)];
    _roomlistView.delegate = self;
    _roomlistView.dataSource = self;
    _roomlistView.backgroundColor = [UIColor clearColor];
    _roomlistView.allowsMultipleSelection = NO;
    _roomlistView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_roomlistView registerClass:[RTCRoomTableViewCell class] forCellReuseIdentifier:@"RTCRoomTableViewCell"];
    [self.view addSubview:_roomlistView];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshClick:) forControlEvents:UIControlEventValueChanged];
    [_roomlistView addSubview:refreshControl];
    //[refreshControl beginRefreshing];
    //[self refreshClick:refreshControl];
    
    _createBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _createBtn.frame = CGRectMake(40*kScaleX, self.view.height - 100*kScaleY, self.view.width - 80*kScaleX, 50*kScaleY);
    _createBtn.layer.cornerRadius = 8;
    _createBtn.layer.masksToBounds = YES;
    _createBtn.layer.shadowOffset = CGSizeMake(1, 1);
    _createBtn.layer.shadowColor = UIColorFromRGB(0x019b5c).CGColor;
    _createBtn.layer.shadowOpacity = 0.8;
    _createBtn.backgroundColor = UIColorFromRGB(0x05a764);
    [_createBtn setTitle:@"新建会话" forState:UIControlStateNormal];
    [_createBtn addTarget:self action:@selector(onCreateBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_createBtn];
    
    // 查看帮助
//    _helpBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.width - 160*kScaleX, self.view.height - 50*kScaleY, 120*kScaleX, 40*kScaleY)];
//    [_helpBtn setImage:[UIImage imageNamed:@"help_small"] forState:UIControlStateNormal];
//    [_helpBtn setTitle:@"查看帮助" forState:UIControlStateNormal];
//    [_helpBtn setTitleColor:UIColorFromRGB(0x999999) forState:UIControlStateNormal];
//    _helpBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 5);
//    _helpBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, -5);
//    _helpBtn.backgroundColor = [UIColor clearColor];
//    [_helpBtn addTarget:self action:@selector(clickHelp:) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:_helpBtn];
//    
//    // log按钮
//    _btnLog = [[UIButton alloc] initWithFrame:CGRectMake(60*kScaleX, self.view.height - 50*kScaleY, 120*kScaleX, 40*kScaleY)];
//    [_btnLog setImage:[UIImage imageNamed:@"look_log"] forState:UIControlStateNormal];
//    [_btnLog setTitle:@"查看log" forState:UIControlStateNormal];
//    [_btnLog setTitleColor:UIColorFromRGB(0x999999) forState:UIControlStateNormal];
//    _btnLog.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 5);
//    _btnLog.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, -5);
//    _btnLog.backgroundColor = [UIColor clearColor];
//    [_btnLog addTarget:self action:@selector(clickLog:) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:_btnLog];
    
    // LOG界面
    _log_switch = NO;
    _logView = [[UITextView alloc] initWithFrame:CGRectMake(0, 80*kScaleY, self.view.size.width, self.view.size.height - 150*kScaleY)];
    _logView.backgroundColor = [UIColor clearColor];
    _logView.alpha = 1;
    _logView.textColor = [UIColor whiteColor];
    _logView.editable = NO;
    _logView.hidden = YES;
    [self.view addSubview:_logView];
    
#ifdef APPSTORE
    _helpBtn.hidden = YES;
    _btnLog.hidden = YES;
#endif
    
    // 半透明浮层，用于方便查看log
    _coverView = [[UIView alloc] init];
    _coverView.frame = _logView.frame;
    _coverView.backgroundColor = [UIColor whiteColor];
    _coverView.alpha = 0.5;
    _coverView.hidden = YES;
    [self.view addSubview:_coverView];
    [self.view sendSubviewToBack:_coverView];
    
    HelpBtnUI(双人音视频)
}

- (void)requestRoomList {
    if (!_initSucc) {
        return;
    }
    
    [_rtcRoom getRoomList:0 cnt:100 withCompletion:^(int errCode, NSString *errMsg, NSArray<RoomInfo *> *roomInfoArray) {
        NSLog(@"getRoomList errCode[%d] errMsg[%@]", errCode, errMsg);
        _roomInfoArray = roomInfoArray;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_roomlistView reloadData];
            if (_roomInfoArray.count) {
                _tipLabel.text = @"选择会话点击进入";
                _tipLabel.frame = CGRectMake(14*kScaleX, 80*kScaleY, self.view.width, 30*kScaleY);
                _tipLabel.textAlignment = NSTextAlignmentLeft;
            } else {
                _tipLabel.text = @"当前没有进行中的会话\r\n请点击新建会话";
                _tipLabel.frame = CGRectMake(70*kScaleX, 200*kScaleY, self.view.width - 140*kScaleX, 60*kScaleY);
                _tipLabel.textAlignment = NSTextAlignmentCenter;
            }
        });
    }];
}

- (void)refreshClick:(UIRefreshControl *)refreshControl {
    [refreshControl endRefreshing];
    
    [self requestRoomList];
}

- (void)onCreateBtnClicked:(UIButton *)sender {
    if (!_initSucc) {
        //[self alertTips:@"提示" msg:@"正在初始化，请稍后再试"];
        return;
    }
    
    RTCRoomNewViewController *newRoomController = [[RTCRoomNewViewController alloc] init];
    newRoomController.rtcRoom = _rtcRoom;
    newRoomController.userName = _userName;
    newRoomController.roomType = 1;
    [self.navigationController pushViewController:newRoomController animated:YES];
}

- (void)clickHelp:(UIButton *)sender {
    NSURL *helpUrl = [NSURL URLWithString:@"https://cloud.tencent.com/document/product/454/12521"];
    UIApplication *myApp = [UIApplication sharedApplication];
    if ([myApp canOpenURL:helpUrl]) {
        [myApp openURL:helpUrl];
    }
}

- (void)clickLog:(UIButton *)sender {
    if (!_log_switch) {
        _log_switch = YES;
        _logView.hidden = NO;
        _coverView.hidden = NO;
        [self.view bringSubviewToFront:_logView];
    }
    else {
        _log_switch = NO;
        _logView.hidden = YES;
        _coverView.hidden = YES;
    }
}

- (void)appendLog:(NSString *)msg {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString *time = [format stringFromDate:[NSDate date]];
    NSString *log = [NSString stringWithFormat:@"[%@] %@", time, msg];
    NSString *logMsg = [NSString stringWithFormat:@"%@\n%@", _logView.text, log];
    [_logView setText:logMsg];
}


#pragma mark - RTCRoomListener

- (void)onGetPusherList:(NSArray<PusherInfo *> *)pusherInfoArray {
    
}

- (void)onPusherJoin:(PusherInfo *)pusherInfo {
    
}

- (void)onPusherQuit:(PusherInfo *)pusherInfo {
    
}


- (void)onRoomClose:(NSString *)roomID {
    
}

- (void)onDebugMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendLog:msg];
    });
}

- (void)onError:(int)errCode errMsg:(NSString *)errMsg {
    
}

- (void)alertTips:(NSString *)title msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }]];
        
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
    });
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _roomInfoArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identify = @"RTCRoomTableViewCell";
    RTCRoomTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identify];
    if (cell == nil) {
        cell = [[RTCRoomTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
    }
    if (indexPath.row >= _roomInfoArray.count) {
        return cell;
    }
    
    RoomInfo *roomInfo = _roomInfoArray[indexPath.row];
    
    //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    //cell.textLabel.text = roomInfo.roomName;
    //cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu人在线", roomInfo.memberInfos.count];
    //cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.52 alpha:1.0];
    
    cell.roomInfo = roomInfo.roomInfo;
    cell.roomID = roomInfo.roomID;
    cell.memberNum = [roomInfo.pusherInfoArray count];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= _roomInfoArray.count) {
        return;
    }
    RoomInfo *roomInfo = _roomInfoArray[indexPath.row];
    
    // 视图跳转
    RTCDoubleRoomViewController *vc = [[RTCDoubleRoomViewController alloc] init];
    vc.entryType = 2;
    vc.roomID = roomInfo.roomID;
    vc.roomName = roomInfo.roomInfo;
    vc.userName = _userName;
    vc.rtcRoom = _rtcRoom;
    _rtcRoom.delegate = vc;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 130;
}

@end
