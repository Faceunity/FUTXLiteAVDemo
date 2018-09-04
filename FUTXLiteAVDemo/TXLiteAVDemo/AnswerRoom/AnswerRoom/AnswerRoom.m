//
//  AnswerRoom.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/10/30.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "AnswerRoom.h"
#import "TXLiveSDKTypeDef.h"
#import "TXLivePush.h"
#import "TXLivePlayer.h"
#import "AFNetworking.h"
#import "RoomMsgMgr.h"

// 业务服务器API
#define kHttpServerAddr_GetRoomList     @"get_room_list"
#define kHttpServerAddr_GetPushUrl      @"get_push_url"
#define kHttpServerAddr_GetPushers      @"get_pushers"
#define kHttpServerAddr_CreateRoom      @"create_room"
#define kHttpServerAddr_AddPusher       @"add_pusher"
#define kHttpServerAddr_DeletePusher    @"delete_pusher"
#define kHttpServerAddr_PusherHeartBeat @"pusher_heartbeat"
#define kHttpServerAddr_GetIMLoginInfo  @"get_im_login_info"



@interface AnswerRoom() <TXLivePushListener, TXLivePlayListener, RoomMsgListener> {
    RoomMsgMgr              *_msgMgr;
    TXLivePush              *_answerPusher;
    NSMutableDictionary     *_answerPlayerDic;  // [userID, player]
    NSMutableArray          *_roomInfos;      // 保存最近一次拉回的房间列表
    AFHTTPSessionManager    *_httpSession;
    NSString                *_serverDomain;   // 保存业务服务器域名
    NSMutableDictionary     *_apiAddr;        // 保存业务服务器相关的rest api
    
    SelfAccountInfo         *_userInfo;
    NSString                *_pushUrl;
    NSString                *_roomID;
    NSString                *_roomName;

    dispatch_source_t       _heartBeatTimer;
    dispatch_queue_t        _queue;
    
    int                     _roomRole;        // 房间角色，创建者(大主播):1  小主播:2  普通观众:3
    BOOL                    _created;         // 标记是否已经创建过房间
    
    ICreateRoomCompletionHandler  _createRoomCompletion;
}
@end

@implementation AnswerRoom

- (instancetype)init {
    if (self = [super init]) {
        TXLivePushConfig *config = [[TXLivePushConfig alloc] init];
        config.videoEncodeGop = 1;
        config.audioSampleRate = AUDIO_SAMPLE_RATE_48000;
        config.videoResolution = VIDEO_RESOLUTION_TYPE_360_640;
        config.enableAutoBitrate = YES;
        config.videoBitrateMin = 600;
        config.videoBitrateMax = 1000;
        config.autoAdjustStrategy = AUTO_ADJUST_LIVEPUSH_RESOLUTION_STRATEGY;
        config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
        config.pauseFps = 15;
        config.pauseTime = 0x7fffffff;
        
        _answerPusher = [[TXLivePush alloc] initWithConfig:config];
        _answerPusher.delegate = self;
        
        _answerPlayerDic = [[NSMutableDictionary alloc] init];
        _roomInfos = [[NSMutableArray alloc] init];
        
        _httpSession = [AFHTTPSessionManager manager];
        [_httpSession setRequestSerializer:[AFJSONRequestSerializer serializer]];
        [_httpSession setResponseSerializer:[AFJSONResponseSerializer serializer]];
        [_httpSession.requestSerializer willChangeValueForKey:@"timeoutInterval"];
        _httpSession.requestSerializer.timeoutInterval = 5.0;
        [_httpSession.requestSerializer didChangeValueForKey:@"timeoutInterval"];
        _httpSession.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/xml", @"text/plain", nil];
        
        _queue = dispatch_queue_create("AnswerRoomQueue", DISPATCH_QUEUE_SERIAL);
        
        _created = NO;
    }
    return self;
}

typedef void (^block)();
- (void)asyncRun:(block)block {
    dispatch_async(_queue, ^{
        block();
    });
}

- (NSString *)getApiAddr:(NSString *)api {
    return [NSString stringWithFormat:@"%@/%@", _serverDomain, api];
}

