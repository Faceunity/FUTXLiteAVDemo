//
//  LiveRoom.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "LiveRoom.h"
//#import "TXUGCRecord"
#import "TXLivePush.h"
#import "TXLivePlayer.h"
#import "AFNetworking.h"
#import "RoomMsgMgr.h"
#import "RoomUtil.h"


#import "FUManager.h"

// 业务服务器API
#define kHttpServerAddr_GetRoomList     @"get_room_list"
#define kHttpServerAddr_GetAudienceList @"get_audiences"
#define kHttpServerAddr_GetPushUrl      @"get_push_url"
#define kHttpServerAddr_GetPushers      @"get_pushers"
#define kHttpServerAddr_CreateRoom      @"create_room"
#define kHttpServerAddr_AddPusher       @"add_pusher"
#define kHttpServerAddr_DeletePusher    @"delete_pusher"
#define kHttpServerAddr_AddAudience     @"add_audience"
#define kHttpServerAddr_DeleteAudience  @"delete_audience"
#define kHttpServerAddr_PusherHeartBeat @"pusher_heartbeat"
#define kHttpServerAddr_GetIMLoginInfo  @"get_im_login_info"
#define kHttpServerAddr_Logout          @"logout"
#define kHttpServerAddr_MergeStream     @"merge_stream"


@interface LiveRoom() <TXLivePushListener, IRoomLivePlayListener, RoomMsgListener, TXVideoCustomProcessDelegate> {
    TXLivePush              *_livePusher;
    NSMutableDictionary     *_livePlayerDic;  // [userID, player]
    NSMutableDictionary     *_playerEventDic; // [userID, RoomLivePlayListenerWrapper]
    NSMutableArray          *_roomInfos;      // 保存最近一次拉回的房间列表，这里仅仅使用里面的房间混流地址和创建者信息
    RoomInfo                *_roomInfo;       // 注意这个RoomInfo里面的pusherInfoArray不包含自己
    NSMutableArray          *_audienceInfos;  // 保存最近一次拉回的房间观众列表
    AFHTTPSessionManager    *_httpSession;
    NSString                *_serverDomain;   // 保存业务服务器域名
    NSMutableDictionary     *_apiAddr;        // 保存业务服务器相关的rest api
    
    NSString                *_appID;
    SelfAccountInfo         *_userInfo;
    NSString                *_pushUrl;
    NSString                *_roomID;

    NSString                *_roomCreator;    // 房间创建者ID，也就是大主播
    NSString                *_roomCreatorUrl; // 大主播的直播流地址
    NSString                *_mixedPlayURL;   // 房间混流播放地址

    dispatch_source_t       _heartBeatTimer;
    dispatch_queue_t        _queue;
    
    int                     _roomRole;        // 房间角色，创建者(大主播):1  小主播:2  普通观众:3
    BOOL                    _created;         // 标记是否已经创建过房间
    int                     _videoQuality;    // 保存当前推流的视频质量
    int                     _renderMode;
    BOOL                    _background;
    BOOL                    _mutePusher;
    
    IRequestJoinPusherCompletionHandler _requestJoinPusherCompletion;
    IRequestPKCompletionHandler         _requestPKCompletion;
}

@property (atomic, strong) RoomMsgMgr *                  msgMgr;
@property (atomic, strong) ICreateRoomCompletionHandler  createRoomCompletion;
@property (atomic, strong) IJoinPusherCompletionHandler  joinPusherCompletion;

@end

@implementation LiveRoom

- (GLuint)onPreProcessTexture:(GLuint)texture width:(CGFloat)width height:(CGFloat)height {
    
    if ([FUManager shareManager].showFaceUnityEffect) {
        texture = [[FUManager shareManager] renderItemWithTexture:texture Width:width Height:height];
    }
    
    return texture ;
}


- (instancetype)init {
    if (self = [super init]) {
        [self initLivePusher];
        _livePlayerDic = [[NSMutableDictionary alloc] init];
        _playerEventDic = [[NSMutableDictionary alloc] init];
        _roomInfos = [[NSMutableArray alloc] init];
        _roomInfo = [[RoomInfo alloc] init];
        
        _httpSession = [AFHTTPSessionManager manager];
        [_httpSession setRequestSerializer:[AFJSONRequestSerializer serializer]];
        [_httpSession setResponseSerializer:[AFJSONResponseSerializer serializer]];
        [_httpSession.requestSerializer willChangeValueForKey:@"timeoutInterval"];
        _httpSession.requestSerializer.timeoutInterval = 5.0;
        [_httpSession.requestSerializer didChangeValueForKey:@"timeoutInterval"];
        _httpSession.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/xml", @"text/plain", nil];
        
        _queue = dispatch_queue_create("LiveRoomQueue", DISPATCH_QUEUE_SERIAL);
        
        _created = NO;
        _background = NO;
        _mutePusher = NO;
        _renderMode = -1;
    }
    return self;
}

