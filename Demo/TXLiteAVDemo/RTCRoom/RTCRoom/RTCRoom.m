//
//  RTCRoom.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RTCRoom.h"
#import "TXLiveSDKTypeDef.h"
#import "TXLivePush.h"
#import "TXLivePlayer.h"
#import "AFNetworking.h"
#import "RoomMsgMgr.h"
#import "TXLiveBase.h"
#import "RoomUtil.h"

// 业务服务器API
#define kHttpServerAddr_GetRoomList     @"get_room_list"
#define kHttpServerAddr_GetPushUrl      @"get_push_url"
#define kHttpServerAddr_GetPushers      @"get_pushers"
#define kHttpServerAddr_CreateRoom      @"create_room"
#define kHttpServerAddr_AddPusher       @"add_pusher"
#define kHttpServerAddr_DeletePusher    @"delete_pusher"
#define kHttpServerAddr_PusherHeartBeat @"pusher_heartbeat"
#define kHttpServerAddr_GetIMLoginInfo  @"get_im_login_info"
#define kHttpServerAddr_Logout          @"logout"
#define kHttpServerAddr_Report          @"report"


@interface RTCRoom() <TXLivePushListener, IRoomLivePlayListener, RoomMsgListener, RoomReportDelegate> {
    TXLivePush              *_livePusher;
    NSMutableDictionary     *_livePlayerDic;  // [userID, player]
    NSMutableDictionary     *_playerEventDic; // [userID, RoomLivePlayListenerWrapper]
    RoomInfo                *_roomInfo;       // 注意这个RoomInfo里面的pusherInfoArray不包含自己
    AFHTTPSessionManager    *_httpSession;
    NSString                *_serverDomain;   // 保存业务服务器域名
    NSMutableDictionary     *_apiAddr;        // 保存业务服务器相关的rest api
    
    SelfAccountInfo         *_userInfo;
    NSString                *_pushUrl;
    NSString                *_roomID;

    NSMutableArray          *_roomInfos;

    dispatch_source_t       _heartBeatTimer;
    dispatch_queue_t        _queue;
    
    int                     _roomRole;        // 房间角色，创建者:1 普通成员:2, 用于在推流成功后做不同处理
    BOOL                    _background;
    BOOL                    _mutePusher;
    
    RoomStatisticInfo*            _roomStatisticInfo;
}

@property (atomic, strong) RoomMsgMgr *                  msgMgr;
@property (atomic, strong) ICreateRoomCompletionHandler  createRoomCompletion;
@property (atomic, strong) IEnterRoomCompletionHandler   enterRoomCompletion;

@end

@implementation RTCRoom

- (instancetype)init {
    if (self = [super init]) {
        [self initLivePusher];
        
        _livePlayerDic = [[NSMutableDictionary alloc] init];
        _playerEventDic = [[NSMutableDictionary alloc] init];
        _roomInfo = [[RoomInfo alloc] init];
        
        _httpSession = [AFHTTPSessionManager manager];
        [_httpSession setRequestSerializer:[AFJSONRequestSerializer serializer]];
        [_httpSession setResponseSerializer:[AFJSONResponseSerializer serializer]];
        [_httpSession.requestSerializer willChangeValueForKey:@"timeoutInterval"];
        _httpSession.requestSerializer.timeoutInterval = 5.0;
        [_httpSession.requestSerializer didChangeValueForKey:@"timeoutInterval"];
        _httpSession.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/xml", @"text/plain", nil];
        
        _queue = dispatch_queue_create("RTCRoomQueue", DISPATCH_QUEUE_SERIAL);
        
        _background = NO;
        _mutePusher = NO;
        
        _roomStatisticInfo = [[RoomStatisticInfo alloc] init];
        _roomStatisticInfo.delegate = self;
    }
    return self;
}

- (void)initLivePusher {
    if (_livePusher == nil) {
        TXLivePushConfig *config = [[TXLivePushConfig alloc] init];
        config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
        config.pauseFps = 15;
        config.pauseTime = 300;
        
        _livePusher = [[TXLivePush alloc] initWithConfig:config];
        [_livePusher setVideoQuality:VIDEO_QUALITY_REALTIME_VIDEOCHAT adjustBitrate:YES adjustResolution:YES];
        config.videoResolution = VIDEO_RESOLUTION_TYPE_480_640;
        [_livePusher setConfig:config];
        _livePusher.delegate = self;
    }
}

- (void)dealloc
{
    [_httpSession invalidateSessionCancelingTasks:YES];
}

- (void)releaseLivePusher {
    if (_livePusher) {
        _livePusher.delegate = nil;
        _livePusher = nil;
    }
}

typedef void (^block)();
- (void)asyncRun:(block)block {
    dispatch_async(_queue, ^{
        block();
    });
}

- (NSString *)getApiAddr:(NSString *)api userID:(NSString*)userID token:(NSString*)token {
    return [NSString stringWithFormat:@"%@/%@?userID=%@&token=%@", _serverDomain, api, userID, token];
}

