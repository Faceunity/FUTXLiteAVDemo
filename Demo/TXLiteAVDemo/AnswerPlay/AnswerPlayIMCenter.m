//
//  AnswerPlayIMCenter.m
//  TXLiteAVDemo_Enterprise
//
//  Created by tomzhu on 2018/1/18.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "AnswerPlayIMCenter.h"

@interface AnswerPlayIMCenter() <TIMMessageListener, TIMUserStatusListener>

@property(nonatomic, strong) NSString *chatGroup; //聊天群组的ID
@property(nonatomic, strong) NSString *issueGroup; //问题群组的ID
@property(nonatomic, assign) BOOL isInit;

@end

@implementation AnswerPlayIMCenter

+ (instancetype)getInstance
{
    static AnswerPlayIMCenter *gInstance;
    if (gInstance == nil) {
        gInstance = [[AnswerPlayIMCenter alloc] init];
    }
    return gInstance;
}

- (void)initIMCenter:(int)sdkAppId accountType:(NSString *)accountType
{
    if (self.isInit) {
        return;
    }
    self.isInit = YES;
    
    // 1.初始化SDK
    TIMSdkConfig *sdkCfg = [[TIMSdkConfig alloc] init];
    sdkCfg.sdkAppId = sdkAppId;
    sdkCfg.accountType = accountType;
    
    [[TIMManager sharedInstance] initSdk:sdkCfg];
    
    // 2.初始化用户配置信息
    TIMUserConfig *userCfg = [[TIMUserConfig alloc] init];
    userCfg.userStatusListener = self;
    [[TIMManager sharedInstance] setUserConfig:userCfg];
    
    // 3.添加消息监听器
    [[TIMManager sharedInstance] addMessageListener:self];
}

- (void)loginIMUser:(TIMLoginParam *)loginParam succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if ([loginParam.identifier isEqualToString:[[TIMManager sharedInstance] getLoginUser]]) { //用户已登录，直接返回成功
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succ) {
                succ();
            }
        });
        return;
    }
    
    //1. 清空群组信息缓存
    self.chatGroup = nil;
    self.issueGroup = nil;
    
    //2. 登录用户
    [[TIMManager sharedInstance] login:loginParam succ:succ fail:fail];
}

- (void)logout
{
    //1. 清空群组信息缓存
    self.chatGroup = nil;
    self.issueGroup = nil;
    
    //2. 登出用户
    [[TIMManager sharedInstance] logout:nil fail:nil];
}

- (void)sendChatMessage:(NSString *)message succ:(TIMSucc)succ fail:(TIMFail)fail
{
    //1. 聊天群组不存在，返回失败
    if (self.chatGroup == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (fail) {
                fail(1, @"用户未加入聊天群组");
            }
        });
        return;
    }
    
    //2. 构建文本消息
    TIMMessage *msg = [[TIMMessage alloc] init];
    TIMTextElem *textElem = [[TIMTextElem alloc] init];
    textElem.text = message;
    [msg addElem:textElem];
    
    //3. 发送文本消息
    TIMConversation *sess = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:self.chatGroup];
    [sess sendMessage:msg succ:succ fail:fail];
}

- (void)joinIMGroup:(NSString *)chatGroup issueGroup:(NSString *)issueGroup succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if ([chatGroup isEqualToString:self.chatGroup]
        && [issueGroup isEqualToString:self.issueGroup]) { //如果已加入群组，则返回成功
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succ) {
                succ();
            }
        });
        return;
    }
    
    // 1.如果已加入其他群组，则先退出群组
    [self quitGroup];
    
    // 2.加入聊天群组
    __weak AnswerPlayIMCenter *wself = self;
    [self joinChatGroup:chatGroup succ:^{
        wself.chatGroup = chatGroup;
        // 3.加入问题群组
        [wself joinIssueGroup:issueGroup succ:^{
            wself.issueGroup = issueGroup;
            succ();
        } fail:^(int code, NSString *msg) {
            [wself quitGroup];
            fail(code, msg);
        }];
    } fail:^(int code, NSString *msg) {
        [wself quitGroup];
        fail(code, msg);
    }];
}

- (void)joinChatGroup:(NSString *)groupId succ:(TIMSucc)succ fail:(TIMFail)fail
{
    [[TIMGroupManager sharedInstance] joinGroup:groupId msg:@"" succ:succ fail:fail];
}

- (void)joinIssueGroup:(NSString *)groupId succ:(TIMSucc)succ fail:(TIMFail)fail
{
    [[TIMGroupManager sharedInstance] joinGroup:groupId msg:@"" succ:succ fail:fail];
}

- (void)quitGroup
{
    if (self.chatGroup) {
        [[TIMGroupManager sharedInstance] quitGroup:self.chatGroup succ:nil fail:nil];
        self.chatGroup = nil;
    }
    if (self.issueGroup) {
        [[TIMGroupManager sharedInstance] quitGroup:self.issueGroup succ:nil fail:nil];
        self.issueGroup = nil;
    }
}

- (void)onNewMessage:(NSArray *)msgs
{
    for (TIMMessage *msg in msgs) {
        NSString *groupId = [[msg getConversation] getReceiver];
        if ([[msg getConversation] getType] == TIM_GROUP && [groupId isEqualToString:self.chatGroup]) {
            if ([msg elemCount] == 1 && [[msg getElem:0] isKindOfClass:[TIMTextElem class]]) {
                TIMTextElem *textElem = (TIMTextElem *)[msg getElem:0];
                [self.delegate onRecvChatMessage:textElem.text fromUser:msg.sender];
            }
        }
        else if ([[msg getConversation] getType] == TIM_GROUP && [groupId isEqualToString:self.issueGroup]) {
            if ([msg elemCount] == 1 && [[msg getElem:0] isKindOfClass:[TIMCustomElem class]]) {
                TIMCustomElem *customElem = (TIMCustomElem *)[msg getElem:0];
                [self.delegate onRecvIssueMessage:customElem.data];
            }
        }
        else if ([[msg getConversation] getType] == TIM_SYSTEM && [[msg getElem:0] isKindOfClass:[TIMGroupSystemElem class]]) {
            TIMGroupSystemElem *systemElem = (TIMGroupSystemElem *)[msg getElem:0];
            if (systemElem.type == TIM_GROUP_SYSTEM_DELETE_GROUP_TYPE) {
                [self.delegate onIMGroupDelete:systemElem.group];
                if ([self.chatGroup isEqualToString:systemElem.group]) {
                    self.chatGroup = nil;
                }
                else if ([self.issueGroup isEqualToString:systemElem.group]) {
                    self.issueGroup = nil;
                }
            }
        }
    }
}

- (void)onForceOffline
{
    [self.delegate onForceOffline];
}

- (void)onUserSigExpired
{
    [self.delegate onUserSigExpired];
}

- (void)onReConnFailed:(int)code err:(NSString *)err
{
    [self.delegate onReConnFailed:code err:err];
}



@end
