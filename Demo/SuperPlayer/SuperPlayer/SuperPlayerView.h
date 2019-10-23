#import <UIKit/UIKit.h>
#import "SuperPlayer.h"
#import "SuperPlayerModel.h"
#import "TXVodPlayer.h"
#import "TXLivePlayer.h"
#import "TXLiveBase.h"
#import "TXImageSprite.h"
#import "CFDanmakuView.h"

@class SuperPlayerControlView;
@class SuperPlayerView;

@protocol SuperPlayerDelegate <NSObject>
@optional
/** 返回事件 */
- (void)superPlayerBackAction:(SuperPlayerView *)player;
/// 全屏改变通知
- (void)superPlayerFullScreenChanged:(SuperPlayerView *)player;
// 需要通知到父view的事件在此添加
@end

// 播放器的几种状态
typedef NS_ENUM(NSInteger, SuperPlayerState) {
    StateFailed,     // 播放失败
    StateBuffering,  // 缓冲中
    StatePlaying,    // 播放中
    StateStopped,    // 停止播放
    StatePause       // 暂停播放
};


@interface SuperPlayerView : UIView

/** 设置代理 */
@property (nonatomic, weak) id<SuperPlayerDelegate>      delegate;

/**
 * 设置播放器的父view。播放过程中调用可实现播放窗口转移
 */
@property (nonatomic, weak) UIView *fatherView;

/** 播放器的状态 */
@property (nonatomic, assign) SuperPlayerState       state;
/** 是否全屏 */
@property (nonatomic, assign) BOOL isFullScreen;
/** 是否锁定旋转 */
@property (nonatomic, assign) BOOL isLockScreen;
/** 是否是直播流 */
@property (readonly) BOOL isLive;
/// 弹幕视图
@property (nonatomic) CFDanmakuView *danmakuView;
/// 超级播放器控制层
@property (nonatomic) SuperPlayerControlView *controlView;
/// 是否允许竖屏手势
@property (nonatomic) BOOL disableGesture;
/// 是否在手势中
@property (readonly)  BOOL isDragging;
/**
 * 设置封面图片
 */
@property (nonatomic) UIImageView *coverImageView;

/**
 * 播放model
 */
- (void)playWithModel:(SuperPlayerModel *)playerModel;

/**
 * 重置player
 */
- (void)resetPlayer;

/**
 * 播放
 */
- (void)resume;

/**
 * 暂停
 */
- (void)pause;

@end