// 保存所有server API
- (void)initApiAddr:(NSString*)userID token:(NSString*)token {
    _apiAddr = [[NSMutableDictionary alloc] init];
    _apiAddr[kHttpServerAddr_GetRoomList] = [self getApiAddr:kHttpServerAddr_GetRoomList userID:userID token:token];
    _apiAddr[kHttpServerAddr_GetPushUrl] = [self getApiAddr:kHttpServerAddr_GetPushUrl userID:userID token:token];
    _apiAddr[kHttpServerAddr_GetPushers] = [self getApiAddr:kHttpServerAddr_GetPushers userID:userID token:token];
    _apiAddr[kHttpServerAddr_CreateRoom] = [self getApiAddr:kHttpServerAddr_CreateRoom userID:userID token:token];
    _apiAddr[kHttpServerAddr_AddPusher] = [self getApiAddr:kHttpServerAddr_AddPusher userID:userID token:token];
    _apiAddr[kHttpServerAddr_DeletePusher] = [self getApiAddr:kHttpServerAddr_DeletePusher userID:userID token:token];
    _apiAddr[kHttpServerAddr_PusherHeartBeat] = [self getApiAddr:kHttpServerAddr_PusherHeartBeat userID:userID token:token];
    _apiAddr[kHttpServerAddr_GetIMLoginInfo] = [self getApiAddr:kHttpServerAddr_GetIMLoginInfo userID:userID token:token];
    _apiAddr[kHttpServerAddr_Logout] = [self getApiAddr:kHttpServerAddr_Logout userID:userID token:token];
    _apiAddr[kHttpServerAddr_Report] = [NSString stringWithFormat:@"%@/%@?userID=%@&token=%@", @"https://roomtest.qcloud.com/weapp/utils", kHttpServerAddr_Report, userID, token];
}

/**
   1. Room登录
   2. IM初始化及登录
 */
- (void)login:(NSString*)serverDomain loginInfo:(LoginInfo *)loginInfo withCompletion:(ILoginCompletionHandler)completion {
    [self asyncRun:^{
        // 保存到本地
        _serverDomain = serverDomain;
        
        _roomStatisticInfo.str_appid = [NSString stringWithFormat:@"%d", loginInfo.sdkAppID];
        _roomStatisticInfo.str_userid = loginInfo.userID;
        
        [self login:loginInfo.sdkAppID accountType:loginInfo.accType userID:loginInfo.userID userSig:loginInfo.userSig completion:^(int errCode, NSString *errMsg, NSString *userID, NSString *token) {
            if (errCode == ROOM_SUCCESS) {
                
                [self initApiAddr: loginInfo.userID token:token];
                
                // 初始化userInfo
                _userInfo = [SelfAccountInfo new];
                _userInfo.userID    = loginInfo.userID;
                _userInfo.userName  = loginInfo.userName;
                _userInfo.userAvatar = loginInfo.userAvatar;
                _userInfo.sdkAppID = loginInfo.sdkAppID;
                _userInfo.accType = loginInfo.accType;
                _userInfo.userSig = loginInfo.userSig;
                
        // 初始化 RoomMsgMgr 并登录
        RoomMsgMgrConfig *config = [[RoomMsgMgrConfig alloc] init];
                config.userID = loginInfo.userID;
                config.appID = loginInfo.sdkAppID;
                config.accType = loginInfo.accType;
                config.userSig = loginInfo.userSig;
                config.userName = loginInfo.userName;
                config.userAvatar = loginInfo.userAvatar;
        
        _msgMgr = [[RoomMsgMgr alloc] initWithConfig:config];
        [_msgMgr setDelegate:self];
        
        [self sendDebugMsg:[NSString stringWithFormat:@"初始化IMSDK: appID[%d] userID[%@]", config.appID, config.userID]];
        
        __weak __typeof(self) weakSelf = self;
        [_msgMgr login:^(int errCode, NSString *errMsg) {
            [weakSelf asyncRun:^{
                [self sendDebugMsg:[NSString stringWithFormat:@"IM登录返回: errCode[%d] errMsg[%@]", errCode, errMsg]];
                if (errCode == 0 && completion) {
                    completion(0, @"登录成功");
                } else if (errCode != 0 && completion) {
                    completion(ROOM_ERR_IM_LOGIN, @"登录失败");
                }
            }];
        }];
            }
            else {
                [self sendDebugMsg:[NSString stringWithFormat:@"初始化RTCRoom失败: errorCode[%d] errorMsg[%@]", errCode, errMsg]];
            }
        }];
    }];
}

/**
 Room退出
 */
-(void)logout:(ILogoutCompletionHandler)completion {
    if (_apiAddr == nil) {
        return;
    }
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        // Room退出
        [_httpSession POST:_apiAddr[kHttpServerAddr_Logout] parameters:@{} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];

                if (completion) {
                    completion(errCode == 0 ? ROOM_SUCCESS : ROOM_ERR_REQUEST_TIMEOUT, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                }
            }];

        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"RTCRoom logout failed: error[%@]", [error description]]];
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
                }
            }];
        }];
    }];
}

/**
   会议创建者
   1. 在应用层调用startLocalPreview
   2. 请求kHttpServerAddr_GetPushUrl,获取推流地址
   3. 开始推流
   4. 在收到推流成功的事件后请求kHttpServerAddr_CreateRoom，获取roomID
   5. 加入IM Group (groupID就是第4步请求到的roomID)
 */