// 保存所有server API
- (void)initApiAddr {
    _apiAddr = [[NSMutableDictionary alloc] init];
    _apiAddr[kHttpServerAddr_GetRoomList] = [self getApiAddr:kHttpServerAddr_GetRoomList];
    _apiAddr[kHttpServerAddr_GetPushUrl] = [self getApiAddr:kHttpServerAddr_GetPushUrl];
    _apiAddr[kHttpServerAddr_GetPushers] = [self getApiAddr:kHttpServerAddr_GetPushers];
    _apiAddr[kHttpServerAddr_CreateRoom] = [self getApiAddr:kHttpServerAddr_CreateRoom];
    _apiAddr[kHttpServerAddr_AddPusher] = [self getApiAddr:kHttpServerAddr_AddPusher];
    _apiAddr[kHttpServerAddr_DeletePusher] = [self getApiAddr:kHttpServerAddr_DeletePusher];
    _apiAddr[kHttpServerAddr_PusherHeartBeat] = [self getApiAddr:kHttpServerAddr_PusherHeartBeat];
    _apiAddr[kHttpServerAddr_GetIMLoginInfo] = [self getApiAddr:kHttpServerAddr_GetIMLoginInfo];
}

/**
   1. 初始化IM
   2. 登录IM
 */
- (void)init:(NSString*)serverDomain accountInfo:(SelfAccountInfo *)userInfo withCompletion:(IInitCompletionHandler)completion {
    [self asyncRun:^{
        // 保存到本地
        _serverDomain = serverDomain;
        _userInfo = userInfo;
        [self initApiAddr];
        
        // 初始化 RoomMsgMgr 并登录
        RoomMsgMgrConfig *config = [[RoomMsgMgrConfig alloc] init];
        config.userID = userInfo.userID;
        config.appID = userInfo.sdkAppID;
        config.accType = userInfo.accType;
        config.userSig = userInfo.userSig;
        config.userName = userInfo.userName;
        config.userAvatar = userInfo.userAvatar;
        
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
- (void)createRoom:(NSString *)roomName withCompletion:(ICreateRoomCompletionHandler)completion {
    [self asyncRun:^{
        _roomRole = 1;  // 房间角色为创建者
        _createRoomCompletion = completion;
        _roomName = roomName;
        
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
        _roomRole = 3;
        _roomID = roomID;
        
        [_msgMgr enterRoom:roomID completion:^(int errCode, NSString *errMsg) {
            [weakSelf asyncRun:^{
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"加入IMGroup完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
                if (errCode == 0) {
                    // 遍历房间列表
                    for (RoomInfo *roomInfo in _roomInfos) {
                        if ([roomInfo.roomID isEqualToString:roomID]) {
                            NSString *userID = roomInfo.roomCreator;
                            NSString *playUrl = roomInfo.mixedPlayURL;
                            
                            // 播放
                            TXLivePlayer *player = [_answerPlayerDic objectForKey:userID];
                            if (!player) {
                                player = [[TXLivePlayer alloc] init];
                                player.delegate = self;
                                
                                TXLivePlayConfig *config = [[TXLivePlayConfig alloc] init];
//                                config.bAutoAdjustCacheTime = NO;
                                config.maxAutoAdjustCacheTime = 1;
                                config.minAutoAdjustCacheTime = 1;
                                config.cacheTime = 1;
                                config.connectRetryCount = 3;
                                config.connectRetryInterval = 3;
                                config.enableAEC = NO;
                                config.enableMessage = YES;
                                
                                [player setConfig:config];
                                [_answerPlayerDic setObject:player forKey:userID];
                            }
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [player setupVideoWidget:CGRectZero containView:view insertIndex:0];
                                [player startPlay:playUrl type:PLAY_TYPE_LIVE_FLV];
                            });
                        
                            break;
                        }
                    }
                    
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
        
        if (_msgMgr) {
            [_msgMgr leaveRoom:_roomID completion:^(int errCode, NSString *errMsg) {
                NSLog(@"_msgMgr leaveRoom: errCode[%d] errMsg[%@]", errCode, errMsg);
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"离开IM Group完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
            }];
        }
        
        NSDictionary *param = @{@"roomID": _roomID, @"userID": _userInfo.userID};
        NSString *reqUrl = _apiAddr[kHttpServerAddr_DeletePusher];
        
        if (reqUrl) {
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
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 关闭本地采集和预览
            [self stopLocalPreview];
            
            // 关闭所有播放器
            for (id userID in _answerPlayerDic) {
                TXLivePlayer *player = [_answerPlayerDic objectForKey:userID];
                [player stopPlay];
            }
            [_answerPlayerDic removeAllObjects];
        });

        // 停止心跳
        [self stopHeartBeat];
        
        // 清除标记
        _created = NO;
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
                    [weakSelf asyncRun:^{
                        // 启动推流
                        _pushUrl = pushUrl;
                        [_answerPusher startPush:_pushUrl];
                    }];
                    
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
            
                NSString *roomName = responseObject[@"roomName"];
                _roomName = roomName;
                
                RoomInfo *roomInfo = [[RoomInfo alloc] init];
                roomInfo.roomID = _roomID;
                roomInfo.roomName = _roomName;
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
                    roomInfo.roomName = room[@"roomName"];
                    roomInfo.roomCreator = room[@"roomCreator"];
                    roomInfo.mixedPlayURL = room[@"mixedPlayURL"];
                    roomInfo.pusherInfoArray = [self parsePushersFromJsonArray:room[@"pushers"]];
                    
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

- (void)sendRoomTextMsg:(NSString *)textMsg {
    [self asyncRun:^{
        [_msgMgr sendRoomTextMsg:textMsg];
    }];
}

- (NSMutableArray<PusherInfo *> *)parsePushersFromJsonArray:(NSArray *)pushers {
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
    [_answerPusher startPreview:view];
}

- (void)stopLocalPreview {
    [_answerPusher stopPreview];
    [_answerPusher stopPush];
}

- (void)switchCamera {
    [_answerPusher switchCamera];
}

- (void)sendMessage:(NSString *)mesg {
    [_answerPusher sendMessage:[mesg dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)setMute:(BOOL)isMute {
    [_answerPusher setMute:isMute];
}

- (void)setHDAudio:(BOOL)isHD {
    TXLivePushConfig *config = _answerPusher.config;
    if (isHD && config.audioSampleRate != AUDIO_SAMPLE_RATE_48000) {
        config.audioSampleRate = AUDIO_SAMPLE_RATE_48000;
        [_answerPusher setConfig:config];
    }
    if (!isHD && config.audioSampleRate != AUDIO_SAMPLE_RATE_16000) {
        config.audioSampleRate = AUDIO_SAMPLE_RATE_16000;
        [_answerPusher setConfig:config];
    }
}

- (void)setVideoRatio:(RoomVideoRatio)ratio {
    // 根据不同的比例来设置最大且合适的分辨率，SDK内部的QOS模块会自动根据码率来降低其分辨率，但是分辨率比例不会改变
    if (ratio == ROOM_VIDEO_RATIO_3_4) {
        [self setVideoResolution:VIDEO_RESOLUTION_TYPE_360_480];
    }
    else if (ratio == ROOM_VIDEO_RATIO_9_16) {
        [self setVideoResolution:VIDEO_RESOLUTION_TYPE_360_640];
    }
    else if (ratio == ROOM_VIDEO_RATIO_1_1) {
        [self setVideoResolution:VIDEO_RESOLUTION_TYPE_480_480];
    }
}

- (void)setVideoResolution:(int)videoResolution {
    TXLivePushConfig *config = _answerPusher.config;
    if (config.videoResolution != videoResolution) {
        config.videoResolution = videoResolution;
        [_answerPusher setConfig:config];
    }
}

- (void)setBitrateRange:(int)minBitrate max:(int)maxBitrate {
    TXLivePushConfig *config = _answerPusher.config;
    if (config.videoBitrateMin != minBitrate || config.videoBitrateMax != maxBitrate) {
        config.videoBitrateMin = minBitrate;
        config.videoBitrateMax = maxBitrate;
        [_answerPusher setConfig:config];
    }
}

- (void)switchToBackground:(UIImage *)pauseImage {
    TXLivePushConfig *config = _answerPusher.config;
    if (!config.pauseImg || ![config.pauseImg isEqual:pauseImage]) {
        config.pauseImg = pauseImage;
        [_answerPusher setConfig:config];
    }
    [_answerPusher pausePush];
}

- (void)switchToForeground {
    [_answerPusher resumePush];
}

- (void)showVideoDebugLog:(BOOL)isShow {
    [_answerPusher showVideoDebugLog:isShow];
    
    [self asyncRun:^{
        for (id userID in _answerPlayerDic) {
            TXLivePlayer *player = [_answerPlayerDic objectForKey:userID];
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
    [_answerPusher setBeautyStyle:beautyStyle beautyLevel:beautyLevel whitenessLevel:whitenessLevel ruddinessLevel:ruddinessLevel];
}

- (void)setEyeScaleLevel:(float)eyeScaleLevel {
    [_answerPusher setEyeScaleLevel:eyeScaleLevel];
}

- (void)setFaceScaleLevel:(float)faceScaleLevel {
    [_answerPusher setFaceScaleLevel:faceScaleLevel];
}

- (void)setFaceVLevel:(float)faceVLevel {
    [_answerPusher setFaceVLevel:faceVLevel];
}

- (void)setChinLevel:(float)chinLevel {
    [_answerPusher setChinLevel:chinLevel];
}

- (void)setFaceShortLevel:(float)faceShortlevel {
    [_answerPusher setFaceShortLevel:faceShortlevel];
}

- (void)setNoseSlimLevel:(float)noseSlimLevel {
    [_answerPusher setNoseSlimLevel:noseSlimLevel];
}

- (void)setFilter:(UIImage *)image {
    [_answerPusher setFilter:image];
}

- (void)setSpecialRatio:(float)specialValue {
    [_answerPusher setSpecialRatio:specialValue];
}

- (void)setGreenScreenFile:(NSURL *)file {
    [_answerPusher setGreenScreenFile:file];
}

- (void)selectMotionTmpl:(NSString *)tmplName inDir:(NSString *)tmplDir {
    [_answerPusher selectMotionTmpl:tmplName inDir:tmplDir];
}

- (void) onPlayEvent:(int)EvtID withParam:(NSDictionary *)param {
    [self asyncRun:^{
        if (EvtID == PLAY_EVT_GET_MESSAGE) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([_delegate respondsToSelector:@selector(onPlayerMessage:)]) {
                    [_delegate onPlayerMessage:param[@"EVT_GET_MSG"]];
                }
            });
        }
    }];
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
                
                NSDictionary *params = @{@"userID": _userInfo.userID, @"roomName": _roomName, @"userName": _userInfo.userName,
                                         @"userAvatar": _userInfo.userAvatar, @"pushURL": _pushUrl};
                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"开始请求create_room"]];
                
                [_httpSession POST:_apiAddr[kHttpServerAddr_CreateRoom] parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    
                    [weakSelf asyncRun:^{
                        int errCode = [responseObject[@"code"] intValue];
                        NSString *errMsg = responseObject[@"message"];
                        NSString *roomID = responseObject[@"roomID"];
                        _roomID = roomID;
                        
                        [weakSelf sendDebugMsg:[NSString stringWithFormat:@"AppSvr回复create_room: errCode[%d] errMsg[%@] roomID[%@]", errCode, errMsg, roomID]];
                        
                        if (errCode == 0) {
                            [_msgMgr enterRoom:roomID completion:^(int errCode, NSString *errMsg) {
                                [weakSelf sendDebugMsg:[NSString stringWithFormat:@"加入IMGroup完成: errCode[%d] errMsg[%@]", errCode, errMsg]];
                                if (_createRoomCompletion) {
                                    _createRoomCompletion(errCode, errMsg);
                                    _createRoomCompletion = nil;
                                }
                            }];
                            
                            // 标记已经创建房间
                            _created = YES;
                            
                            // 启动心跳
                            [weakSelf startHeartBeat];
                            
                        } else {
                            if (_createRoomCompletion) {
                                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, [NSString stringWithFormat:@"%@[%d]", errMsg, errCode]);
                                _createRoomCompletion = nil;
                            }
                        }

                    }];
                    
                    
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    [weakSelf sendDebugMsg:[NSString stringWithFormat:@"请求create_room失败: error[%@]", [error description]]];
                    [weakSelf asyncRun:^{
                        if (_createRoomCompletion) {
                            _createRoomCompletion(ROOM_ERR_REQUEST_TIMEOUT, @"网络请求超时，请检查网络设置");
                            _createRoomCompletion = nil;
                        }
                    }];
                    
                }];
            }
            else if (_roomRole == 2) {  // 小主播
                
            }
            
        } else if (EvtID == PUSH_ERR_NET_DISCONNECT) {
            NSString *errMsg = @"推流断开，请检查网络设置";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;

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
                
            }
            
        } else if (EvtID == PUSH_ERR_OPEN_MIC_FAIL) {
            NSString *errMsg = @"获取麦克风权限失败，请前往隐私-麦克风设置里面打开应用权限";
            if (_createRoomCompletion) {
                _createRoomCompletion(ROOM_ERR_CREATE_ROOM, errMsg);
                _createRoomCompletion = nil;
                
            }
        }
    }];
}

-(void) onNetStatus:(NSDictionary*)param {
    
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
    [self onPusherChanged];
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
    /*
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
     */
}

- (void)sendDebugMsg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate) {
            [_delegate onDebugMsg:msg];
        }
    });
}

@end
