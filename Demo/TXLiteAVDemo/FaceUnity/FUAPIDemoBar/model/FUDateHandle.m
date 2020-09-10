//
//  FUDateHandle.m
//  FULiveDemo
//
//  Created by 孙慕 on 2020/6/20.
//  Copyright © 2020 FaceUnity. All rights reserved.
//

#import "FUDateHandle.h"
#import "FUBeautyParam.h"
#import "YYModel.h"
#import "FUPosition.h"

@implementation FUDateHandle

/// 美肤
+ (NSArray<FUBeautyParam *> *)setupSkinData{

    NSArray *prams = @[@"blur_level",@"color_level",@"red_level",@"sharpen",@"eye_bright",@"tooth_whiten",@"remove_pouch_strength",@"remove_nasolabial_folds_strength"];//
    NSDictionary *titelDic = @{@"blur_level":@"精细磨皮",@"color_level":@"美白",@"red_level":@"红润",@"sharpen":@"锐化",@"remove_pouch_strength":@"去黑眼圈",@"remove_nasolabial_folds_strength":@"去法令纹",@"eye_bright":@"亮眼",@"tooth_whiten":@"美牙"};
    NSDictionary *defaultValueDic = @{@"blur_level":@(0.7),@"color_level":@(0.3),@"red_level":@(0.3),@"sharpen":@(0.2),@"remove_pouch_strength":@(0),@"remove_nasolabial_folds_strength":@(0),@"eye_bright":@(0),@"tooth_whiten":@(0)};

    NSMutableArray *tempM = [NSMutableArray array];
    for (NSString *str in prams) {

        FUBeautyParam *modle = [[FUBeautyParam alloc] init];
        modle.mParam = str;
        modle.mTitle = [titelDic valueForKey:str];
        modle.mValue = [[defaultValueDic valueForKey:str] floatValue];
        modle.defaultValue = modle.mValue;
        modle.type = FUDataTypeBeautify;
        [tempM addObject:modle];
        
    }

    return tempM.copy;
    
}

/// 美型
+ (NSArray<FUBeautyParam *> *)setupShapData{

    NSArray *prams = @[@"cheek_thinning",@"cheek_v",@"cheek_narrow",@"cheek_small",@"eye_enlarging",@"intensity_chin",@"intensity_forehead",@"intensity_nose",@"intensity_mouth",@"intensity_canthus",@"intensity_eye_space",@"intensity_eye_rotate",@"intensity_long_nose",@"intensity_philtrum",@"intensity_smile"];
    NSDictionary *titelDic = @{@"cheek_thinning":@"瘦脸",@"cheek_v":@"v脸",@"cheek_narrow":@"窄脸",@"cheek_small":@"小脸",@"eye_enlarging":@"大眼",@"intensity_chin":@"下巴",
                               @"intensity_forehead":@"额头",@"intensity_nose":@"瘦鼻",@"intensity_mouth":@"嘴型",@"intensity_canthus":@"开眼角",@"intensity_eye_space":@"眼距",@"intensity_eye_rotate":@"眼睛角度",@"intensity_long_nose":@"长鼻",@"intensity_philtrum":@"缩人中",@"intensity_smile":@"微笑嘴角"
    };
   NSDictionary *defaultValueDic = @{@"cheek_thinning":@(0),@"cheek_v":@(0.5),@"cheek_narrow":@(0),@"cheek_small":@(0),@"eye_enlarging":@(0.4),@"intensity_chin":@(0.3),
                              @"intensity_forehead":@(0.3),@"intensity_nose":@(0.5),@"intensity_mouth":@(0.4),@"intensity_canthus":@(0),@"intensity_eye_space":@(0.5),@"intensity_eye_rotate":@(0.5),@"intensity_long_nose":@(0.5),@"intensity_philtrum":@(0.5),@"intensity_smile":@(0)
   };

    NSMutableArray *tempM = [NSMutableArray array];
    for (NSString *str in prams) {
        BOOL isStyle101 = NO;
        if ([str isEqualToString:@"intensity_chin"] || [str isEqualToString:@"intensity_forehead"] || [str isEqualToString:@"intensity_mouth"] || [str isEqualToString:@"intensity_eye_space"] || [str isEqualToString:@"intensity_eye_rotate"] || [str isEqualToString:@"intensity_long_nose"] || [str isEqualToString:@"intensity_philtrum"]) {
            isStyle101 = YES;
        }
       
        FUBeautyParam *modle = [[FUBeautyParam alloc] init];
        modle.mParam = str;
        modle.mTitle = [titelDic valueForKey:str];
        modle.mValue = [[defaultValueDic valueForKey:str] floatValue];
        modle.defaultValue = modle.mValue;
        modle.iSStyle101 = isStyle101;
        modle.type = FUDataTypeBeautify;
        [tempM addObject:modle];
    }
    
    return tempM.copy;
    
}