- (void)createRoom:(NSString *)roomID roomInfo:(NSString *)roomInfo withCompletion:(ICreateRoomCompletionHandler)completion {
    [self asyncRun:^{
        _roomRole = 1;  // 房间角色为创建者
        _roomID = roomID;
        _roomInfo.roomInfo = roomInfo;
        _createRoomCompletion = completion;
        
        __weak __typeof(self) weakSelf = self;
        //调用CGI：create_room，返回roomID, roomSig
        [self doCreateRoom:^(int errCode, NSString *errMsg, NSString *roomID) {
            if (errCode == 0) {
                _roomID = roomID;
                [weakSelf getUrlAndPushing:completion];
            }
            else {
                if (weakSelf.createRoomCompletion) {
                    weakSelf.createRoomCompletion(ROOM_ERR_CREATE_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                    weakSelf.createRoomCompletion = nil;
                }
            }
            
        }];
    }];
}

/**
   会议场景普通成员
   1. 在应用层调用startLocalPreview
   2. 加入IM Group
   3. 请求kHttpServerAddr_GetPushers，获取房间里所有pusher的信息
   4. 通过onGetPusherList将房间里所有pusher信息回调给上层播放
   5. 请求kHttpServerAddr_GetPushUrl,获取推流地址
   6. 开始推流
   7. 在收到推流成功的事件后请求kHttpServerAddr_AddPusher，把自己加入房间成员列表
 */
- (void)enterRoom:(NSString *)roomID withCompletion:(IEnterRoomCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        _roomRole = 2; // 房间角色为普通成员
        _enterRoomCompletion = completion;
        _roomID = roomID;
        
        [_roomStatisticInfo clean];
        _roomStatisticInfo.str_roomid = roomID;
        _roomStatisticInfo.str_username = _userInfo.userName;
        _roomStatisticInfo.int64_ts_enter_room = [[NSDate date] timeIntervalSince1970] * 1000;
        if (_roomInfos != nil && [_roomInfos count] > 0) {
            for (RoomInfo * item in _roomInfos) {
                if (roomID != nil && [roomID isEqualToString:item.roomID]) {
                    _roomStatisticInfo.str_room_creator = item.roomCreator;
                    break;
                }
            }
        }
        
        SInt64 joinGroupTSBeg = [[NSDate date] timeIntervalSince1970] * 1000;
        [_msgMgr enterRoom:roomID completion:^(int errCode, NSString *errMsg) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"加入IMGroup完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
                if (errCode == 0) {
                    _roomStatisticInfo.int64_tc_join_group = [[NSDate date] timeIntervalSince1970] * 1000 - joinGroupTSBeg;
                    
                    // 获取房间所有pusher信息
                    SInt64 getPusherTSBeg = [[NSDate date] timeIntervalSince1970] * 1000;
                    [weakSelf getPusherList:^(int errCode, NSString *errMsg, RoomInfo *roomInfo) {
                        if (errCode != 0) {
                            _roomStatisticInfo.int64_tc_get_pushers = errCode < 0 ? errCode : 0 - errCode;
                            [_roomStatisticInfo reportStatisticInfo];
 
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (_delegate) {
                                    [_delegate onError:errCode errMsg:errMsg];
                                }
                            });
                            return;
                        }
                        
                        [weakSelf asyncRun:^{
                            _roomInfo = roomInfo;
                        }];
                        
                        _roomStatisticInfo.int64_tc_get_pushers = [[NSDate date] timeIntervalSince1970] * 1000 - getPusherTSBeg;
                        [_roomStatisticInfo setPlayStreamBeginTS:[[NSDate date] timeIntervalSince1970] * 1000];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (_delegate) {
                                [_delegate onGetPusherList:roomInfo.pusherInfoArray];
                            }
                        });
                    }];
                    
                    // 获取推流地址并推流
                    [weakSelf getUrlAndPushing:completion];
                }
                else {
                    _roomStatisticInfo.int64_tc_join_group = errCode < 0 ? errCode : 0 - errCode;
                    [_roomStatisticInfo reportStatisticInfo];
                    
                    if (_enterRoomCompletion) {
                        _enterRoomCompletion(ROOM_ERR_ENTER_ROOM, @"进房失败");
                        _enterRoomCompletion = nil;
                    }
                }

            }];
        }];
    }];
}

/**
   1. stopLocalPreview
   2. 调用stopPush
   3. 退出IM房间
   4. 结束播放所有的流
   5. 请求 kHttpServerAddr_DeletePusher
 */