- (void)initLivePusher {
    if (_livePusher == nil) {
        TXLivePushConfig *config = [[TXLivePushConfig alloc] init];
        config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
        config.pauseFps = 15;
        config.pauseTime = 300;
       
        _videoQuality = VIDEO_QUALITY_HIGH_DEFINITION;
        _livePusher = [[TXLivePush alloc] initWithConfig:config];
        _livePusher.delegate = self;
        
        // 增加此代理，拿到视频数据回调
        _livePusher.videoProcessDelegate = self ;
        
        [_livePusher setVideoQuality:_videoQuality adjustBitrate:NO adjustResolution:NO];
        [_livePusher setLogViewMargin:UIEdgeInsetsMake(120, 10, 60, 10)];
        config.videoEncodeGop = 5;
        [_livePusher setConfig:config];
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
    _apiAddr[kHttpServerAddr_GetAudienceList] = [self getApiAddr:kHttpServerAddr_GetAudienceList userID:userID token:token];
    _apiAddr[kHttpServerAddr_GetPushUrl] = [self getApiAddr:kHttpServerAddr_GetPushUrl userID:userID token:token];
    _apiAddr[kHttpServerAddr_GetPushers] = [self getApiAddr:kHttpServerAddr_GetPushers userID:userID token:token];
    _apiAddr[kHttpServerAddr_CreateRoom] = [self getApiAddr:kHttpServerAddr_CreateRoom userID:userID token:token];
    _apiAddr[kHttpServerAddr_AddPusher] = [self getApiAddr:kHttpServerAddr_AddPusher userID:userID token:token];
    _apiAddr[kHttpServerAddr_DeletePusher] = [self getApiAddr:kHttpServerAddr_DeletePusher userID:userID token:token];
    _apiAddr[kHttpServerAddr_AddAudience] = [self getApiAddr:kHttpServerAddr_AddAudience userID:userID token:token];
    _apiAddr[kHttpServerAddr_DeleteAudience] = [self getApiAddr:kHttpServerAddr_DeleteAudience userID:userID token:token];
    _apiAddr[kHttpServerAddr_PusherHeartBeat] = [self getApiAddr:kHttpServerAddr_PusherHeartBeat userID:userID token:token];
    _apiAddr[kHttpServerAddr_GetIMLoginInfo] = [self getApiAddr:kHttpServerAddr_GetIMLoginInfo userID:userID token:token];
    _apiAddr[kHttpServerAddr_MergeStream] = [self getApiAddr:kHttpServerAddr_MergeStream userID:userID token:token];
    _apiAddr[kHttpServerAddr_Logout] = [self getApiAddr:kHttpServerAddr_Logout userID:userID token:token];
}

/**
   1. Room登录
   2. IM初始化及登录
 */
- (void)login:(NSString*)serverDomain loginInfo:(LoginInfo *)loginInfo withCompletion:(ILoginCompletionHandler)completion {
    [self asyncRun:^{
        // 保存到本地
        _serverDomain = serverDomain;
        
        [self login:loginInfo.sdkAppID accType:loginInfo.accType userID:loginInfo.userID userSig:loginInfo.userSig completion:^(int errCode, NSString *errMsg, NSString *userID, NSString *token) {
            if (errCode == ROOM_SUCCESS) {
                
                [self initApiAddr: loginInfo.userID token:token];
                
                _appID = [NSString stringWithFormat:@"%d", loginInfo.sdkAppID];
                
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
                [self sendDebugMsg:[NSString stringWithFormat:@"初始化LiveRoom失败: errorCode[%d] errorMsg[%@]", errCode, errMsg]];
            }
        }];
    }];
}

/**
   大主播
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
        [self getUrlAndPushing:completion];
    }];
}

/**
   观众
   1. 加入IM Group
   2. 播放房间的混流播放地址
 */
- (void)enterRoom:(NSString *)roomID withView:(UIView *)view withCompletion:(IEnterRoomCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        _roomRole = 3;  // 房间角色为普通观众
        _roomID = roomID;
        
        [_msgMgr enterRoom:roomID completion:^(int errCode, NSString *errMsg) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"加入IMGroup完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
                if (errCode == 0) {
                    // 遍历房间列表，找到大主播的地址，开始播放
                    for (RoomInfo *roomInfo in _roomInfos) {
                        // 找到当前房间
                        if ([roomInfo.roomID isEqualToString:roomID]) {
                            // 保存大主播ID和房间混流地址
                            _roomCreator = roomInfo.roomCreator;
                            _mixedPlayURL = roomInfo.mixedPlayURL;
                            
                            // 找到大主播
                            for (PusherInfo *pusherInfo in roomInfo.pusherInfoArray) {
                                if ([pusherInfo.userID isEqualToString:_roomCreator]) {
                                    // 保存大主播的直播流地址
                                    _roomCreatorUrl = pusherInfo.playUrl;
                                    break;
                                }
                            }
                            
                            // 播放房间混流地址，注意这里是按直播模式播放
                            TXLivePlayer *player = [_livePlayerDic objectForKey:_roomCreator];
                            if (!player) {
                                RoomLivePlayListenerWrapper *playerEventWrapper = [[RoomLivePlayListenerWrapper alloc] init];
                                playerEventWrapper.userID = _roomCreator;
                                playerEventWrapper.delegate = self;
                                
                                player = [[TXLivePlayer alloc] init];
                                player.delegate = playerEventWrapper;
                                [player setRenderMode:RENDER_MODE_FILL_EDGE];

                                [_livePlayerDic setObject:player forKey:_roomCreator];
                                [_playerEventDic setObject:playerEventWrapper forKey:_roomCreator];
                            }
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                TXLivePlayConfig *playConfig = [[TXLivePlayConfig alloc] init];
                                playConfig.bAutoAdjustCacheTime = YES;
                                playConfig.minAutoAdjustCacheTime = 2.0f;
                                playConfig.maxAutoAdjustCacheTime = 2.0f;
                                [player setConfig:playConfig];
                                [player setupVideoWidget:CGRectZero containView:view insertIndex:0];
                                [player setLogViewMargin:UIEdgeInsetsMake(120, 10, 60, 10)];
                                [player startPlay:_mixedPlayURL type:[self getPlayType:_mixedPlayURL]];
                            });
                        
                            break;
                        }
                    }
                    
                    // 作为普通观众，调用CGI：add_audience
                    NSError *parseError = nil;
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"userName":_userInfo.userName, @"userAvatar":_userInfo.userAvatar} options:NSJSONWritingPrettyPrinted error:&parseError];
                    NSString *userInfo = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    [self doAddAudience:_roomID userID:_userInfo.userID userInfo:userInfo completion:^(int errCode, NSString *errMsg) {
                        
                    }];
                    
                    if (completion) {
                        completion(errCode, errMsg);
                    }
                }
                else {
                    if (completion) {
                        completion(ROOM_ERR_ENTER_ROOM, @"进房失败");
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
 
   如果是普通观众，则只需要调用第3、4步
 */
- (void)exitRoom:(IExitRoomCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        // 上层存在没有获取到roomID也调用exitRoom的情况
        if (!_roomID) {
            return;
        }
        
        // 退出IM群组
        if (_msgMgr) {
            [_msgMgr leaveRoom:_roomID completion:^(int errCode, NSString *errMsg) {
                NSLog(@"_msgMgr leaveRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"离开IM Group完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
            }];
        }
        
        // 作为连麦者退出房间（不区分大、小主播、普通观众）
        [_httpSession POST:_apiAddr[kHttpServerAddr_DeletePusher] parameters:@{@"roomID": _roomID, @"userID": _userInfo.userID} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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
        
        // 作为普通观众退出 (不区分大、小主播）
        [self doDeleteAudience:_roomID userID:_userInfo.userID completion:^(int errCode, NSString *errMsg) {
            
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
        _roomCreator = nil;
        _roomCreatorUrl = nil;
        _mixedPlayURL = nil;
        
        // 清除标记
        _created = NO;
        _mutePusher = NO;
        _renderMode = -1;
    }];
}

typedef void (^ILoginCompletionCallback)(int errCode, NSString *errMsg, NSString *userID, NSString *token);

/**
   Room登录
*/
-(void)login:(int)sdkAppID accType:(NSString*)accType userID:(NSString*)userID userSig:(NSString*)userSig completion:(ILoginCompletionCallback)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        // Room登录
        NSString * cgiUrl = [NSString stringWithFormat:@"%@/login?sdkAppID=%d&accountType=%@&userID=%@&userSig=%@", _serverDomain, sdkAppID, accType, userID, userSig];

        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"LiveRoom登录, userID[%@]", userID]];

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
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"LiveRoom登录失败: error[%@]", [error description]]];
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置", nil, nil);
                }
            }];
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
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"LiveRoom logout failed: error[%@]", [error description]]];
                if (completion) {
                    completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
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
        NSDictionary *params = @{@"userID": _userInfo.userID};
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求推流地址, userID[%@]", _userInfo.userID]];
        
        [_httpSession POST:_apiAddr[kHttpServerAddr_GetPushUrl] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                NSString *pushUrl = responseObject[@"pushURL"];
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr返回推流地址: errCode[%d] errMsg[%@] pushUrl[%@]", errCode, errMsg, pushUrl]];
                
                if (errCode == 0) {
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
   小主播在请求加入连麦成功后调用
   1. 在应用层调用startLocalPreview
   2. 结束播放房间的混流地址(mixedPlayURL)，改为播放大主播的直播流地址
   3. 请求kHttpServerAddr_GetPushers，获取房间里所有pusher的信息
   4. 通过onGetPusherList将房间里所有pusher信息回调给上层播放
   5. 请求kHttpServerAddr_GetPushUrl,获取推流地址
   6. 开始推流
   7. 在收到推流成功的事件后请求kHttpServerAddr_AddPusher，把自己加入房间成员列表
 */
- (void)joinPusher:(IJoinPusherCompletionHandler)completion {
    [self asyncRun:^{
        _roomRole = 2;  // 房间角色为小主播
        _joinPusherCompletion = completion;

        // 设置视频质量为小主播(连麦模式)
        if (_videoQuality != VIDEO_QUALITY_LINKMIC_SUB_PUBLISHER) {
            _videoQuality = VIDEO_QUALITY_LINKMIC_SUB_PUBLISHER;
            [_livePusher setVideoQuality:_videoQuality adjustBitrate:NO adjustResolution:NO];
            [_livePusher setLogViewMargin:UIEdgeInsetsMake(2, 2, 2, 2)];
        }
        
        TXLivePlayer *player = [_livePlayerDic objectForKey:_roomCreator];
        if (player) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [player stopPlay];
                // 播放大主播的直播流地址，注意type是 PLAY_TYPE_LIVE_RTMP_ACC
                [player startPlay:_roomCreatorUrl type:PLAY_TYPE_LIVE_RTMP_ACC];
            });
        }
        
        // 获取房间所有pusher信息
        __weak __typeof(self) weakSelf = self;
        [self getPusherList:^(int errCode, NSString *errMsg, RoomInfo *roomInfo) {
            if (errCode != 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (_delegate && [_delegate respondsToSelector:@selector(onError:errMsg:)]) {
                        [_delegate onError:errCode errMsg:errMsg];
                    }
                });
                return;
            }
            
            [weakSelf asyncRun:^{
                _roomInfo = roomInfo;
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_delegate) {
                    [_delegate onGetPusherList:roomInfo.pusherInfoArray];
                }
            });
        }];
        
        // 获取推流地址并推流
        [self getUrlAndPushing:completion];
    }];
}

