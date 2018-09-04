//
//  AnswerRoomListViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/22.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "AnswerRoomListViewController.h"
#import "AnswerRoom.h"
#import "UIView+Additions.h"
#import "AnswerRoomPlayerViewController.h"
#import "AFNetworking.h"
#import "ColorMacro.h"
#import "AnswerRoomTableViewCell.h"
#import "AnswerRoomNewViewController.h"

#define kHttpServerAddrDomain           @"https://lvb.qcloud.com/weapp/live_room"
#define kHttpServerAddr_GetIMLoginInfo  kHttpServerAddrDomain@"/get_im_login_info"

@interface AnswerRoomListViewController () <UITableViewDelegate, UITableViewDataSource, AnswerRoomListener> {
    NSArray<RoomInfo *>  	 *_roomInfoArray;
    
    UILabel                  *_tipLabel;
    UITableView              *_roomlistView;
    UIButton                 *_createBtn;
    UIButton                 *_helpBtn;
    
    UIButton                 *_btnLog;
    UITextView               *_logView;
    BOOL                     _log_switch;
    UIView                   *_coverView;
    
    NSArray<NSString*>       *_nickNameArray;
    NSString                 *_nickName;
}

@property (nonatomic, strong) AnswerRoom *answerRoom;
@property (nonatomic, assign) BOOL     initSucc;

@end

@implementation AnswerRoomListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _answerRoom = [[AnswerRoom alloc] init];
    _answerRoom.delegate = self;
    
    _roomInfoArray = [[NSArray alloc] init];
    _nickNameArray = [[NSArray alloc] initWithObjects:@"李元芳", @"刘备", @"梦奇", @"王昭君", @"周瑜", @"鲁班", @"后裔", @"安其拉", @"亚瑟", @"曹操",
                      @"百里守约", @"东皇太一", @"花木兰", @"诸葛亮", @"黄忠", @"不知火舞", @"钟馗", @"李白", @"娜可露露", @"张飞", nil];
    _nickName = _nickNameArray[arc4random() % _nickNameArray.count];
    
    _initSucc = NO;
    
    [self initUI];
    
    // 从后台获取随机产生的userID，以及IMSDK所需要的appid、account_type, sig等信息
    AFHTTPSessionManager *httpSession = [AFHTTPSessionManager manager];
    [httpSession setRequestSerializer:[AFJSONRequestSerializer serializer]];
    [httpSession setResponseSerializer:[AFJSONResponseSerializer serializer]];
    [httpSession.requestSerializer willChangeValueForKey:@"timeoutInterval"];
    httpSession.requestSerializer.timeoutInterval = 5.0;
    [httpSession.requestSerializer didChangeValueForKey:@"timeoutInterval"];
    httpSession.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/xml", @"text/plain", nil];
    
    
    __weak __typeof(self) weakSelf = self;
    NSDictionary *param = @{@"userIDPrefix":@"iOS"};
    [httpSession POST:kHttpServerAddr_GetIMLoginInfo parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        if (errCode != 0) {
            NSLog(@"request IM login info failed: errCode[%d] errMsg[%@]", errCode, errMsg);
            [weakSelf alertTips:@"get_im_login_info请求失败" msg:errMsg];
            return;
        }
        
        SelfAccountInfo *userInfo = [[SelfAccountInfo alloc] init];
        userInfo.userID = responseObject[@"userID"];
        userInfo.sdkAppID = [responseObject[@"sdkAppID"] intValue];
        userInfo.accType = responseObject[@"accType"];
        userInfo.userSig = responseObject[@"userSig"];
        userInfo.userName = _nickName;
        userInfo.userAvatar = @"headpic.png";
        
        // 初始化AnswerRoom
        [weakSelf.answerRoom init:kHttpServerAddrDomain accountInfo:userInfo withCompletion:^(int errCode, NSString *errMsg) {
            NSLog(@"initIM errCode[%d] errMsg[%@]", errCode, errMsg);
            if (errCode == 0) {
                weakSelf.initSucc = YES;
            } else {
                [weakSelf alertTips:@"AnswerRoom init失败" msg:errMsg];
            }
        }];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"request IM login info failed: err[%@]", [error description]);
        [weakSelf alertTips:@"提示" msg:@"网络请求超时，请检查网络设置"];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [_answerRoom setDelegate:self];
    
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

