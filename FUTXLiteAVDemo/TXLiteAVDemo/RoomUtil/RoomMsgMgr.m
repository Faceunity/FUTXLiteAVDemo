//
//  RoomMsgMgr.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/1.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RoomMsgMgr.h"
#import "ImSDK/ImSDK.h"

#define CMD_PUSHER_CHANGE      @"notifyPusherChange"
#define CMD_CUSTOM_TEXT_MSG    @"CustomTextMsg"
#define CMD_CUSTOM_CMD_MSG     @"CustomCmdMsg"
#define CMD_LINK_MIC           @"linkmic"
#define CMD_PK                 @"pk"

@implementation RoomMsgMgrConfig
@end


@interface RoomMsgMgr() <TIMMessageListener> {
    RoomMsgMgrConfig     *_config;
    dispatch_queue_t     _queue;
    
    NSString             *_groupID;           // 群ID
    TIMConversation      *_roomConversation;  // 群会话上下文
}

@property (nonatomic, assign) BOOL     isOwner;  // 是否是群主
@property (nonatomic, copy) NSString   *ownerGroupID;

@end

@implementation RoomMsgMgr

- (instancetype)initWithConfig:(RoomMsgMgrConfig *)config {
    if (self = [super init]) {
        _config = config;
        _queue = dispatch_queue_create("RoomMsgMgrQueue", DISPATCH_QUEUE_SERIAL);
        
        TIMSdkConfig *sdkConfig = [[TIMSdkConfig alloc] init];
        sdkConfig.sdkAppId = config.appID;
        sdkConfig.accountType = config.accType;
        
        [[TIMManager sharedInstance] initSdk:sdkConfig];
        [[TIMManager sharedInstance] addMessageListener:self];
        
        _groupID = @"0";
        _isOwner = NO;
    }
    return self;
}

- (void)dealloc {
    [[TIMManager sharedInstance] removeMessageListener:self];
}

typedef void (^block)();
- (void)asyncRun:(block)block {
    dispatch_async(_queue, ^{
        block();
    });
}

- (void)syncRun:(block)block {
    dispatch_sync(_queue, ^{
        block();
    });
}

- (void)switchRoom:(NSString *)groupID {
    _groupID = groupID;
    _roomConversation = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:groupID];
}