/**
   小主播退出连麦
   1. 应用层调用stopLocalPreview，结束本地预览和停止推流
   2. 结束播放所有的流(playUrl)
   3. 播放房间的混流地址(mixedPlayURL),这里使用大主播的view来播放视频
   4. 请求 kHttpServerAddr_DeletePusher，将自己从房间成员列表里删除
 */
- (void)quitPusher:(IQuitPusherCompletionHandler)completion {
    [self asyncRun:^{
        _roomRole = 3;  // 房间角色变为普通观众
        
        // 关闭所有播放器
        for (id userID in _livePlayerDic) {
            if ([userID isEqualToString:_roomCreator] == NO) {
                TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
                [player stopPlay];
            
                RoomLivePlayListenerWrapper *playerEventWrapper = [_playerEventDic objectForKey:userID];
                [playerEventWrapper clear];
            }
        }
        
        // 用大主播的播放器来播放混流地址，这样可以复用之前的view
        TXLivePlayer *bigPlayer = [_livePlayerDic objectForKey:_roomCreator]; // 获取大主播的player
        RoomLivePlayListenerWrapper * playEvtWrapper = [_playerEventDic objectForKey:_roomCreator];
        playEvtWrapper.userID = _roomCreator;
        playEvtWrapper.delegate = self;
        
        [_livePlayerDic removeAllObjects];
        [_playerEventDic removeAllObjects];
    
        [_livePlayerDic setObject:bigPlayer forKey:_roomCreator];
        [_playerEventDic setObject:playEvtWrapper forKey:_roomCreator];
        
        if (_roomRole != 2 && [bigPlayer isPlaying]) {
            TXLivePlayConfig *playConfig = [[TXLivePlayConfig alloc] init];
            playConfig.bAutoAdjustCacheTime = YES;
            playConfig.minAutoAdjustCacheTime = 2.0f;
            playConfig.maxAutoAdjustCacheTime = 2.0f;
            [bigPlayer setConfig:playConfig];
            [bigPlayer stopPlay];
            [bigPlayer startPlay:_mixedPlayURL type:[self getPlayType:_mixedPlayURL]];
            if (_background == YES) {
                [bigPlayer pause];
            }
        }

        
        // 请求 kHttpServerAddr_DeletePusher
        __weak __typeof(self) weakSelf = self;
        NSDictionary *param = @{@"roomID": _roomID, @"userID": _userInfo.userID};
        [_httpSession POST:_apiAddr[kHttpServerAddr_DeletePusher] parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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
        
        // 停止心跳
        [self stopHeartBeat];
        
    }];
}

-(void) handleRequestJoinPusherTimeOut:(NSObject*)obj {
    if (_requestJoinPusherCompletion) {
        _requestJoinPusherCompletion(1, @"主播未处理您的连麦请求");
        _requestJoinPusherCompletion = nil;
    }
}

/**
   小主播发起连麦请求
 */
- (void)requestJoinPusher:(NSInteger)timeout withCompletion:(IRequestJoinPusherCompletionHandler)completion {
    [self asyncRun:^{
        _requestJoinPusherCompletion = completion;
        [_msgMgr sendLinkMicRequest:_roomCreator];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleRequestJoinPusherTimeOut:) object:self];
            [self performSelector:@selector(handleRequestJoinPusherTimeOut:) withObject:self afterDelay:timeout];
        });
    }];
}

/**
   大主播接受连麦请求
 */
- (void)acceptJoinPusher:(NSString *)userID {
    [self asyncRun:^{
        [_msgMgr sendLinkMicResponse:userID withResult:YES andReason:@""];
    }];
}

/**
   大主播拒绝连麦请求
 */
- (void)rejectJoinPusher:(NSString *)userID reason:(NSString *)reason {
    [self asyncRun:^{
        [_msgMgr sendLinkMicResponse:userID withResult:NO andReason:reason];
    }];
}

/**
   大主播踢掉小主播
 */
- (void)kickoutSubPusher:(NSString *)userID {
    [self asyncRun:^{
        // 发送踢掉消息
        [_msgMgr sendLinkMicKickout:userID];
        
        // 本地关闭播放器
        [self deleteRemoteView:userID];
        
        // 重新请求merge stream
        if (_roomInfo) {
            for (PusherInfo *pushInfo in _roomInfo.pusherInfoArray) {
                if ([pushInfo.userID isEqualToString:userID]) {
                    [_roomInfo.pusherInfoArray removeObject:pushInfo];
                    break;
                }
            }
        }
        
        NSMutableArray *playUrlArray = [[NSMutableArray alloc] init];
        for (PusherInfo *pusherInfo in _roomInfo.pusherInfoArray) {
            [playUrlArray addObject:pusherInfo.playUrl];
        }
        [self requestMergeStream:1 playUrlArray:playUrlArray withMode:1];
    }];
}

- (void)handleRequestPKTimeout:(NSObject *)obj {
    if (_requestPKCompletion) {
        _requestPKCompletion(1, @"主播未处理您的PK请求或者超时", nil);
        _requestPKCompletion = nil;
    }
}

/**
   主播PK: 发起PK请求
   请求带上自己的userID, userName, userAvatar, streamUrl
 */
- (void)sendPKReques:(NSString *)userID timeout:(NSInteger)timeout withCompletion:(IRequestPKCompletionHandler)completion {
    [self asyncRun:^{
        // 将pushUrl中的livepush替换成liveplay就是加速流播放地址
        NSString *accelerateURL = nil;
        NSRange range = [_pushUrl rangeOfString:@"livepush"];
        if (range.location != NSNotFound) {
            accelerateURL = [_pushUrl stringByReplacingCharactersInRange:range withString:@"liveplay"];
        }
        if (accelerateURL == nil) {
            [self sendDebugMsg:@"pushurl不合法"];
            return;
        }
        
        _requestPKCompletion = completion;
        [_msgMgr sendPKRequest:userID withAccelerateURL:accelerateURL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleRequestPKTimeout:) object:nil];
            [self performSelector:@selector(handleRequestPKTimeout:) withObject:nil afterDelay:timeout];
        });
    }];
}

/**
   主播PK: 发送结束PK的请求
 */
- (void)sendPKFinishRequest:(NSString *)userID {
    [self asyncRun:^{
        [_msgMgr sendPKFinishRequest:userID];
    }];
}

/**
   主播PK: 接受PK请求
   回包中带上自己的播放地址streamUrl
 */
- (void)acceptPKRequest:(NSString *)userID {
    [self asyncRun:^{
        // 将pushUrl中的livepush替换成liveplay就是加速流播放地址
        NSString *accelerateURL = nil;
        NSRange range = [_pushUrl rangeOfString:@"livepush"];
        if (range.location != NSNotFound) {
            accelerateURL = [_pushUrl stringByReplacingCharactersInRange:range withString:@"liveplay"];
        }
        if (accelerateURL == nil) {
            [self sendDebugMsg:@"pushurl不合法"];
            return;
        }
        
        [_msgMgr acceptPKRequest:userID withAccelerateURL:accelerateURL];
    }];
}

