//
//  TXUGCPublishOptCenter.h
//  TXLiteAVDemo
//
//  Created by carolsuo on 2018/8/24.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TXUGCPublishOptCenter : NSObject

+ (instancetype)shareInstance;
@property (atomic, assign)  BOOL isStarted;
@property(nonatomic,strong) NSString * signature;
@property (strong, nonatomic) NSMutableDictionary *dnsCache;
@property (strong, nonatomic) NSMutableDictionary *publishingList;

- (void) prepareUpload:(NSString *)signature;
- (NSString*) query:(NSString *)hostname;
- (BOOL) useProxy;
- (BOOL) useHttpDNS:(NSString *)hostname;
- (void) addPublishing:(NSString *)videoPath;
- (void) delPublishing:(NSString *)videoPath;
- (BOOL) isPublishingPublishing:(NSString *)videoPath;

@end