/// 滤镜
+ (NSArray<FUBeautyParam *> *)setupFilterData{
    
    NSArray *beautyFiltersDataSource = @[@"origin",@"ziran1",@"ziran2",@"ziran3",@"ziran4",@"ziran5",@"ziran6",@"ziran7",@"ziran8",
    @"zhiganhui1",@"zhiganhui2",@"zhiganhui3",@"zhiganhui4",@"zhiganhui5",@"zhiganhui6",@"zhiganhui7",@"zhiganhui8",
                                          @"mitao1",@"mitao2",@"mitao3",@"mitao4",@"mitao5",@"mitao6",@"mitao7",@"mitao8",
                                         @"bailiang1",@"bailiang2",@"bailiang3",@"bailiang4",@"bailiang5",@"bailiang6",@"bailiang7"
                                         ,@"fennen1",@"fennen2",@"fennen3",@"fennen5",@"fennen6",@"fennen7",@"fennen8",
                                         @"lengsediao1",@"lengsediao2",@"lengsediao3",@"lengsediao4",@"lengsediao7",@"lengsediao8",@"lengsediao11",
                                         @"nuansediao1",@"nuansediao2",
                                         @"gexing1",@"gexing2",@"gexing3",@"gexing4",@"gexing5",@"gexing7",@"gexing10",@"gexing11",
                                         @"xiaoqingxin1",@"xiaoqingxin3",@"xiaoqingxin4",@"xiaoqingxin6",
                                         @"heibai1",@"heibai2",@"heibai3",@"heibai4"];
    
    NSDictionary *filtersCHName = @{@"origin":@"原图",@"bailiang1":@"白亮1",@"bailiang2":@"白亮2",@"bailiang3":@"白亮3",@"bailiang4":@"白亮4",@"bailiang5":@"白亮5",@"bailiang6":@"白亮6",@"bailiang7":@"白亮7"
                                    ,@"fennen1":@"粉嫩1",@"fennen2":@"粉嫩2",@"fennen3":@"粉嫩3",@"fennen4":@"粉嫩4",@"fennen5":@"粉嫩5",@"fennen6":@"粉嫩6",@"fennen7":@"粉嫩7",@"fennen8":@"粉嫩8",
                                    @"gexing1":@"个性1",@"gexing2":@"个性2",@"gexing3":@"个性3",@"gexing4":@"个性4",@"gexing5":@"个性5",@"gexing6":@"个性6",@"gexing7":@"个性7",@"gexing8":@"个性8",@"gexing9":@"个性9",@"gexing10":@"个性10",@"gexing11":@"个性11",
                                    @"heibai1":@"黑白1",@"heibai2":@"黑白2",@"heibai3":@"黑白3",@"heibai4":@"黑白4",@"heibai5":@"黑白5",
                                    @"lengsediao1":@"冷色调1",@"lengsediao2":@"冷色调2",@"lengsediao3":@"冷色调3",@"lengsediao4":@"冷色调4",@"lengsediao5":@"冷色调5",@"lengsediao6":@"冷色调6",@"lengsediao7":@"冷色调7",@"lengsediao8":@"冷色调8",@"lengsediao9":@"冷色调9",@"lengsediao10":@"冷色调10",@"lengsediao11":@"冷色调11",
                                    @"nuansediao1":@"暖色调1",@"nuansediao2":@"暖色调2",@"nuansediao3":@"暖色调3",@"xiaoqingxin1":@"小清新1",@"xiaoqingxin2":@"小清新2",@"xiaoqingxin3":@"小清新3",@"xiaoqingxin4":@"小清新4",@"xiaoqingxin5":@"小清新5",@"xiaoqingxin6":@"小清新6",
                                    @"ziran1":@"自然1",@"ziran2":@"自然2",@"ziran3":@"自然3",@"ziran4":@"自然4",@"ziran5":@"自然5",@"ziran6":@"自然6",@"ziran7":@"自然7",@"ziran8":@"自然8",
                                    @"mitao1":@"蜜桃1",@"mitao2":@"蜜桃2",@"mitao3":@"蜜桃3",@"mitao4":@"蜜桃4",@"mitao5":@"蜜桃5",@"mitao6":@"蜜桃6",@"mitao7":@"蜜桃7",@"mitao8":@"蜜桃8",
                                    @"zhiganhui1":@"质感灰1",@"zhiganhui2":@"质感灰2",@"zhiganhui3":@"质感灰3",@"zhiganhui4":@"质感灰4",@"zhiganhui5":@"质感灰5",@"zhiganhui6":@"质感灰6",@"zhiganhui7":@"质感灰7",@"zhiganhui8":@"质感灰8"
    };
    
    NSMutableArray *tempM = [[NSMutableArray alloc] init];
    for (NSString *str in beautyFiltersDataSource) {
        
        FUBeautyParam *modle = [[FUBeautyParam alloc] init];
        modle.mParam = str;
        modle.mTitle = [filtersCHName valueForKey:str];
        modle.mValue = 0.4;
        modle.type = FUDataTypeFilter;
        [tempM addObject:modle];
    }

    return tempM.copy;
}