/**
   主播PK: 拒绝PK请求
 */
- (void)rejectPKRequest:(NSString *)userID reason:(NSString *)reason {
    [self asyncRun:^{
        [_msgMgr rejectPKRequest:userID reason:reason];
    }];
}

/**
   获取在线的主播列表(不包括自己)
 */
- (void)getOnlinePusherList:(IGetOnlinePusherListCompletionHandler)completion {
    [self getRoomList:0 cnt:100 withCompletion:^(int errCode, NSString *errMsg, NSArray<RoomInfo *> *roomInfoArray) {
        NSLog(@"getRoomList errCode[%d] errMsg[%@]", errCode, errMsg);
        
        NSMutableArray<PusherInfo *> *pusherInfoArray = [[NSMutableArray alloc] init];
        NSMutableSet *userIDSet = [[NSMutableSet alloc] init];
        
        for (RoomInfo *roomInfo in roomInfoArray) {
            for (PusherInfo *pusherInfo in roomInfo.pusherInfoArray) {
                // 遍历房间的pusher，找出房间创建者，即为主播， 注意过滤掉自己
                if ([pusherInfo.userID isEqualToString:roomInfo.roomCreator] && ![pusherInfo.userID isEqualToString:_userInfo.userID]) {
                    
                    // 注意过滤一下重复的userID，后台可能存在僵尸room，一个人是两个房间的创建者
                    if (![userIDSet containsObject:pusherInfo.userID]) {
                        [userIDSet addObject:pusherInfo.userID];
                        [pusherInfoArray addObject:pusherInfo];
                    }
                    break;
                }
            }
        }
        
        if (completion) {
            completion(pusherInfoArray);
        }
    }];
}

/**
   主播PK: 开始播放对方的流
   1. 调整推流参数，切换到连麦模式
   2. 播放加速流地址，拉取视频
   3. 启动后台混流，从播放地址里面取到对方的流ID，把对方的视频流“混流”到自己推的流上面
 */
- (void)startPlayPKStream:(NSString *)playUrl view:(UIView *)view playBegin:(IPlayBegin)playBegin playError:(IPlayError)playError {
    [self asyncRun:^{
        [_livePusher showVideoDebugLog:NO];
        
        // 设置推流模式为连麦模式
        _videoQuality = VIDEO_QUALITY_LINKMIC_MAIN_PUBLISHER;
        [_livePusher setVideoQuality:_videoQuality adjustBitrate:YES adjustResolution:NO];
        TXLivePushConfig * config = _livePusher.config;
        config.videoResolution = VIDEO_RESOLUTION_TYPE_360_640;
        config.enableAutoBitrate = NO;
        config.videoBitratePIN = 800;
        [_livePusher setConfig:config];
        [_livePusher setLogViewMargin:UIEdgeInsetsMake(66, 5, 5, 5)];
        
        // 播放加速流地址
        TXLivePlayer *player = [[TXLivePlayer alloc] init];
        
        RoomLivePlayListenerWrapper *playerEventWrapper = [[RoomLivePlayListenerWrapper alloc] init];
        playerEventWrapper.playBeginBlock = playBegin;
        playerEventWrapper.playErrorBlock = playError;
        player.delegate = playerEventWrapper;
        
        [_livePlayerDic setObject:player forKey:playUrl]; // 这里用playUrl做为key存储
        [_playerEventDic setObject:playerEventWrapper forKey:playUrl];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [player setupVideoWidget:CGRectZero containView:view insertIndex:0];
            [player setLogViewMargin:UIEdgeInsetsMake(66, 5, 5, 5)];
            [player startPlay:playUrl type:PLAY_TYPE_LIVE_RTMP_ACC];
        });
        
        // 启动混流
        NSArray *playUrlArray = @[playUrl];
        [self requestMergeStream:5 playUrlArray:playUrlArray withMode:2];
        
    }];
}

/**
   主播PK: 结束PK
   1. 调整推流参数，切换到直播模式
   2. 结束视频播放
   3. 取消混流
 */
- (void)stopPlayPKStream {
    [self asyncRun:^{
        [_livePusher showVideoDebugLog:NO];
        
        // 设置推流模式为直播模式(高清）
        _videoQuality = VIDEO_QUALITY_HIGH_DEFINITION;
        [_livePusher setVideoQuality:_videoQuality adjustBitrate:NO adjustResolution:NO];
        TXLivePushConfig * config = _livePusher.config;
        config.videoEncodeGop = 5;
        [_livePusher setConfig:config];
        [_livePusher setLogViewMargin:UIEdgeInsetsMake(120, 10, 60, 10)];
        
        // 关闭播放器
        dispatch_async(dispatch_get_main_queue(), ^{
            for (id userID in _livePlayerDic) {
                TXLivePlayer *player = [_livePlayerDic objectForKey:userID];
                [player stopPlay];
                
                RoomLivePlayListenerWrapper *playerEventWrapper = [_playerEventDic objectForKey:userID];
                [playerEventWrapper clear];
            }
            [_livePlayerDic removeAllObjects];
            [_playerEventDic removeAllObjects];
        });
        
        // 取消混流
        [self requestMergeStream:5 playUrlArray:nil withMode:2];
    }];
}

/**
 * 获取房间内所有pusher的信息
 */
typedef void (^IGetPusherListCompletionHandler)(int errCode, NSString *errMsg, RoomInfo *roomInfo);

- (void)getPusherList:(IGetPusherListCompletionHandler)completion {
    [self asyncRun:^{
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
                roomInfo.pusherInfoArray = [self parsePushersFromJsonArray:responseObject[@"pushers"] filterCreator:YES];
                
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
                    roomInfo.roomName = room[@"roomName"];
                    roomInfo.roomCreator = room[@"roomCreator"];
                    roomInfo.mixedPlayURL = room[@"mixedPlayURL"];
                    roomInfo.pusherInfoArray = [self parsePushersFromJsonArray:room[@"pushers"] filterCreator:NO];
                    roomInfo.audienceInfoArray = [self parseAudiencesFromJsonObject:room[@"audiences"]];
                    
                    [roomInfos addObject:roomInfo];
                }
                
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr返回房间列表: roomInfos[%@]", roomInfos]];
                
                if (completion) {
                    completion(errCode, errMsg, roomInfos);
                }
                
                _roomInfos = roomInfos;
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

- (void)getAudienceList:(NSString *)roomID  withCompletion:(IGetAudienceListCompletionHandler)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        NSDictionary *param = @{@"roomID": roomID};
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"发起获取房间观众列表请求: roomID[%@]",roomID]];
        
        [_httpSession POST:_apiAddr[kHttpServerAddr_GetAudienceList] parameters:param progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            [weakSelf asyncRun:^{
                int errCode = [responseObject[@"code"] intValue];
                NSString *errMsg = responseObject[@"message"];
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复获取房间观众列表请求: errCode[%d] errMsg[%@]", errCode, errMsg]];
                
                if (errCode != 0) {
                    if (completion) {
                        completion(ROOM_ERR_REQUEST_TIMEOUT, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode], nil);
                    }
                    return;
                }
                
                NSArray *audiences = responseObject[@"audiences"];
                NSMutableArray *audienceInfos = [[NSMutableArray alloc] init];
                
                for (id audience in audiences) {
                    AudienceInfo *audienceInfo = [[AudienceInfo alloc] init];
                    audienceInfo.userID = audience[@"userID"];
                    audienceInfo.userInfo = audience[@"userInfo"];
                    [audienceInfos addObject:audienceInfo];
                }
                
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr返回房间观众列表: audienceInfos[%@]", audienceInfos]];
                
                if (completion) {
                    completion(errCode, errMsg, audienceInfos);
                }
                
                _audienceInfos = audienceInfos;
            }];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"房间观众列表请求失败: error[%@]", [error description]]];
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