- (void)initUI {
    self.title = @"在线答题室";
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(70*kScaleX, 200*kScaleY, self.view.width - 140*kScaleX, 60*kScaleY)];
    _tipLabel.textColor = UIColorFromRGB(0x999999);
    _tipLabel.text = @"当前没有进行中的直播\r\n请点击新建直播间";
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
    [_roomlistView registerClass:[AnswerRoomTableViewCell class] forCellReuseIdentifier:@"AnswerRoomTableViewCell"];
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
    [_createBtn setTitle:@"新建直播间" forState:UIControlStateNormal];
    [_createBtn addTarget:self action:@selector(onCreateBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_createBtn];
    
    // 查看帮助
    _helpBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.width - 160*kScaleX, self.view.height - 50*kScaleY, 100*kScaleX, 40*kScaleY)];
    [_helpBtn setImage:[UIImage imageNamed:@"help_small"] forState:UIControlStateNormal];
    [_helpBtn setTitle:@"查看帮助" forState:UIControlStateNormal];
    [_helpBtn setTitleColor:UIColorFromRGB(0x999999) forState:UIControlStateNormal];
    _helpBtn.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 5);
    _helpBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, -5);
    _helpBtn.backgroundColor = [UIColor clearColor];
    [_helpBtn addTarget:self action:@selector(clickHelp:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_helpBtn];
    
    // log按钮
    _btnLog = [[UIButton alloc] initWithFrame:CGRectMake(60*kScaleX, self.view.height - 50*kScaleY, 100*kScaleX, 40*kScaleY)];
    [_btnLog setImage:[UIImage imageNamed:@"look_log"] forState:UIControlStateNormal];
    [_btnLog setTitle:@"查看log" forState:UIControlStateNormal];
    [_btnLog setTitleColor:UIColorFromRGB(0x999999) forState:UIControlStateNormal];
    _btnLog.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 5);
    _btnLog.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, -5);
    _btnLog.backgroundColor = [UIColor clearColor];
    [_btnLog addTarget:self action:@selector(clickLog:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnLog];
    
    // LOG界面
    _log_switch = NO;
    _logView = [[UITextView alloc] initWithFrame:CGRectMake(0, 80*kScaleY, self.view.size.width, self.view.size.height - 150*kScaleY)];
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
}

- (void)requestRoomList {
    if (!_initSucc) {
        return;
    }
    
    [_answerRoom getRoomList:0 cnt:100 withCompletion:^(int errCode, NSString *errMsg, NSArray<RoomInfo *> *roomInfoArray) {
        NSLog(@"getRoomList errCode[%d] errMsg[%@]", errCode, errMsg);
        _roomInfoArray = roomInfoArray;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_roomlistView reloadData];
            if (_roomInfoArray.count) {
                _tipLabel.text = @"选择直播间点击进入";
                _tipLabel.frame = CGRectMake(14*kScaleX, 80*kScaleY, self.view.width, 30*kScaleY);
                _tipLabel.textAlignment = NSTextAlignmentLeft;
            } else {
                _tipLabel.text = @"当前没有进行中的直播\r\n请点击新建直播间";
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
    
    AnswerRoomNewViewController *newRoomController = [[AnswerRoomNewViewController alloc] init];
    newRoomController.answerRoom = _answerRoom;
    newRoomController.nickName = _nickName;
    [self.navigationController pushViewController:newRoomController animated:YES];
}

- (void)clickHelp:(UIButton *)sender {
    NSURL *helpUrl = [NSURL URLWithString:@"https://cloud.tencent.com/document/product/454/13863"];
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


#pragma mark - AnswerRoomListener

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
    static NSString *identify = @"AnswerRoomTableViewCell";
    AnswerRoomTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identify];
    if (cell == nil) {
        cell = [[AnswerRoomTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
    }
    if (indexPath.row >= _roomInfoArray.count) {
        return cell;
    }
    
    RoomInfo *roomInfo = _roomInfoArray[indexPath.row];
    
    //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    //cell.textLabel.text = roomInfo.roomName;
    //cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu人在线", roomInfo.memberInfos.count];
    //cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.52 alpha:1.0];
    
    cell.roomName = roomInfo.roomName;
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
    AnswerRoomPlayerViewController *vc = [[AnswerRoomPlayerViewController alloc] init];
    vc.roomID = roomInfo.roomID;
    vc.roomName = roomInfo.roomName;
    vc.nickName = _nickName;
    vc.answerRoom = _answerRoom;
    _answerRoom.delegate = vc;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 130;
}

@end