- (void)exitRoom:(IExitRoomCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        // 上层存在没有获取到roomID也调用exitRoom的情况
        if (!_roomID) {
            return;
        }
        
        if (_msgMgr) {
            [_msgMgr leaveRoom:_roomID completion:^(int errCode, NSString *errMsg) {
                NSLog(@"_msgMgr leaveRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"离开IM Group完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
            }];
        }
        
        NSDictionary *param = @{@"roomID": _roomID, @"userID": _userInfo.userID};
        NSString *reqUrl = _apiAddr[kHttpServerAddr_DeletePusher];
        
        [_httpSession POST:reqUrl parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复delete_pusher请求: errCode[%d] errMsg[%@]", errCode, errMsg]];
                
                if (completion) {
                    completion(errCode, errMsg);
                }
            }];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"delete_pusher请求失败: error[%@]", [error description]]];
            
                if (completion) {
                    completion(-1, [error description]);
                }
            }];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 关闭本地采集和预览
            [self stopLocalPreview];
            
            // 关闭所有播放器
            for (id userID in _livePlayerDic) {
                TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
                [player stopPlay];
                
                RoomLivePlayListenerWrapper *playerEventWrapper = [_playerEventDic objectForKey:userID];
                [playerEventWrapper clear];
            }
            [_livePlayerDic removeAllObjects];
            [_playerEventDic removeAllObjects];
        });

        // 停止心跳
        [self stopHeartBeat];
        
        // 清掉房间信息
        [_roomInfo.pusherInfoArray removeAllObjects];
        
        // 清除标记
        _mutePusher = NO;
        _background = NO;
    }];
}

typedef void (^ILoginCompletionCallback)(int errCode, NSString *errMsg, NSString *userID, NSString *token);
    
/**
   Room登录
*/
-(void)login:(int)sdkAppID accountType:(NSString*)accType userID:(NSString*)userID userSig:(NSString*)userSig completion:(ILoginCompletionCallback)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        // Room登录
        NSString * cgiUrl = [NSString stringWithFormat:@"%@/login?sdkAppID=%d&accountType=%@&userID=%@&userSig=%@", _serverDomain, sdkAppID, accType, userID, userSig];
        
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"RTCRoom登录, userID[%@]", userID]];
        
        [_httpSession POST:cgiUrl parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                NSString *userID = responseObject[@"userID"];
                NSString *token  = responseObject[@"token"];
                
                if (completion) {
                    completion(errCode == 0 ? ROOM_SUCCESS : ROOM_ERR_REQUEST_TIMEOUT, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode], userID, token);
                }
            }];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"RTCRoom登录失败: error[%@]", [error description]]];
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置", nil, nil);
                }
            }];
        }];
    }];
}

/**
   获取推流地址，并推流
 */
typedef void (^IGetUrlAndPushingCompletionHandler)(int errCode, NSString *errMsg);

- (void)getUrlAndPushing:(IGetUrlAndPushingCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        // 获取推流地址
        NSDictionary *params = @{@"userID": _userInfo.userID, @"roomID": _roomID};
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求推流地址, userID[%@] roomID[%@]", _userInfo.userID, _roomID]];
        
        SInt64 getPushUrlTSBeg = [[NSDate date] timeIntervalSince1970] * 1000;
        [_httpSession POST:_apiAddr[kHttpServerAddr_GetPushUrl] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                NSString *pushUrl = responseObject[@"pushURL"];
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr返回推流地址: errCode[%d] errMsg[%@] pushUrl[%@]", errCode, errMsg, pushUrl]];
                
                if (_roomRole == 2) {
                if (errCode == 0) {
                        _roomStatisticInfo.int64_tc_get_pushurl = [[NSDate date] timeIntervalSince1970] * 1000 - getPushUrlTSBeg;
                    }
                    else {
                        _roomStatisticInfo.int64_tc_get_pushurl = errCode < 0 ? errCode : 0 - errCode;
                        [_roomStatisticInfo reportStatisticInfo];
                    }
                }
                
                if (errCode == 0) {
                    if (_roomRole == 2) {
                        [_roomStatisticInfo setStreamPushUrl:pushUrl];
                        _roomStatisticInfo.int64_ts_push_stream = [[NSDate date] timeIntervalSince1970] * 1000;
                    }
                    // 启动推流
                    _pushUrl = pushUrl;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_livePusher startPush:_pushUrl];
                    });
                    
                } else {
                    if (completion) {
                        completion(ROOM_ERR_REQUEST_TIMEOUT, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                    }
                }
            }];
           
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求推流地址失败: error[%@]", [error description]]];
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
                }
            }];
        }];
    }];
}


/**
 * 获取房间内所有pusher的信息
 */
typedef void (^IGetPusherListCompletionHandler)(int errCode, NSString *errMsg, RoomInfo *roomInfo);

- (void)getPusherList:(IGetPusherListCompletionHandler)completion {
    [self asyncRun:^{
        if (_roomID == nil) {
            return;
        }
        
        __weak __typeof(self) weakSelf = self;
        NSDictionary *param = @{@"roomID": _roomID};
        
        [_httpSession POST:_apiAddr[kHttpServerAddr_GetPushers] parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                
                if (errCode != 0) {
                    if (completion) {
                        completion(ROOM_ERR_REQUEST_TIMEOUT, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode], nil);
                    }
                    return;
                }
            
                RoomInfo *roomInfo = [[RoomInfo alloc] init];
                roomInfo.roomID = _roomID;
                roomInfo.roomInfo = responseObject[@"roomInfo"];
                roomInfo.pusherInfoArray = [self parsePushersFromJsonArray:responseObject[@"pushers"]];
                
                if (completion) {
                    completion(errCode, errMsg, roomInfo);
                }
            }];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置", nil);
                }
            }];
        }];

    }];
}

