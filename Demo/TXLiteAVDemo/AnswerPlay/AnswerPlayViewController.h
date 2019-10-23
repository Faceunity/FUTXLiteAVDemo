//
//  PlayController.h
//  RTMPiOSDemo
//
//  Created by 蓝鲸 on 16/4/1.
//  Copyright © 2016年 tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TXLivePlayer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface AnswerPlayViewController : UIViewController<UIAlertViewDelegate>
{
    TXLivePlayer *      _txLivePlayer;
    UITextView*         _statusView;
    UITextView*         _logViewEvt;
    unsigned long long  _startTime;
    unsigned long long  _lastTime;
    
    UIButton*           _btnPlay;
    UIView*             _cover;
    
    BOOL                _screenPortrait;
    BOOL                _sdMode;
    BOOL                _renderFillScreen;
    BOOL                _log_switch;
    BOOL                _play_switch;
    
    NSString*           _logMsg;
    NSString*           _tipsMsg;
    NSString*           _testPath;
    

    UIButton*           _helpBtn;
    UIButton*           _sdBtn;
    
    TXLivePlayConfig*   _config;
    
    int                 _loadingCount;
    UIAlertController   *_alertController;
}

@property (nonatomic, retain) UITextField* txtRtmpUrl;

@end