- (void)login:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        TIMLoginParam *param = [[TIMLoginParam alloc] init];
        param.identifier = _config.userID;
        param.userSig = _config.userSig;
        param.appidAt3rd = [NSString stringWithFormat:@"%d", _config.appID];
        
        [[TIMManager sharedInstance] login:param succ:^{
            if (completion) {
                completion(0, nil);
            }
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)logout:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        [[TIMManager sharedInstance] logout:^{
            if (completion) {
                completion(0, nil);
            }
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)createRoom:(NSString *)groupID groupName:(NSString *)groupName completion:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        [[TIMGroupManager sharedInstance] createGroup:@"AVChatRoom" groupId:groupID groupName:groupName succ:^(NSString *groupId) {
            weakSelf.isOwner = YES;
            weakSelf.ownerGroupID = groupID;
            
            if (completion) {
                completion(0, nil);
            }
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)enterRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        [[TIMGroupManager sharedInstance] joinGroup:groupID msg:nil succ:^{
            //切换群会话的上下文环境
            [weakSelf switchRoom:groupID];
            
            if (completion) {
                completion(0, nil);
            }
            
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)leaveRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        // 如果是群主，那么就解散该群，如果不是群主，那就退出该群
        if (_isOwner && [_ownerGroupID isEqualToString:groupID]) {
            [[TIMGroupManager sharedInstance] deleteGroup:groupID succ:^{
                if (completion) {
                    completion(0, nil);
                }
            } fail:^(int code, NSString *msg) {
                if (completion) {
                    completion(code, msg);
                }
            }];
            
        } else {
            [[TIMGroupManager sharedInstance] quitGroup:groupID succ:^{
                if (completion) {
                    completion(0, nil);
                }
            } fail:^(int code, NSString *msg) {
                if (completion) {
                    completion(code, msg);
                }
            }];
        }
    }];
}

// CustomElem{"cmd":"CustomCmdMsg", "data":{"userName":"xxx", "userAvatar":"xxx", "cmd":"xx", msg:"xx"}}
- (void)sendRoomCustomMsg:(NSString *)cmd msg:(NSString *)msg {
    [self asyncRun:^{
        TIMCustomElem *elem = [[TIMCustomElem alloc] init];
        NSDictionary *data = @{@"cmd": cmd, @"msg": msg == nil ? @"" : msg};
        NSDictionary *customMsg = @{@"userName":_config.userName, @"userAvatar":_config.userAvatar, @"cmd": CMD_CUSTOM_CMD_MSG, @"data": data};
        [elem setData:[self dictionary2JsonData:customMsg]];
        
        TIMMessage *msg = [[TIMMessage alloc] init];
        [msg addElem:elem];
        
        if (_roomConversation) {
            [_roomConversation sendMessage:msg succ:^{
                NSLog(@"sendCustomMessage success");
            } fail:^(int code, NSString *msg) {
                NSLog(@"sendCustomMessage failed, data[%@]", data);
            }];
        }
    }];
}

- (void)sendCCCustomMessage:(NSString *)userID data:(NSData *)data {
    TIMCustomElem *elem = [[TIMCustomElem alloc] init];
    [elem setData:data];
    
    TIMMessage *msg = [[TIMMessage alloc] init];
    [msg addElem:elem];
    
    TIMConversation *conversation = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:userID];
    if (conversation) {
        [conversation sendMessage:msg succ:^{
            NSLog(@"sendCCCustomMessage success");
        } fail:^(int code, NSString *msg) {
            NSLog(@"sendCCCustomMessage failed, data[%@]", data);
        }];
    }
}

// 一条消息两个Elem：CustomElem{“cmd”:”CustomTextMsg”, “data”:{nickName:“xx”, headPic:”xx”}} + TextElem
- (void)sendRoomTextMsg:(NSString *)textMsg {
    [self asyncRun:^{
        TIMCustomElem *msgHead = [[TIMCustomElem alloc] init];
        NSDictionary *userInfo = @{@"nickName": _config.userName, @"headPic": _config.userAvatar};
        NSDictionary *headData = @{@"cmd": CMD_CUSTOM_TEXT_MSG, @"data": userInfo};
        msgHead.data = [self dictionary2JsonData:headData];
        
        TIMTextElem *msgBody = [[TIMTextElem alloc] init];
        msgBody.text = textMsg;
        
        TIMMessage *msg = [[TIMMessage alloc] init];
        [msg addElem:msgHead];
        [msg addElem:msgBody];
        
        if (_roomConversation) {
            [_roomConversation sendMessage:msg succ:^{
                NSLog(@"sendRoomTextMsg success");
            } fail:^(int code, NSString *msg) {
                NSLog(@"sendRoomTextMsg failed, textMsg[%@]", textMsg);
            }];
        }
    }];
}