- (void)getRoomList:(int)index cnt:(int)cnt withCompletion:(IGetRoomListCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        NSDictionary *param = @{@"cnt": @(cnt), @"index": @(index)};
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"发起获取房间列表请求: index[%d] cnt[%d]", index, cnt]];
        
        [_httpSession POST:_apiAddr[kHttpServerAddr_GetRoomList] parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复获取房间请求: errCode[%d] errMsg[%@]", errCode, errMsg]];
                
                if (errCode != 0) {
                    if (completion) {
                        completion(ROOM_ERR_REQUEST_TIMEOUT, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode], nil);
                    }
                    return;
                }
                
                NSArray *rooms = responseObject[@"rooms"];
                NSMutableArray *roomInfos = [[NSMutableArray alloc] init];
                
                for (id room in rooms) {
                    RoomInfo *roomInfo = [[RoomInfo alloc] init];
                    roomInfo.roomID = room[@"roomID"];
                    roomInfo.roomInfo = room[@"roomInfo"];
                    roomInfo.roomCreator = room[@"roomCreator"];
                    roomInfo.mixedPlayURL = room[@"mixedPlayURL"];
                    roomInfo.pusherInfoArray = [self parsePushersFromJsonArray:room[@"pushers"]];
                    
                    [roomInfos addObject:roomInfo];
                }
                
                _roomInfos = roomInfos;
                
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr返回房间列表: roomInfos[%@]", roomInfos]];
                
                if (completion) {
                    completion(errCode, errMsg, roomInfos);
                }
            }];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"房间列表请求失败: error[%@]", [error description]]];
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置", nil);
                }
            }];
        }];

    }];
}

- (void)sendRoomTextMsg:(NSString *)textMsg {
    [self asyncRun:^{
        [_msgMgr sendRoomTextMsg:textMsg];
    }];
}

- (NSMutableArray<PusherInfo *> *)  parsePushersFromJsonArray:(NSArray *)pushers {
    if (pushers == nil) {
        return nil;
    }
    
    NSMutableArray *pusherInfoArray = [[NSMutableArray alloc] init];
    for (id pusher in pushers) {
        PusherInfo *pusherInfo = [[PusherInfo alloc] init];
        pusherInfo.playUrl = pusher[@"accelerateURL"];
        pusherInfo.userID = pusher[@"userID"];
        pusherInfo.userName = pusher[@"userName"];
        pusherInfo.userAvatar = pusher[@"userAvatar"];
        
        // 注意：这里将自己过滤掉 (为了上层使用方便)
        if ([pusherInfo.userID isEqualToString:_userInfo.userID]) {
            continue;
        }
        
        [pusherInfoArray addObject:pusherInfo];
    }
    
    return pusherInfoArray;
}

- (void)startHeartBeat {
    // 启动心跳，向业务服务器发送心跳请求
    __weak __typeof(self) weakSelf = self;
    _heartBeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_event_handler(_heartBeatTimer, ^{
        __strong __typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf sendHeartBeat];
        }
    });
    dispatch_source_set_timer(_heartBeatTimer, dispatch_walltime(NULL, 0), 7 * NSEC_PER_SEC, 0);
    dispatch_resume(_heartBeatTimer);
}

- (void)stopHeartBeat {
    if (_heartBeatTimer) {
        dispatch_cancel(_heartBeatTimer);
        _heartBeatTimer = nil;
    }
}

- (void)sendHeartBeat {
    [self asyncRun:^{
        if (_userInfo == nil || _roomID == nil) {
            return;
        }
        
        NSDictionary *param = @{@"roomID": _roomID, @"userID": _userInfo.userID};
        
        __weak __typeof(self) weakSelf = self;
        [_httpSession POST:_apiAddr[kHttpServerAddr_PusherHeartBeat] parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            NSLog(@"sendHeartBeat errCode[%d] errMsg[%@]", errCode, errMsg);
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"sendHeartBeat failed error[%@]", error);
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"发起心跳失败: error[%@]", [error description]]];
        }];
    }];
}

- (void)startLocalPreview:(UIView *)view {
    [self initLivePusher];
    [_livePusher startPreview:view];
}

- (void)stopLocalPreview {
    [_livePusher stopPreview];
    [_livePusher stopPush];
    [self releaseLivePusher];
}