- (void)sendRoomCustomMsg:(NSString *)cmd msg:(NSString *)msg {
    [self asyncRun:^{
        [_msgMgr sendRoomCustomMsg:cmd msg:msg];
    }];
}

- (NSMutableArray<PusherInfo *> *)parsePushersFromJsonArray:(NSArray *)pushers filterCreator:(BOOL)filterCreator {
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
        
        // 注意：这里将大主播过滤掉 (为了上层使用方便)
        // 内部使用时需要过滤，如果是外面调用getRoomList接口时则不能过滤，不然显示在线人数有问题
        if (filterCreator && [pusherInfo.userID isEqualToString:_roomCreator]) {
            continue;
        }
        
        [pusherInfoArray addObject:pusherInfo];
    }
    
    return pusherInfoArray;
}

- (NSMutableArray<AudienceInfo *> *)parseAudiencesFromJsonObject:(NSDictionary *)audiences {
    if (audiences == nil) {
        return nil;
    }
    
    NSMutableArray<AudienceInfo *> *audienceInfoArray = [[NSMutableArray alloc] init];
    NSArray * array = audiences[@"audiences"];
    if (array != nil && array.count > 0) {
        for (id item in array) {
            AudienceInfo * audienceInfo = [[AudienceInfo alloc] init];
            audienceInfo.userID = item[@"userID"];
            audienceInfo.userInfo = item[@"userInfo"];
            
            // 注意：这里将自己过滤掉 (为了上层使用方便)
            if ([audienceInfo.userID isEqualToString:_userInfo.userID]) {
                continue;
            }
            
            [audienceInfoArray addObject:audienceInfo];
        }
    }

    return audienceInfoArray;
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
            player = [[TXLivePlayer alloc] init];
            
            RoomLivePlayListenerWrapper *playerEventWrapper = [[RoomLivePlayListenerWrapper alloc] init];
            playerEventWrapper.playBeginBlock = playBegin;
            playerEventWrapper.playErrorBlock = playError;
            
            player.delegate = playerEventWrapper;
            
            [_livePlayerDic setObject:player forKey:userID];
            [_playerEventDic setObject:playerEventWrapper forKey:userID];
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

- (void)toggleTorch:(BOOL)bEnable {
    [_livePusher toggleTorch:bEnable];
}

- (void)setMute:(BOOL)isMute {
    _mutePusher = isMute;
    [_livePusher setMute:isMute];
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

/**
   美颜相关
 */
- (void)setBeautyStyle:(int)beautyStyle beautyLevel:(float)beautyLevel whitenessLevel:(float)whitenessLevel ruddinessLevel:(float)ruddinessLevel {
    [_livePusher setBeautyStyle:beautyStyle beautyLevel:beautyLevel whitenessLevel:whitenessLevel ruddinessLevel:ruddinessLevel];
}

- (void)setEyeScaleLevel:(float)eyeScaleLevel {
    [_livePusher setEyeScaleLevel:eyeScaleLevel];
}

- (void)setFaceScaleLevel:(float)faceScaleLevel {
    [_livePusher setFaceScaleLevel:faceScaleLevel];
}

- (void)setFaceVLevel:(float)faceVLevel {
    [_livePusher setFaceVLevel:faceVLevel];
}

- (void)setChinLevel:(float)chinLevel {
    [_livePusher setChinLevel:chinLevel];
}

- (void)setFaceShortLevel:(float)faceShortlevel {
    [_livePusher setFaceShortLevel:faceShortlevel];
}

- (void)setNoseSlimLevel:(float)noseSlimLevel {
    [_livePusher setNoseSlimLevel:noseSlimLevel];
}

- (void)setFilter:(UIImage *)image {
    [_livePusher setFilter:image];
}

- (void)setSpecialRatio:(float)specialValue {
    [_livePusher setSpecialRatio:specialValue];
}

- (void)setGreenScreenFile:(NSURL *)file {
    [_livePusher setGreenScreenFile:file];
}

- (void)selectMotionTmpl:(NSString *)tmplName inDir:(NSString *)tmplDir {
    [_livePusher selectMotionTmpl:tmplName inDir:tmplDir];
}

- (BOOL)playBGM:(NSString *)path {
    return [_livePusher playBGM:path];
}

- (BOOL)playBGM:(NSString *)path
        withBeginNotify:(void (^)(NSInteger errCode))beginNotify
        withProgressNotify:(void (^)(NSInteger progressMS, NSInteger durationMS))progressNotify
        andCompleteNotify:(void (^)(NSInteger errCode))completeNotify {
    return [_livePusher playBGM:path withBeginNotify:beginNotify withProgressNotify:progressNotify andCompleteNotify:completeNotify];
}

- (BOOL)stopBGM {
    return [_livePusher stopBGM];
}

- (BOOL)pauseBGM {
    return [_livePusher pauseBGM];
}

- (BOOL)resumeBGM {
    return [_livePusher resumeBGM];
}

- (int)getMusicDuration:(NSString *)path {
    return [_livePusher getMusicDuration:path];
}

- (BOOL)setMicVolume:(float)volume {
    return [_livePusher setMicVolume:volume];
}

- (BOOL)setBGMVolume:(float)volume {
    return [_livePusher setBGMVolume:volume];
}

#pragma mark - TXLivePushListener

-(void) onPushEvent:(int)EvtID withParam:(NSDictionary*)param {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        
        if (EvtID == PUSH_EVT_PUSH_BEGIN) {
            if (_roomRole == 1) {  // 创建者
                // rtmp推流过程中每次重连都会下发PUSH_EVT_PUSH_BEGIN，需要加一个BOOL变量来保护下，避免重复请求create_room，
                // 只能在第一次或者调用过exitRoom后才能够请求create_room
                if (_created) {
                    return;
                }
                
                //调用CGI：create_room，返回roomID
                [self doCreateRoom:^(int errCode, NSString *errMsg, NSString *roomID) {
                    if (errCode == 0) {
                        _roomID = roomID;
                        _created = YES; // 标记已经创建房间
                        
                        //请求CGI：add_pusher，加入房间
                        [self doAddPusher:roomID completion:^(int errCode, NSString *errMsg) {
                            if (errCode == 0) {
                        
                                //调用IM的joinGroup，加入群组
                                [weakSelf.msgMgr enterRoom:roomID completion:^(int errCode, NSString *errMsg) {
                                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"加入IMGroup完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
                                    if (weakSelf.createRoomCompletion) {
                                        weakSelf.createRoomCompletion(errCode, errMsg);
                                        weakSelf.createRoomCompletion = nil;
                                }
                            }];
                                [weakSelf startHeartBeat]; // 启动心跳
                            }
                            else {
                                if (weakSelf.createRoomCompletion) {
                                    weakSelf.createRoomCompletion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                                    weakSelf.createRoomCompletion = nil;
                                }
                            }
                        }];
                    }
                    else {
                        if (weakSelf.createRoomCompletion) {
                            weakSelf.createRoomCompletion(ROOM_ERR_CREATE_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                            weakSelf.createRoomCompletion = nil;
                        }
                    }
                }];
            }
            else if (_roomRole == 2) {  // 小主播
                //请求CGI：add_pusher，加入房间
                [self doAddPusher:_roomID completion:^(int errCode, NSString *errMsg) {
                    if (errCode == 0) {
                        if (weakSelf.joinPusherCompletion) {
                            weakSelf.joinPusherCompletion(errCode, errMsg);
                            weakSelf.joinPusherCompletion = nil;
                        }
                
                    } else {
                        if (weakSelf.joinPusherCompletion) {
                            weakSelf.joinPusherCompletion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                            weakSelf.joinPusherCompletion = nil;
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

            } else if (_joinPusherCompletion) {
                _joinPusherCompletion(ROOM_ERR_ENTER_ROOM, errMsg);
                _joinPusherCompletion = nil;
                
            } else {
                if (_delegate && [_delegate respondsToSelector:@selector(onError:errMsg:)]) {
                    [_delegate onError:ROOM_ERR_PUSH_DISCONNECT errMsg:errMsg];
                }
            }
            
        } else if (EvtID == PUSH_ERR_OPEN_CAMERA_FAIL) {
            NSString *errMsg = @"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;
                
            } else if (_joinPusherCompletion) {
                _joinPusherCompletion(ROOM_ERR_ENTER_ROOM, errMsg);
                _joinPusherCompletion = nil;
            }
            
        } else if (EvtID == PUSH_ERR_OPEN_MIC_FAIL) {
            NSString *errMsg = @"获取麦克风权限失败，请前往隐私-麦克风设置里面打开应用权限";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;
                
            } else if (_joinPusherCompletion) {
                _joinPusherCompletion(ROOM_ERR_ENTER_ROOM, errMsg);
                _joinPusherCompletion = nil;
            }
        }
    }];
}

-(void) onNetStatus:(NSDictionary*)param {
    
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

    [_httpSession POST:_apiAddr[kHttpServerAddr_AddPusher] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [weakSelf asyncRun:^{
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复add_pusher: errCode[%d] errMsg[%@]", errCode, errMsg]];
            
            if (errCode == 0) {
                if (completion) {
                    completion(errCode, errMsg);
                }
            } else {
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


typedef void (^IAddAudienceCompletionSink)(int errCode, NSString *errMsg);

- (void)doAddAudience:(NSString*)roomID userID:(NSString*)userID userInfo:(NSString*)userInfo completion:(IAddAudienceCompletionSink)completion {
    __weak __typeof(self) weakSelf = self;
    
    [weakSelf sendDebugMsg:[NSString stringWithFormat:@"开始请求add_audience"]];
    
    NSDictionary *params = @{@"roomID": roomID, @"userID": userID, @"userInfo": userInfo};
    
    [_httpSession POST:_apiAddr[kHttpServerAddr_AddAudience] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [weakSelf asyncRun:^{
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复add_audience: errCode[%d] errMsg[%@]", errCode, errMsg]];
            
            if (errCode == 0) {
                if (completion) {
                    completion(errCode, errMsg);
                }
            } else {
                if (completion) {
                    completion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                }
            }
        }];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求add_audience失败: error[%@]", [error description]]];
        [weakSelf asyncRun:^{
            if (completion) {
                completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
            }
        }];
    }];
}

typedef void (^IDeleteAudienceCompletionSink)(int errCode, NSString *errMsg);

- (void)doDeleteAudience:(NSString*)roomID userID:(NSString*)userID completion:(IDeleteAudienceCompletionSink)completion {
    __weak __typeof(self) weakSelf = self;
    
    [weakSelf sendDebugMsg:[NSString stringWithFormat:@"开始请求delete_audience"]];
    
    NSDictionary *params = @{@"roomID": roomID, @"userID": userID};
    
    [_httpSession POST:_apiAddr[kHttpServerAddr_DeleteAudience] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [weakSelf asyncRun:^{
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复delete_audience: errCode[%d] errMsg[%@]", errCode, errMsg]];
            
            if (errCode == 0) {
                if (completion) {
                    completion(errCode, errMsg);
                }
            } else {
                if (completion) {
                    completion(ROOM_ERR_ENTER_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                }
            }
        }];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求delete_audience失败: error[%@]", [error description]]];
        [weakSelf asyncRun:^{
            if (completion) {
                completion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
            }
        }];
    }];
}

#pragma mark - IRoomLivePlayListener
-(void)onLivePlayNetStatus:(NSString*) userID withParam: (NSDictionary*) param {
    if (_roomCreator != nil && [_roomCreator isEqualToString:userID]) {
        if (param) {
            int renderMode = RENDER_MODE_FILL_SCREEN;
            int width  = [(NSNumber*)[param valueForKey:NET_STATUS_VIDEO_WIDTH] intValue];
            int height = [(NSNumber*)[param valueForKey:NET_STATUS_VIDEO_HEIGHT] intValue];
            if (width > 0 && height > 0) {
                //pc上混流后的宽高比为4:5，这种情况下填充模式会把左右的小主播窗口截掉一部分，用适应模式比较合适
                float ratio = (float) height / width;
                if (ratio > 1.3f) {
                    renderMode = RENDER_MODE_FILL_SCREEN;
                }
                else {
                    renderMode = RENDER_MODE_FILL_EDGE;
                }
                if (_renderMode != renderMode) {
                    _renderMode = renderMode;
                    TXLivePlayer * livePlayer = [_livePlayerDic objectForKey:_roomCreator];
                    if (livePlayer) {
                        [livePlayer setRenderMode:_renderMode];
                    }
                }
            }
        }
    }
}

-(void)onLivePlayEvent:(NSString*) userID withEvtID:(int)EvtID andParam:(NSDictionary*)param {
    if (EvtID == PLAY_ERR_NET_DISCONNECT){
        if (_roomCreator != nil && [_roomCreator isEqualToString:userID]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_delegate) {
                    [_delegate onError:EvtID errMsg:@"播放地址无效或者当前没有数据"];
                }
            });
        }
        else {
            [self deleteRemoteView:userID];
        }
    }
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
    if (_roomRole == 3) { // 普通观众不需要关注这个消息
        return;
    }
    if (_background == YES) { //切后台期间，忽略这个消息
        return;
    }
    
    [self onPusherChanged];
}


- (void)onGroupDelete:(NSString *)groupID {
    [self sendDebugMsg:[NSString stringWithFormat:@"房间[%@]被解散", groupID]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onRoomClose:)]) {
            [_delegate onRoomClose:groupID];
        }
    });
}

