#import <UIKit/UIKit.h>
#import "TXUGCRecord.h"

@interface VideoConfigure : NSObject
@property(nonatomic,assign)TXVideoAspectRatio videoRatio;
@property(nonatomic,assign)TXVideoResolution videoResolution;
@property(nonatomic,assign)int bps;
@property(nonatomic,assign)int fps;
@property(nonatomic,assign)int gop;
@end

@interface RecordMusicInfo : NSObject
@property (nonatomic, copy) NSString* filePath;
@property (nonatomic, copy) NSString* soneName;
@property (nonatomic, copy) NSString* singerName;
@property (nonatomic, assign) CGFloat duration;
@end

/**
 *  短视频录制VC
 */
@interface VideoRecordViewController : UIViewController
-(instancetype)initWithConfigure:(VideoConfigure*)configure;
@end
