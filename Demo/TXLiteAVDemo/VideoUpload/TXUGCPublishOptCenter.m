//
//  TXUGCPublishOptCenter.m
//  TXLiteAVDemo
//
//  Created by carolsuo on 2018/8/24.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "TXUGCPublishOptCenter.h"
#import "TVCClientInner.h"
#import "AFNetworkReachabilityManager.h"

#define HTTPDNS_SERVER    @"http://119.29.29.29/d?dn="         // httpdns服务器


static TXUGCPublishOptCenter *_shareInstance = nil;

@implementation TXUGCPublishOptCenter

+ (instancetype)shareInstance
{
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        _shareInstance = [[TXUGCPublishOptCenter alloc] init];
    });
    return _shareInstance;
}

- (instancetype)init
{
    if (self = [super init])
    {
        _dnsCache = [[NSMutableDictionary alloc] init];
        _publishingList = [[NSMutableDictionary alloc] init];
        _isStarted = NO;
        _signature = @"";
    }
    return self;
}

- (void)prepareUpload:(NSString*)signature
{
    _signature = signature;
    if (!_isStarted) {
        _isStarted = YES;
        [self reFresh];
        [self monitorNetwork];
    }
}

//刷新httpdns
- (void) reFresh
{
    //清掉dns缓存
    [_dnsCache removeAllObjects];
    
    //使用了代理，不走httpdns
    if ([self useProxy]) {
        return;
    }
    NSString *baseUrl = [HTTPDNS_SERVER stringByAppendingString:UGC_HOST];
    
    // create request
    NSURL *url =[NSURL URLWithString:baseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSURLSessionConfiguration *initCfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    [initCfg setTimeoutIntervalForRequest:5];
    
    NSURLSession* session = [NSURLSession sessionWithConfiguration:initCfg delegate:nil delegateQueue:nil];
    __weak NSURLSession *wis = session;
    
    NSURLSessionTask *dnsTask = [session dataTaskWithRequest:request completionHandler:^(NSData *_Nullable initData, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        //invalid NSURLSession
        [wis invalidateAndCancel];
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if (error || httpResponse.statusCode != 200 || initData == nil) {
            return;
        }
        NSString* ips = [[NSString alloc]initWithData:initData encoding:NSUTF8StringEncoding];
        NSLog(@"httpdns resp: %@", ips);
        
        NSArray *ipLists = [ips componentsSeparatedByString:@";"];
        [_dnsCache setValue:ipLists forKey:UGC_HOST];
    }];
    [dnsTask resume];
}

//监控网络接入变化
-(void)monitorNetwork
{
    //网络切换的时候刷新一下httpdns
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusUnknown:
                NSLog(@"未知");
                break;
            case AFNetworkReachabilityStatusNotReachable:
                NSLog(@"没有网络");
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                NSLog(@"3G|4G");
                [self reFresh];
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                NSLog(@"WiFi");
                [self reFresh];
                break;
            default:
                break;
        }

    }];
}

//获取指定域名对应的ip
- (NSString*) query:(NSString *)hostname
{
    NSArray* ipLists = [_dnsCache objectForKey:hostname];
    if (ipLists != nil && ipLists.count > 0) {
        return ipLists[0];
    }
    return nil;
}

//是否使用了代理
- (BOOL) useProxy
{
    CFDictionaryRef dicRef = CFNetworkCopySystemProxySettings();
    const CFStringRef proxyCFstr = (const CFStringRef)CFDictionaryGetValue(dicRef, (const void*)kCFNetworkProxiesHTTPProxy);
    NSString* proxy = (__bridge NSString *)proxyCFstr;
    if (proxy != nil) {
        //使用了代理
        return YES;
    }
    //没有使用代理
    return NO;
}

//是否使用了httpdns
- (BOOL) useHttpDNS:(NSString *)hostname
{
    if ([self query:hostname] != nil) {
        return YES;
    }
    return NO;
}


- (void) addPublishing:(NSString *)videoPath
{
    [_publishingList setValue:[NSNumber numberWithBool:YES] forKey:videoPath];
}

- (void) delPublishing:(NSString *)videoPath
{
    [_publishingList removeObjectForKey:videoPath];
}

- (BOOL) isPublishingPublishing:(NSString *)videoPath
{
    return [[_publishingList objectForKey:videoPath] boolValue];
}

@end