// 接收到小主播的连麦请求
- (void)onRecvLinkMicRequest:(NSString *)groupID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar {
    if (![groupID isEqualToString:_roomID]) {
        return;
    }
    
    [self sendDebugMsg:[NSString stringWithFormat:@"收到小主播[%@-%@]连麦请求", userID, userName]];
    [self asyncRun:^{
        if (_roomInfo) {
            for (PusherInfo *pushInfo in _roomInfo.pusherInfoArray) {
                if ([pushInfo.userID isEqualToString:userID]) {
                    [_roomInfo.pusherInfoArray removeObject:pushInfo];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (_delegate && [_delegate respondsToSelector:@selector(onPusherQuit:)]) {
                            [_delegate onPusherQuit:pushInfo];
                        }
                    });
                    break;
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_delegate && [_delegate respondsToSelector:@selector(onRecvJoinPusherRequest:userName:userAvatar:)]) {
                [_delegate onRecvJoinPusherRequest:userID userName:userName userAvatar:userAvatar];
            }
        });
    }];
}

// 接收到大主播的连麦回应， result为YES表示同意连麦，为NO表示拒绝连麦
- (void)onRecvLinkMicResponse:(NSString *)groupID result:(BOOL)result message:(NSString *)message {
    if (![groupID isEqualToString:_roomID]) {
        return;
    }
    
    [self sendDebugMsg:[NSString stringWithFormat:@"收到大主播回应连麦请求:result[%d] message[%@]", result, message]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleRequestJoinPusherTimeOut:) object:self];
        if (_requestJoinPusherCompletion) {
            if (result) {
                _requestJoinPusherCompletion(0, message);
            } else {
                _requestJoinPusherCompletion(1, message);
            }
            _requestJoinPusherCompletion = nil;
        }
    });
}

// 接收到被大主播的踢出连麦的消息
- (void)onRecvLinkMicKickout:(NSString *)groupID {
    if (![groupID isEqualToString:_roomID]) {
        return;
    }
    
    [self sendDebugMsg:@"收到被大主播踢出连麦的消息"];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onKickout)]) {
            [_delegate onKickout];
        }
    });
}

