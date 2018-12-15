//
//  SuperPlayerViewConfig.m
//  SuperPlayer
//
//  Created by annidyfeng on 2018/10/18.
//

#import "SuperPlayerViewConfig.h"

@implementation SuperPlayerViewConfig

- (instancetype)init {
    self = [super init];
    self.hwAcceleration = 1;
    self.playRate = 1;
    self.renderMode = RENDER_MODE_FILL_EDGE;
    
    return self;
}

- (BOOL)hwAcceleration
{
#if TARGET_OS_SIMULATOR
    return NO;
#else
    return _hwAcceleration;
#endif
}


@end