- (void)addRemoteView:(UIView *)view withUserID:(NSString *)userID playBegin:(IPlayBegin)playBegin playError:(IPlayError)playError {
    [self asyncRun:^{
        // 先检查房间是否存在userID
        NSString *playUrl = nil;
        for (PusherInfo *pushInfo in _roomInfo.pusherInfoArray) {
            if ([pushInfo.userID isEqualToString:userID]) {
                playUrl = pushInfo.playUrl;
                break;
            }
        }
        
        // 如果userID不存在,就通知上层该userID已经离开房间及销毁view
        if (playUrl == nil) {
            NSLog(@"startRemoteView: userID[%@] not exist!!!", userID);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_delegate) {
                    PusherInfo *pushInfo = [[PusherInfo alloc] init];
                    pushInfo.userID = userID;
                    [_delegate onPusherQuit:pushInfo];
                }
            });
            return;
        }
        
        TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
        if (!player) {
            RoomLivePlayListenerWrapper * listenerWrapper = [RoomLivePlayListenerWrapper new];
            listenerWrapper.userID = userID;
            listenerWrapper.delegate = self;
            listenerWrapper.playBeginBlock = playBegin;
            listenerWrapper.playErrorBlock = playError;
            
            player = [[TXLivePlayer alloc] init];
            player.delegate = listenerWrapper;
            
            TXLivePlayConfig *config = [[TXLivePlayConfig alloc] init];
            config.bAutoAdjustCacheTime = YES;
            config.cacheTime = 0.2;
            config.maxAutoAdjustCacheTime = 1.2;
            config.minAutoAdjustCacheTime = 0.2;
            config.connectRetryCount = 3;
            config.connectRetryInterval = 3;
            config.enableAEC = YES;
            
            [player setConfig:config];
            [_livePlayerDic setObject:player forKey:userID];
            [_playerEventDic setObject:listenerWrapper forKey:userID];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [player setupVideoWidget:CGRectZero containView:view insertIndex:0];
            [player startPlay:playUrl type:PLAY_TYPE_LIVE_RTMP_ACC];
        });
    }];
}

- (void)deleteRemoteView:(NSString *)userID {
    [self asyncRun:^{
        TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
        if (player) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [player stopPlay];
                [player removeVideoWidget];
                player.delegate = nil;
            });
        }
        
        RoomLivePlayListenerWrapper *playerEventWrapper = [_playerEventDic objectForKey:userID];
        [playerEventWrapper clear];
        
        [_livePlayerDic removeObjectForKey:userID];
        [_playerEventDic removeObjectForKey:userID];
    }];
}

- (void)switchCamera {
    [_livePusher switchCamera];
}

- (void)setMute:(BOOL)isMute {
    _mutePusher = isMute;
    [_livePusher setMute:isMute];
}

- (void)setHDAudio:(BOOL)isHD {
    TXLivePushConfig *config = _livePusher.config;
    if (isHD && config.audioSampleRate != AUDIO_SAMPLE_RATE_48000) {
        config.audioSampleRate = AUDIO_SAMPLE_RATE_48000;
        [_livePusher setConfig:config];
    }
    if (!isHD && config.audioSampleRate != AUDIO_SAMPLE_RATE_16000) {
        config.audioSampleRate = AUDIO_SAMPLE_RATE_16000;
        [_livePusher setConfig:config];
    }
}

- (void)setBitrateRange:(int)minBitrate max:(int)maxBitrate {
    TXLivePushConfig *config = _livePusher.config;
    if (config.videoBitrateMin != minBitrate || config.videoBitrateMax != maxBitrate) {
        config.videoBitrateMin = minBitrate;
        config.videoBitrateMax = maxBitrate;
        [_livePusher setConfig:config];
    }
}

- (void)switchToBackground:(UIImage *)pauseImage {
    TXLivePushConfig *config = _livePusher.config;
    if (!config.pauseImg || ![config.pauseImg isEqual:pauseImage]) {
        config.pauseImg = pauseImage;
        [_livePusher setConfig:config];
    }
    //[_livePusher setMute:YES];
    [_livePusher pausePush];
    
    [self asyncRun:^{
        for (id userID in _livePlayerDic) {
            TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (player) {
                    [player pause];
                }
            });
        }
    }];

    _background = YES;
}

- (void)switchToForeground {
    //[_livePusher setMute:_mutePusher];
    [_livePusher resumePush];
    
    [self asyncRun:^{
        for (id userID in _livePlayerDic) {
            TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (player) {
                    [player resume];
                }
            });
        }
    }];

    _background = NO;
    
    if (_livePusher && [_livePusher isPublishing]) {
        [self onPusherChanged];
    }
}

- (void)showVideoDebugLog:(BOOL)isShow {
    [_livePusher showVideoDebugLog:isShow];
    
    [self asyncRun:^{
        for (id userID in _livePlayerDic) {
            TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (player) {
                    [player showVideoDebugLog:isShow];
                }
            });
        }
    }];
}

- (void)setBeautyStyle:(int)beautyStyle beautyLevel:(float)beautyLevel whitenessLevel:(float)whitenessLevel ruddinessLevel:(float)ruddinessLevel {
    [_livePusher setBeautyStyle:beautyStyle beautyLevel:beautyLevel whitenessLevel:whitenessLevel ruddinessLevel:ruddinessLevel];
}


#pragma mark - TXLivePushListener