// 接收群自定义消息，cmd为自定义命令字，msg为自定义消息体(这里统一使用json字符串)
- (void)onRecvGroupCustomMsg:(NSString *)groupID userID:(NSString *)userID cmd:(NSString *)cmd msg:(NSString *)msg userName:(NSString *)userName userAvatar:(NSString *)userAvatar {
    if (![groupID isEqualToString:_roomID]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onRecvRoomCustomMsg:userID:userName:userAvatar:cmd:msg:)]) {
            [_delegate onRecvRoomCustomMsg:groupID userID:userID userName:userName userAvatar:userAvatar cmd:cmd msg:msg];
        }
    });
}

// 接收到PK请求
- (void)onRecvPKRequest:(NSString *)groupID userID:(NSString *)userID userName:(NSString *)userName userAvatar:(NSString *)userAvatar streamUrl:(NSString *)streamUrl {
    [self sendDebugMsg:[NSString stringWithFormat:@"收到房间[%@]主播[%@]的PK请求", groupID, userID]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onRecvPKRequest:userName:userAvatar:streamUrl:)]) {
            [_delegate onRecvPKRequest:userID userName:userName userAvatar:userAvatar streamUrl:streamUrl];
        }
    });
}

// 接收到PK请求回应, result为YES表示同意PK，为NO表示拒绝PK，若同意，则streamUrl为对方的播放流地址
- (void)onRecvPKResponse:(NSString *)groupID userID:(NSString *)userID result:(BOOL)result message:(NSString *)message streamUrl:(NSString *)streamUrl {
    [self sendDebugMsg:[NSString stringWithFormat:@"收到房间[%@]主播[%@]回应PK请求:result[%d] message[%@]", groupID, userID, result, message]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(handleRequestPKTimeout:) object:nil];
        if (_requestPKCompletion) {
            if (result) {
                _requestPKCompletion(0, message, streamUrl);
            } else {
                _requestPKCompletion(1, message, nil);
            }
            _requestPKCompletion = nil;
        }
    });
}

// 接收PK结束消息
- (void)onRecvPKFinishRequest:(NSString *)groupID userID:(NSString *)userID {
    [self sendDebugMsg:[NSString stringWithFormat:@"收到房间[%@]主播[%@]的结束PK消息", groupID, userID]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onRecvPKFinishRequest:)]) {
            [_delegate onRecvPKFinishRequest:userID];
        }
    });
}

- (void)onPusherChanged {
    [self getPusherList:^(int errCode, NSString *errMsg, RoomInfo *roomInfo) {
        NSLog(@"onMemberChanged getMemberList errCode[%d] errMsg[%@]", errCode, errMsg);
        if (errCode != 0) {
            return;
        }
        
        BOOL pusherChanged = NO;
        
        RoomInfo *newRoomInfo = roomInfo;
        RoomInfo *oldRoomInfo = _roomInfo;
        
        
        NSMutableSet *leaveSet = [[NSMutableSet alloc] init];
        for (PusherInfo *pusherInfo in oldRoomInfo.pusherInfoArray) {
            if (pusherInfo) {
                [leaveSet addObject:pusherInfo];
            }
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
                
                pusherChanged = YES;
                
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
            
            pusherChanged = YES;
        }
        
        // 更新
        _roomInfo = newRoomInfo;
        
        if (_roomRole == 1) {
            // 当连麦人数发生变化时，大主播需要重新向服务器请求混流
            if (pusherChanged) {
                NSMutableArray *playUrlArray = [[NSMutableArray alloc] init];
                for (PusherInfo *pusherInfo in _roomInfo.pusherInfoArray) {
                    [playUrlArray addObject:pusherInfo.playUrl];
                }
                [self requestMergeStream:5 playUrlArray:playUrlArray withMode:1];
            }
            
            // 当存在其他推流者时，就是连麦模式
            if (_roomInfo.pusherInfoArray.count > 0) {
                // 设置视频质量为大主播(连麦模式)
                if (_videoQuality != VIDEO_QUALITY_LINKMIC_MAIN_PUBLISHER) {
                    _videoQuality = VIDEO_QUALITY_LINKMIC_MAIN_PUBLISHER;
                    [_livePusher setVideoQuality:_videoQuality adjustBitrate:YES adjustResolution:NO];
                }
            } else {
                // 设置视频质量为高清(直播模式)
                if (_videoQuality != VIDEO_QUALITY_HIGH_DEFINITION) {
                    _videoQuality = VIDEO_QUALITY_HIGH_DEFINITION;
                    [_livePusher setVideoQuality:_videoQuality adjustBitrate:NO adjustResolution:NO];
                    TXLivePushConfig * config = _livePusher.config;
                    config.videoEncodeGop = 5;
                    [_livePusher setConfig:config];
                }
            }
        }
    }];
}

- (void)sendDebugMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(onDebugMsg:)]) {
            [_delegate onDebugMsg:msg];
        }
    });
}

#pragma mark -- 连麦混流

// mode: 1 表示连麦模式   2 表示PK模式， 二者画面布局不同
// playUrlArray 表示待混流的播放地址(自己除外)
- (void)requestMergeStream: (int)retryCount playUrlArray:(NSArray<NSString *> *)playUrlArray withMode:(NSInteger)mode {
    NSDictionary *mergeParams = nil;
    if (mode == 2 && playUrlArray.count > 0) {
        mergeParams = [self createPKMergeParams:playUrlArray];
    } else {
        mergeParams = [self createLinkMicMergeParams:playUrlArray];
    }
    NSDictionary *param = @{@"userID": _userInfo.userID, @"roomID": _roomID, @"mergeParams": mergeParams};
    [self performSelectorInBackground: @selector(internalSendRequest:) withObject:@[[NSNumber numberWithInt:retryCount], param]];
}

// 连麦合流参数
- (NSDictionary*)createLinkMicMergeParams:(NSArray<NSString *> *)playUrlArray {
    NSString *mainStreamId = [self getStreamIDByStreamUrl:_pushUrl];
    
    NSMutableArray * inputStreamList = [NSMutableArray new];
    
    //大主播
    NSDictionary * mainStream = @{
                                  @"input_stream_id": mainStreamId,
                                  @"layout_params": @{@"image_layer": [NSNumber numberWithInt:1]}
                                  };
    [inputStreamList addObject:mainStream];
    
    NSString * streamInfo = [NSString stringWithFormat:@"mainStream: %@", mainStreamId];
    
    
    int mainStreamWidth = 540;
    int mainStreamHeight = 960;
    int subWidth  = 160;
    int subHeight = 240;
    int offsetHeight = 90;
    if (mainStreamWidth < 540 || mainStreamHeight < 960) {
        subWidth  = 120;
        subHeight = 180;
        offsetHeight = 60;
    }
    int subLocationX = mainStreamWidth - subWidth;
    int subLocationY = mainStreamHeight - subHeight - offsetHeight;
    
    NSMutableArray *subStreamIds = [[NSMutableArray alloc] init];
    for (NSString *playUrl in playUrlArray) {
        [subStreamIds addObject:[self getStreamIDByStreamUrl:playUrl]];
    }
    
    //小主播
    int index = 0;
    for (NSString * item in subStreamIds) {
        NSDictionary * subStream = @{
                                     @"input_stream_id": item,
                                     @"layout_params": @{
                                             @"image_layer": [NSNumber numberWithInt:(index + 2)],
                                             @"image_width": [NSNumber numberWithInt: subWidth],
                                             @"image_height": [NSNumber numberWithInt: subHeight],
                                             @"location_x": [NSNumber numberWithInt:subLocationX],
                                             @"location_y": [NSNumber numberWithInt:(subLocationY - index * subHeight)]
                                             }
                                     };
        ++index;
        [inputStreamList addObject:subStream];
        
        streamInfo = [NSString stringWithFormat:@"%@ subStream%d: %@", streamInfo, index, item];
    }
    
    NSLog(@"MergeVideoStream: %@", streamInfo);
    
    //para
    NSDictionary * para = @{
                            @"app_id": [NSNumber numberWithInt:[_appID intValue]] ,
                            @"interface": @"mix_streamv2.start_mix_stream_advanced",
                            @"mix_stream_session_id": mainStreamId,
                            @"output_stream_id": mainStreamId,
                            @"input_stream_list": inputStreamList
                            };
    
    //interface
    NSDictionary * interface = @{
                                 @"interfaceName":@"Mix_StreamV2",
                                 @"para":para
                                 };
    
    
    //mergeParams
    NSDictionary * mergeParams = @{
                                   @"timestamp": [NSNumber numberWithLong: (long)[[NSDate date] timeIntervalSince1970]],
                                   @"eventId": [NSNumber numberWithLong: (long)[[NSDate date] timeIntervalSince1970]],
                                   @"interface": interface
                                   };
    return mergeParams;
}