/// 道具贴纸
+ (NSArray<FUBeautyParam *> *)setupSticker{

    NSArray *prams = @[@"makeup_noitem",@"sdlu",@"DaisyPig",@"fashi",@"xueqiu_lm_fu",@"wobushi",@"gaoshiqing"];

    NSMutableArray *tempM = [[NSMutableArray alloc] init];
    
    for (NSString *str in prams) {
    
        FUBeautyParam *modle = [[FUBeautyParam alloc] init];
        modle.mParam = str;
        modle.type = FUDataTypeStrick;
        [tempM addObject:modle];
        
    }

    return tempM.copy;
    
}

/// 美妆
+ (NSArray<FUBeautyParam *> *)setupMakeupData{

    NSString *wholePath=[[NSBundle mainBundle] pathForResource:@"makeup_whole" ofType:@"json"];
    NSData *wholeData=[[NSData alloc] initWithContentsOfFile:wholePath];
    NSDictionary *wholeDic=[NSJSONSerialization JSONObjectWithData:wholeData options:NSJSONReadingMutableContainers error:nil];
    NSArray *dataArr = wholeDic[@"data"];
    NSMutableArray *tempM = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in dataArr) {
       
        FUBeautyParam *modle = [[FUBeautyParam alloc] init];
        modle.mParam = dict[@"imageStr"];
        modle.mTitle = dict[@"name"];
        modle.mValue = [dict[@"value"] floatValue];
        modle.makeupBundle = dict[@"makeupBundle"];
        modle.type = FUDataTypeMakeup;
        [tempM addObject:modle];
    }

    return tempM.copy;
    
}

+ (NSArray<FUBeautyParam *>*)setupBodyData{
   NSArray *prams = @[@"BodySlimStrength",@"LegSlimStrength",@"WaistSlimStrength",@"ShoulderSlimStrength",@"HipSlimStrength",@"HeadSlim",@"LegSlim"];
    NSDictionary *titelDic = @{@"BodySlimStrength":@"瘦身",@"LegSlimStrength":@"长腿",@"WaistSlimStrength":@"细腰",@"ShoulderSlimStrength":@"美肩",@"HipSlimStrength":@"美臀",@"HeadSlim":@"小头",@"LegSlim":@"瘦腿"
    };
   NSDictionary *defaultValueDic = @{@"BodySlimStrength":@(0),@"LegSlimStrength":@(0),@"WaistSlimStrength":@(0),@"ShoulderSlimStrength":@(0.5),@"HipSlimStrength":@(0),@"HeadSlim":@(0),@"LegSlim":@(0)
   };
   
   NSMutableArray *array = [[NSMutableArray alloc] init];
   for (NSString *str in prams) {
       BOOL isStyle101 = NO;
       if ([str isEqualToString:@"ShoulderSlimStrength"]) {
           isStyle101 = YES;
       }
       
       FUBeautyParam *modle = [[FUBeautyParam alloc] init];
       modle.mParam = str;
       modle.mTitle = [titelDic valueForKey:str];
       modle.mValue = [[defaultValueDic valueForKey:str] floatValue];
       modle.defaultValue = modle.mValue;
       modle.iSStyle101 = isStyle101;
       modle.type = FUDataTypebody;
       [array addObject:modle];
   }
    
    return array;
}


@end