-(void) onPushEvent:(int)EvtID withParam:(NSDictionary*)param {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        if (_roomRole == 2) {
        if (EvtID == PUSH_EVT_PUSH_BEGIN) {
                _roomStatisticInfo.int64_tc_push_stream = [[NSDate date] timeIntervalSince1970] * 1000 - _roomStatisticInfo.int64_ts_push_stream;
            }
            else if (EvtID == PUSH_ERR_OPEN_CAMERA_FAIL || EvtID == PUSH_ERR_OPEN_MIC_FAIL || EvtID == PUSH_ERR_NET_DISCONNECT) {
                [_roomStatisticInfo reportStatisticInfo];
            }
        }
        
        if (EvtID == PUSH_EVT_PUSH_BEGIN) {
            if (_roomRole == 1) {  // 创建者
                //请求CGI：add_pusher，加入房间
                [self doAddPusher:_roomID completion:^(int errCode, NSString *errMsg) {
                    if (errCode == 0) {
                        //调用IM的joinGroup，加入群组
                        [weakSelf.msgMgr enterRoom:_roomID completion:^(int errCode, NSString *errMsg) {
                            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"加入IMGroup完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
                            if (weakSelf.createRoomCompletion) {
                                weakSelf.createRoomCompletion(errCode, errMsg);
                                weakSelf.createRoomCompletion = nil;
                            }
                        }];
                        [weakSelf startHeartBeat]; // 启动心跳
                        
                    } else {
                        if (weakSelf.createRoomCompletion) {
                            weakSelf.createRoomCompletion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                            weakSelf.createRoomCompletion = nil;
                        }
                    }
                }];
            }
            else if (_roomRole == 2) {  // 普通成员
                //请求CGI：add_pusher，加入房间
                [self doAddPusher:_roomID completion:^(int errCode, NSString *errMsg) {
                    if (errCode == 0) {
                        if (weakSelf.enterRoomCompletion) {
                            weakSelf.enterRoomCompletion(errCode, errMsg);
                            weakSelf.enterRoomCompletion = nil;
                        }
                        
                    } else {
                        if (weakSelf.enterRoomCompletion) {
                            weakSelf.enterRoomCompletion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                            weakSelf.enterRoomCompletion = nil;
                        }
                    }

                    // 启动心跳
                    [weakSelf startHeartBeat];
                }];
            }
                    
        } else if (EvtID == PUSH_ERR_NET_DISCONNECT || EvtID == PUSH_ERR_INVALID_ADDRESS) {
            NSString *errMsg = @"推流断开，请检查网络设置";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;

            } else if (_enterRoomCompletion) {
                _enterRoomCompletion(ROOM_ERR_ENTER_ROOM, errMsg);
                _enterRoomCompletion = nil;
                
            } else {
                if (_delegate) {
                    [_delegate onError:ROOM_ERR_PUSH_DISCONNECT errMsg:errMsg];
                }
            }
            
        } else if (EvtID == PUSH_ERR_OPEN_CAMERA_FAIL) {
            NSString *errMsg = @"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;
                
            } else if (_enterRoomCompletion) {
                _enterRoomCompletion(ROOM_ERR_ENTER_ROOM, errMsg);
                _enterRoomCompletion = nil;
                
            }
            
        } else if (EvtID == PUSH_ERR_OPEN_MIC_FAIL) {
            NSString *errMsg = @"获取麦克风权限失败，请前往隐私-麦克风设置里面打开应用权限";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;
                
            } else if (_enterRoomCompletion) {
                _enterRoomCompletion(ROOM_ERR_ENTER_ROOM, errMsg);
                _enterRoomCompletion = nil;
            }
        }
    }];
}

-(void) onNetStatus:(NSDictionary*)param {
    
}

#pragma mark - IRoomLivePlayListener

-(void)onLivePlayEvent:(NSString*) userID withEvtID:(int)EvtID andParam:(NSDictionary*)param {
    if (_roomRole == 2) {
        if (EvtID == PLAY_EVT_PLAY_BEGIN) {
            [_roomStatisticInfo updatePlayStreamSuccessTS:[[NSDate date] timeIntervalSince1970] * 1000];
        }
        else if (EvtID == PLAY_ERR_NET_DISCONNECT){
            [_roomStatisticInfo reportStatisticInfo];
        }
    }
    
    if (EvtID == PLAY_ERR_NET_DISCONNECT){
        [self deleteRemoteView:userID];
    }
}

typedef void (^ICreateRoomCompletionSink)(int errCode, NSString *errMsg, NSString * roomID);

- (void)doCreateRoom:(ICreateRoomCompletionSink)completion {
    __weak __typeof(self) weakSelf = self;
    
    [weakSelf sendDebugMsg:[NSString stringWithFormat:@"开始请求create_room"]];
    
    if (_roomID == nil) {
        _roomID = @"";
    }
    
    [_httpSession POST:_apiAddr[kHttpServerAddr_CreateRoom] parameters:@{@"userID": _userInfo.userID, @"roomID":_roomID, @"roomInfo":_roomInfo.roomInfo} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [weakSelf asyncRun:^{
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复create_room: errCode[%d] errMsg[%@]", errCode, errMsg]];
            
            if (errCode == 0) {
                NSString *roomID = responseObject[@"roomID"];
                if (completion) {
                    completion(errCode, errMsg, roomID);
                }
            }
            else {
                if (completion) {
                    completion(ROOM_ERR_CREATE_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode], nil);
                }
            }
        }];
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求create_room失败: error[%@]", [error description]]];
        [weakSelf asyncRun:^{
            if (completion) {
                completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置", nil);
            }
        }];
        
    }];
}

typedef void (^IAddPusherCompletionSink)(int errCode, NSString *errMsg);

