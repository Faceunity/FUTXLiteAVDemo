//
//  TXCVEFColorPalette.m
//  TXLiteAVDemo
//
//  Created by shengcui on 2018/5/7.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "TXCVEFColorPalette.h"
#import "ColorMacro.h"

UIColor * TXCVEFColorPaletteColorAtIndex(NSUInteger index) {
    NSCAssert([NSThread isMainThread], @"This class is designed to run on main thread.");
    NSUInteger preset[] = {0xEC5F9B, 0xEC8435, 0x1FBCB6, 0x449FF3, 0x6EA745};
    size_t size = sizeof(preset) / sizeof(preset[0]);
    if (index < size) {
        return UIColorFromRGB(preset[index]);
    }

    CGFloat hue = (index * 37) % 360 / 360.0;
    UIColor *color = [UIColor colorWithHue:hue saturation:0.4 +  0.04 * (index % 10) brightness:0.5 + 0.04 * (index%10) alpha:1];

//    CGFloat r,g,b;
//    [color getRed:&r green:&g blue:&b alpha:NULL];
//    NSLog(@"index: %d, color: #%X%X%X", (int)index,(int)(r*255),(int)(g*255),(int)(b*255));

    return color;
}

