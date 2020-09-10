//
//  SPPlayCGIParseResult.m
//  SuperPlayer
//
//  Created by cui on 2019/12/25.
//  Copyright © 2019 annidy. All rights reserved.
//

#import "SPPlayCGIParseResult.h"
#import "TXImageSprite.h"

@implementation SPPlayCGIParseResult
+ (SPDrmType)drmTypeFromString:(NSString *)typeString {
    if ([typeString isEqualToString: @"SimpleAES"]) {
        return SPDrmTypeSimpleAES;
    }
    return SPDrmTypeNone;
}
@end