// PK合流参数
- (NSDictionary*)createPKMergeParams:(NSArray<NSString *> *)playUrlArray {
    NSString *mainStreamId = [self getStreamIDByStreamUrl:_pushUrl];
    NSString *pkStreamId = @"";
    for (NSString *playUrl in playUrlArray) {  // 目前只会有一个主播PK
        pkStreamId = [self getStreamIDByStreamUrl:playUrl];
        break;
    }
    
    NSMutableArray * inputStreamList = [NSMutableArray new];
    
    //画布
    NSDictionary * canvasStream = @{
                                    @"input_stream_id": mainStreamId,
                                    @"layout_params": @{
                                            @"image_layer": @(1),
                                            @"input_type": @(3),
                                            @"image_width": @(720),
                                            @"image_height": @(640)
                                            }
                                  };
    [inputStreamList addObject:canvasStream];
    
    // mainStream
    NSDictionary * mainStream = @{
                                    @"input_stream_id": mainStreamId,
                                    @"layout_params": @{
                                            @"image_layer": @(2),
                                            @"image_width": @(360),
                                            @"image_height": @(640),
                                            @"location_x": @(0),
                                            @"location_y": @(0)
                                            }
                                    };
    [inputStreamList addObject:mainStream];
    
    // pkStream
    NSDictionary * pkStream = @{
                                  @"input_stream_id": pkStreamId,
                                  @"layout_params": @{
                                          @"image_layer": @(3),
                                          @"image_width": @(360),
                                          @"image_height": @(640),
                                          @"location_x": @(360),
                                          @"location_y": @(0)
                                          }
                                  };
    [inputStreamList addObject:pkStream];
    
    
    //para
    NSDictionary * para = @{
                            @"app_id": [NSNumber numberWithInt:[_appID intValue]] ,
                            @"interface": @"mix_streamv2.start_mix_stream_advanced",
                            @"mix_stream_session_id": mainStreamId,
                            @"output_stream_id": mainStreamId,
                            @"input_stream_list": inputStreamList
                            };
    
    //interface
    NSDictionary * interface = @{
                                 @"interfaceName":@"Mix_StreamV2",
                                 @"para":para
                                 };
    
    
    //mergeParams
    NSDictionary * mergeParams = @{
                                   @"timestamp": [NSNumber numberWithLong: (long)[[NSDate date] timeIntervalSince1970]],
                                   @"eventId": [NSNumber numberWithLong: (long)[[NSDate date] timeIntervalSince1970]],
                                   @"interface": interface
                                   };
    return mergeParams;
}

- (NSString*) getStreamIDByStreamUrl:(NSString*) strStreamUrl {
    if (strStreamUrl == nil || strStreamUrl.length == 0) {
        return nil;
    }
    
    //推流地址格式：rtmp://8888.livepush.myqcloud.com/path/8888_test_12345_test?txSecret=aaaa&txTime=bbbb
    //拉流地址格式：rtmp://8888.liveplay.myqcloud.com/path/8888_test_12345_test
    //            http://8888.liveplay.myqcloud.com/path/8888_test_12345_test.flv
    //            http://8888.liveplay.myqcloud.com/path/8888_test_12345_test.m3u8
    
    NSString * strSubString = strStreamUrl;
    
    {
        //1 截取第一个 ？之前的子串
        NSString * strFind = @"?";
        NSRange range = [strSubString rangeOfString:strFind];
        if (range.location != NSNotFound) {
            strSubString = [strSubString substringToIndex:range.location];
        }
        if (strSubString == nil || strSubString.length == 0) {
            return nil;
        }
    }
    
    {
        //2 截取最后一个 / 之后的子串
        NSString * strFind = @"/";
        NSRange range = [strSubString rangeOfString:strFind options:NSBackwardsSearch];
        if (range.location != NSNotFound) {
            strSubString = [strSubString substringFromIndex:range.location + range.length];
        }
        if (strSubString == nil || strSubString.length == 0) {
            return nil;
        }
    }
    
    {
        //3 截取第一个 . 之前的子串
        NSString * strFind = @".";
        NSRange range = [strSubString rangeOfString:strFind];
        if (range.location != NSNotFound) {
            strSubString = [strSubString substringToIndex:range.location];
        }
        if (strSubString == nil || strSubString.length == 0) {
            return nil;
        }
    }
    
    return strSubString;
}

-(void) internalSendRequest: (NSArray*)array
{
    if ([array count] < 2) {
        return;
    }
    
    NSNumber * numRetryIndex = [array objectAtIndex:0];
    NSDictionary* mergeParams = [array objectAtIndex:1];
    
    NSLog(@"MergeVideoStream: sendRequest, retryIndex = %d", [numRetryIndex intValue]);
          
    __weak __typeof(self) weakSelf = self;
    [_httpSession POST:_apiAddr[kHttpServerAddr_MergeStream] parameters:mergeParams progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [weakSelf asyncRun:^{
            
            int errCode = [responseObject[@"code"] intValue];
            NSString *errMsg = responseObject[@"message"];
            NSDictionary *result = responseObject[@"result"];
            
            int code = -1;
            NSString * message = @"";
            unsigned long long  timestamp = -1;
            if (result && result[@"code"] && result[@"message"] && result[@"timestamp"]) {
                code = [result[@"code"] intValue];
                message = result[@"message"];
                timestamp = [result[@"timestamp"] unsignedLongLongValue];
            }
            
            NSLog(@"MergeVideoStream: recvResponse errCode[%d] errMsg[%@] description[code = %d message = %@ timestamp = %llu]", errCode, errMsg, code, message, timestamp);
            
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复merge_video_stream请求: errCode[%d] errMsg[%@] description[code = %d message = %@ timestamp = %llu]", errCode, errMsg, code, message, timestamp]];
            
            if (code != 0) {
                int retryIndex = [numRetryIndex intValue];
                --retryIndex;
                if (retryIndex > 0) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self performSelectorInBackground: @selector(internalSendRequest:) withObject:@[[NSNumber numberWithInt:retryIndex], mergeParams]];
                    });
                }
            }
        }];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [weakSelf asyncRun:^{
            [weakSelf sendDebugMsg:[NSString stringWithFormat:@"merge_video_stream请求失败: error[%@]", [error description]]];
        }];
    }];
}

-(int)getPlayType:(NSString*)playUrl {
    if ([playUrl hasPrefix:@"rtmp:"]) {
        return  PLAY_TYPE_LIVE_RTMP;
    }
    else if (([playUrl hasPrefix:@"https:"] || [playUrl hasPrefix:@"http:"]) && ([playUrl rangeOfString:@".flv"].length > 0)) {
        return PLAY_TYPE_LIVE_FLV;
    }
    else{
        return PLAY_TYPE_LIVE_FLV;
    }
}
@end
