#import <UIKit/UIKit.h>
#import "TXLivePlayer.h"
/**
 *  短视频预览VC
 */
@class TXRecordResult;
@interface VideoPreviewViewController : UIViewController
- (instancetype)initWithCoverImage:(UIImage *)coverImage
                         videoPath:(NSString*)videoPath
                        renderMode:(TX_Enum_Type_RenderMode)renderMode
                      isFromRecord:(BOOL)isFromRecord;
@end