- (void)doAddPusher:(NSString*)roomID completion:(IAddPusherCompletionSink)completion {
    __weak __typeof(self) weakSelf = self;

    [weakSelf sendDebugMsg:[NSString stringWithFormat:@"开始请求add_pusher"]];
    
    NSDictionary *params = @{@"roomID": roomID, @"userID": _userInfo.userID, @"userName": _userInfo.userName, @"userAvatar": _userInfo.userAvatar, @"pushURL": _pushUrl};
    
    SInt64 addPusherTSBeg = [[NSDate date] timeIntervalSince1970] * 1000;
    [_httpSession POST:_apiAddr[kHttpServerAddr_AddPusher] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [weakSelf asyncRun:^{
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复add_pusher: errCode[%d] errMsg[%@]", errCode, errMsg]];
            
            if (errCode == 0) {
                _roomStatisticInfo.int64_tc_add_pusher = [[NSDate date] timeIntervalSince1970] * 1000 - addPusherTSBeg;
                [_roomStatisticInfo updateAddPusherSuccessTS:[[NSDate date] timeIntervalSince1970] * 1000];
                
                if (completion) {
                    completion(errCode, errMsg);
                }
                
            } else {
                _roomStatisticInfo.int64_tc_add_pusher = errCode < 0 ? errCode : 0 - errCode;
                [_roomStatisticInfo reportStatisticInfo];
                
                if (completion) {
                    completion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                }
            }
        }];
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求add_pusher失败: error[%@]", [error description]]];
        [weakSelf asyncRun:^{
            if (completion) {
                completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
            }
        }];
    }];
}

#pragma mark - RoomMsgListener

- (void)onRecvGroupTextMsg:(NSString *)groupID userID:(NSString *)userID textMsg:(NSString *)textMsg userName:(NSString *)userName userAvatar:(NSString *)userAvatar {
    if (![groupID isEqualToString:_roomID]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onRecvRoomTextMsg:userID:userName:userAvatar:textMsg:)]) {
            [_delegate onRecvRoomTextMsg:groupID userID:userID userName:userName userAvatar:userAvatar textMsg:textMsg];
        }
    });
}

- (void)onMemberChange:(NSString *)groupID {
    if (![groupID isEqualToString:_roomID]) {
        return;
    }
    
    if (_background == NO) {
        [self onPusherChanged];
    }
}


- (void)onGroupDelete:(NSString *)groupID {
    [self sendDebugMsg:[NSString stringWithFormat:@"房间[%@]被解散", groupID]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate) {
            [_delegate onRoomClose:groupID];
        }
    });
}

- (void)onPusherChanged {
    [self getPusherList:^(int errCode, NSString *errMsg, RoomInfo *roomInfo) {
        NSLog(@"onMemberChanged getMemberList errCode[%d] errMsg[%@]", errCode, errMsg);
        if (errCode != 0) {
            return;
        }
        
        RoomInfo *newRoomInfo = roomInfo;
        RoomInfo *oldRoomInfo = _roomInfo;
        
        
        NSMutableSet *leaveSet = [[NSMutableSet alloc] init];
        for (PusherInfo *pusherInfo in oldRoomInfo.pusherInfoArray) {
            [leaveSet addObject:pusherInfo];
        }
        
        for (PusherInfo *pusherInfo in newRoomInfo.pusherInfoArray) {
            // 过滤自己
            if ([pusherInfo.userID isEqualToString:_userInfo.userID]) {
                continue;
            }
            
            
            BOOL isNewMember = YES;
            PusherInfo *tmpPusherInfo = nil;
            for (PusherInfo *info in oldRoomInfo.pusherInfoArray) {
                if ([info.userID isEqualToString:pusherInfo.userID]) {
                    isNewMember = NO;
                    tmpPusherInfo = info;
                    break;
                }
            }
            
            if (isNewMember) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (_delegate) {
                        [_delegate onPusherJoin:pusherInfo];
                    }
                    [self sendDebugMsg:[NSString stringWithFormat:@"加入房间: userID[%@] userName[%@] playUrl[%@]", pusherInfo.userID, pusherInfo.userName, pusherInfo.playUrl]];
                });
            } else {
                [leaveSet removeObject:tmpPusherInfo];
            }
        }
        
        for (PusherInfo *pusherInfo in leaveSet) {
            // 关闭播放器
            [self deleteRemoteView:pusherInfo.userID];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_delegate) {
                    [_delegate onPusherQuit:pusherInfo];
                }
                [self sendDebugMsg:[NSString stringWithFormat:@"离开房间: userID[%@] userName[%@]", pusherInfo.userID, pusherInfo.userName]];
            });
        }
        
        // 更新
        _roomInfo = newRoomInfo;
        
    }];
}

- (void)sendDebugMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate) {
            [_delegate onDebugMsg:msg];
        }
    });
}

- (void)onReportStatisticInfo:(NSDictionary *)statisticInfo {
    [self asyncRun:^{
        NSDictionary *param = @{@"reportID": @(1), @"data": statisticInfo};
        
        for (NSString * key in statisticInfo.allKeys) {
            NSLog(@"roomStatisticInfo key = %@ val = %@\n", key, statisticInfo[key]);
        }
        
        [_httpSession POST:_apiAddr[kHttpServerAddr_Report] parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            NSLog(@"roomStatisticInfo report errCode[%d] errMsg[%@]", errCode, errMsg);
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"roomStatisticInfo report failed error[%@]", error);
        }];
    }];
}

@end
