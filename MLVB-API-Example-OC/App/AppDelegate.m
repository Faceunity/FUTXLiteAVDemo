//
//  AppDelegate.m
//  TRTCSimpleDemo-OC
//
//  Created by dangjiahe on 2021/4/10.
//  Copyright (c) 2021 Tencent. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()<V2TXLivePremierObserver>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [V2TXLivePremier setLicence:LICENSEURL key:LICENSEURLKEY];
    [V2TXLivePremier setObserver:self];
    NSLog(@"SDK Version = %@", [V2TXLivePremier getSDKVersionStr]);

    return YES;
}

#pragma mark - V2TXLivePremierObserver
- (void)onLicenceLoaded:(int)result Reason:(NSString *)reason {
    NSLog(@"onLicenceLoaded: result:%d reason:%@", result, reason);
}


@end