// 向userID发起连麦请求
// {cmd:"linkmic", data:{type: “request”, roomID:”xxx”, userID:"xxxx", userName:"xxxx", userAvatar:"xxxx"}}
- (void)sendLinkMicRequest:(NSString *)userID {
    [self asyncRun:^{
        NSDictionary *data = @{@"type": @"request", @"roomID":_groupID, @"userID":_config.userID, @"userName":_config.userName, @"userAvatar":_config.userAvatar};
        NSDictionary *msgDic = @{@"cmd": CMD_LINK_MIC, @"data":data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

// 向userID发起连麦响应，result为："accept“ or "reject"
// {cmd:"linkmic", data:{type: “response”, roomID:”xxx”, result: "xxxx"，message:"xxxx }}
- (void)sendLinkMicResponse:(NSString *)userID withResult:(BOOL)result andReason:(NSString *)reason {
    [self asyncRun:^{
        NSString *resultStr = @"reject";
        if (result) {
            resultStr = @"accept";
        }
        NSDictionary *data = @{@"type": @"response", @"roomID":_groupID, @"result":resultStr, @"message":reason};
        NSDictionary *msgDic = @{@"cmd": CMD_LINK_MIC, @"data":data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

// 群主向userID发出踢出连麦消息
// {cmd:"linkmic", data:{type: "kickout”, roomID:”xxx”}}
- (void)sendLinkMicKickout:(NSString *)userID {
    [self asyncRun:^{
        NSDictionary *data = @{@"type": @"kickout", @"roomID":_groupID};
        NSDictionary *msgDic = @{@"cmd": CMD_LINK_MIC, @"data":data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

// 向userID发起PK请求
// {"cmd":"pk", "data":{"roomID":"XXX", "type":"request", "action":"start", "userID":"XXX", "userName":"XXX", "userAvatar":"XXX", "accelerateURL":"XXX"} }
- (void)sendPKRequest:(NSString *)userID withAccelerateURL:(NSString *)accelerateURL {
    [self asyncRun:^{
        NSDictionary *data = @{@"roomID":_groupID, @"type": @"request", @"action": @"start", @"userID": _config.userID,
                               @"userName": _config.userName, @"userAvatar": _config.userAvatar, @"accelerateURL": accelerateURL};
        NSDictionary *msgDic = @{@"cmd": CMD_PK, @"data": data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

// 请求结束PK
// {"cmd":"pk", "data":{"roomID":"XXX", "type":"request", "action":"stop", "userID":"XXX", "userName":"XXX", "userAvatar":"XXX"} }
- (void)sendPKFinishRequest:(NSString *)userID {
    [self asyncRun:^{
        NSDictionary *data = @{@"roomID":_groupID, @"type": @"request", @"action": @"stop", @"userID": _config.userID,
                               @"userName": _config.userName, @"userAvatar": _config.userAvatar};
        NSDictionary *msgDic = @{@"cmd": CMD_PK, @"data": data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

// 接收PK
// {"cmd":"pk", "data":{"roomID":"XXX", "type":"response", "result":"accept",  "message":"" , "accelerateURL":"XXX"} }
- (void)acceptPKRequest:(NSString *)userID withAccelerateURL:(NSString *)accelerateURL {
    [self asyncRun:^{
        NSDictionary *data = @{@"roomID":_groupID, @"type": @"response", @"result": @"accept", @"message": @"", @"accelerateURL": accelerateURL};
        NSDictionary *msgDic = @{@"cmd": CMD_PK, @"data": data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

// 拒绝PK
// {"cmd":"pk", "data":{"roomID":"XXX",  "type":"response", "result":"reject",  "message":"" } }
- (void)rejectPKRequest:(NSString *)userID reason:(NSString *)reason {
    [self asyncRun:^{
        NSDictionary *data = @{@"roomID":_groupID, @"type": @"response", @"result": @"reject", @"message": reason};
        NSDictionary *msgDic = @{@"cmd": CMD_PK, @"data": data};
        
        [self sendCCCustomMessage:userID data:[self dictionary2JsonData:msgDic]];
    }];
}

#pragma mark - TIMMessageListener

- (void)onNewMessage:(NSArray*)msgs {
    [self asyncRun:^{
        for (TIMMessage *msg in msgs) {
            TIMConversationType type = msg.getConversation.getType;
            switch (type) {
                case TIM_C2C:
                    [self onRecvC2CMsg:msg];
                    break;
                    
                case TIM_SYSTEM:
                    [self onRecvSystemMsg:msg];
                    break;
                    
                case TIM_GROUP:
                    // 目前只处理当前群消息
                    if ([[msg.getConversation getReceiver] isEqualToString:_groupID]) {
                        [self onRecvGroupMsg:msg];
                    }
                    break;
                    
                default:
                    break;
            }
        }
    }];
}

- (void)onRecvC2CMsg:(TIMMessage *)msg {
    for (int idx = 0; idx < [msg elemCount]; ++idx) {
        TIMElem *elem = [msg getElem:idx];
        
        if ([elem isKindOfClass:[TIMCustomElem class]]) {
            TIMCustomElem *customElem = (TIMCustomElem *)elem;
            NSDictionary *dict = [self jsonData2Dictionary:customElem.data];
            
            NSString *cmd = nil;
            id data = nil;
            if (dict) {
                cmd = dict[@"cmd"];
                data = dict[@"data"];
            }
            
            // 连麦相关的消息
            if (cmd && [cmd isEqualToString:CMD_LINK_MIC] && [data isKindOfClass:[NSDictionary class]]) {
                NSString *type = data[@"type"];
                if (type && [type isEqualToString:@"request"]) {
                    if (_delegate && [_delegate respondsToSelector:@selector(onRecvLinkMicRequest:userID:userName:userAvatar:)]) {
                        [_delegate onRecvLinkMicRequest:_groupID userID:msg.sender userName:data[@"userName"] userAvatar:data[@"userAvatar"]];
                    }
                    
                } else if (type && [type isEqualToString:@"response"]) {
                    NSString *resultStr = data[@"result"];
                    NSString *message = data[@"message"];
                    BOOL result = NO;
                    if (resultStr && [resultStr isEqualToString:@"accept"]) {
                        result = YES;
                    }
                    if (_delegate && [_delegate respondsToSelector:@selector(onRecvLinkMicResponse:result:message:)]) {
                        [_delegate onRecvLinkMicResponse:_groupID result:result message:message];
                    }
                    
                } else if (type && [type isEqualToString:@"kickout"]) {
                    if (_delegate && [_delegate respondsToSelector:@selector(onRecvLinkMicKickout:)]) {
                        [_delegate onRecvLinkMicKickout:_groupID];
                    }
                }
            }
            // 跨房主播PK相关的消息
            else if (cmd && [cmd isEqualToString:CMD_PK] && [data isKindOfClass:[NSDictionary class]]) {
                NSString *type = data[@"type"];
                if (type && [type isEqualToString:@"request"]) {
                    NSString *action = data[@"action"];
                    if (action && [action isEqualToString:@"start"]) {  // 收到PK请求的消息
                        if (_delegate && [_delegate respondsToSelector:@selector(onRecvPKRequest:userID:userName:userAvatar:streamUrl:)]) {
                            [_delegate onRecvPKRequest:data[@"roomID"] userID:msg.sender userName:data[@"userName"] userAvatar:data[@"userAvatar"] streamUrl:data[@"accelerateURL"]];
                        }
                    
                    } else if (action && [action isEqualToString:@"stop"]) { // 收到PK结束的消息
                        if (_delegate && [_delegate respondsToSelector:@selector(onRecvPKFinishRequest:userID:)]) {
                            [_delegate onRecvPKFinishRequest:data[@"roomID"] userID:msg.sender];
                        }
                    }
                    
                } else if (type && [type isEqualToString:@"response"]) {
                    NSString *result = data[@"result"];
                    if (result && [result isEqualToString:@"accept"]) {  // 收到接收PK的消息
                        if (_delegate && [_delegate respondsToSelector:@selector(onRecvPKResponse:userID:result:message:streamUrl:)]) {
                            [_delegate onRecvPKResponse:data[@"roomID"] userID:msg.sender result:YES message:@"" streamUrl:data[@"accelerateURL"]];
                        }
                        
                    } else if (result && [result isEqualToString:@"reject"]) {  // 收到拒绝PK的消息
                        if (_delegate && [_delegate respondsToSelector:@selector(onRecvPKResponse:userID:result:message:streamUrl:)]) {
                            [_delegate onRecvPKResponse:data[@"roomID"] userID:msg.sender result:NO message:data[@"message"] streamUrl:nil];
                        }
                    }
                }
            }
            
        }
    }
}

- (void)onRecvSystemMsg:(TIMMessage *)msg {
    for (int idx = 0; idx < [msg elemCount]; ++idx) {
        TIMElem *elem = [msg getElem:idx];
        
        if ([elem isKindOfClass:[TIMGroupSystemElem class]]) {
            TIMGroupSystemElem *sysElem = (TIMGroupSystemElem *)elem;
            if ([sysElem.group isEqualToString:_groupID]) {
                if (sysElem.type == TIM_GROUP_SYSTEM_DELETE_GROUP_TYPE) {  // 群被解散
                    if (_delegate) {
                        [_delegate onGroupDelete:_groupID];
                    }
                }
                else if (sysElem.type == TIM_GROUP_SYSTEM_CUSTOM_INFO) {  // 用户自定义通知(默认全员接收)
                    NSDictionary *dict = [self jsonData2Dictionary:sysElem.userData];
                    if (dict == nil) {
                        break;
                    }
                    
                    NSString *cmd = dict[@"cmd"];
                    if (cmd == nil) {
                        break;
                    }
                    
                    // 群成员有变化
                    if ([cmd isEqualToString:CMD_PUSHER_CHANGE]) {
                        if (_delegate) {
                            [_delegate onMemberChange:_groupID];
                        }
                    }
                }
            }
        }
    }
}

- (void)onRecvGroupMsg:(TIMMessage *)msg {
    NSString *cmd = nil;
    id data = nil;
    
    for (int idx = 0; idx < [msg elemCount]; ++idx) {
        TIMElem *elem = [msg getElem:idx];
        
        if ([elem isKindOfClass:[TIMCustomElem class]]) {
            TIMCustomElem *customElem = (TIMCustomElem *)elem;
            NSDictionary *dict = [self jsonData2Dictionary:customElem.data];
            if (dict) {
                cmd = dict[@"cmd"];
                data = dict[@"data"];
            }
            
            // 群自定义消息处理
            if (cmd && [cmd isEqualToString:CMD_CUSTOM_CMD_MSG] && [data isKindOfClass:[NSDictionary class]]) {
                if (_delegate && [_delegate respondsToSelector:@selector(onRecvGroupCustomMsg:userID:cmd:msg:userName:userAvatar:)]) {
                    [_delegate onRecvGroupCustomMsg:_groupID userID:msg.sender cmd:data[@"cmd"] msg:data[@"msg"] userName:data[@"userName"] userAvatar:data[@"userAvatar"]];
                }
            }
        }
        
        if ([elem isKindOfClass:[TIMTextElem class]]) {
            TIMTextElem *textElem = (TIMTextElem *)elem;
            NSString *msgText = textElem.text;
            
            // 群文本消息处理
            if (cmd && [cmd isEqualToString:CMD_CUSTOM_TEXT_MSG] && [data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *userInfo = (NSDictionary *)data;
                NSString *nickName = nil;
                NSString *headPic = nil;
                if (userInfo) {
                    nickName = userInfo[@"nickName"];
                    headPic = userInfo[@"headPic"];
                }
                
                if (_delegate) {
                    [_delegate onRecvGroupTextMsg:_groupID userID:msg.sender textMsg:msgText userName:nickName userAvatar:headPic];
                }
               
            }
        }
    }
}


#pragma mark - utils

- (NSData *)dictionary2JsonData:(NSDictionary *)dict {
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if (error) {
            NSLog(@"dictionary2JsonData failed: %@", dict);
            return nil;
        }
        return data;
    }
    return nil;
}

- (NSDictionary *)jsonData2Dictionary:(NSData *)jsonData {
    if (jsonData == nil) {
        return nil;
    }
    NSError *err = nil;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
    if (err) {
        NSLog(@"JjsonData2Dictionary failed: %@", jsonData);
        return nil;
    }
    return dic;
}

@end
