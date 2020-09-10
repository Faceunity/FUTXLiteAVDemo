//
//  QCloudLogDetailViewController.h
//  QCloudCOSXML
//
//  Created by erichmzhang(张恒铭) on 2018/10/8.
//
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface QCloudLogDetailViewController : UIViewController
- (instancetype) initWithLogPath:(NSString *)logPath LogContent:(NSString *)logContent;
@end

NS_ASSUME_NONNULL_END
#endif
