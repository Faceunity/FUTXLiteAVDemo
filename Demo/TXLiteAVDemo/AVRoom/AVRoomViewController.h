#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TXCAVRoom.h"

#import "BeautySettingPanel.h"

@interface AVRoomViewController : UIViewController<TXCAVRoomListener, BeautySettingPanelDelegate> {
    
    BOOL             _log_switch;
    BOOL             _camera_switch;
    BOOL             _renderFillScreen;
    BOOL             _mirror_switch;
    BOOL             _mute_switch;
    BOOL             _pure_switch;

    UITextField*     _txtRoomId;
    UIButton*        _btnJoin;
    UIButton*        _btnCamera;
    UIButton*        _btnBeauty;
    UIButton*        _btnLog;
    UIButton*        _btnRenderFillScreen;
    UIButton*        _btnMirror;
    UIButton*        _btnMute;
    UIButton*        _btnPure;
    
    BeautySettingPanel*   _vBeauty;
}

@end
