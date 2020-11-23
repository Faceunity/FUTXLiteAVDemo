# FUTXLiteAVDemo 快速接入文档

FUTXLiteAVDemo 是集成了 [Faceunity](https://github.com/Faceunity/FULiveDemo/tree/dev) 面部跟踪和虚拟道具功能 和 腾讯移动直播的Demo。

本文是 FaceUnity SDK 快速对接腾讯移动直播的导读说明，关于 FaceUnity SDK 的更多详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)

注意：本例是示例 Demo , 只在 首页 --> 移动直播 --> MLVBLiveRoom --> 新建直播间 --> 开始直播 内 接入了 FaceUnity 效果，如需更多接入，请用户参照本例自行定义。

### 一、导入 SDK

将  FaceUnity  文件夹全部拖入工程中，NamaSDK所需依赖库为 `OpenGLES.framework`、`Accelerate.framework`、`CoreMedia.framework`、`AVFoundation.framework`、`libc++.tbd`、`CoreML.framework`

- 备注: 上述NamaSDK 依赖库使用 Pods 管理 会自动添加依赖,运行在iOS11以下系统时,需要手动添加`CoreML.framework`,并在**TARGETS -> Build Phases-> Link Binary With Libraries**将`CoreML.framework`手动修改为可选**Optional**

### FaceUnity 模块简介
```C
-FUManager              //nama 业务类
-FUCamera               //视频采集类 (本demo未用到)   
-authpack.h             //权限文件
+FUAPIDemoBar     //美颜工具条,可自定义
+item       //道具贴纸 xx.bundel文件

```

### 二、加入展示 FaceUnity SDK 美颜贴纸效果的UI

1、在 `LiveRoomPusherViewController.m`中添加头文件，并创建页面属性

```C
/**faceU */
#import "FUManager.h"
#import "FUAPIDemoBar.h"


@property (nonatomic, strong) FUAPIDemoBar *demoBar ;

```

2、初始化 UI，并遵循代理  FUAPIDemoBarDelegate ，实现代理方法 `bottomDidChange:` 切换贴纸 和 `filterValueChange:` 更新美颜参数。

```C
// demobar 初始化
-(FUAPIDemoBar *)demoBar {
    if (!_demoBar) {
        _demoBar = [[FUAPIDemoBar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 194 - 60, self.view.frame.size.width, 194)];
        
        _demoBar.mDelegate = self;
    }
    return _demoBar ;
}

```

#### 切换贴纸

```C
// 切换贴纸
-(void)bottomDidChange:(int)index{
    if (index < 3) {
        [[FUManager shareManager] setRenderType:FUDataTypeBeautify];
    }
    if (index == 3) {
        [[FUManager shareManager] setRenderType:FUDataTypeStrick];
    }
    
    if (index == 4) {
        [[FUManager shareManager] setRenderType:FUDataTypeMakeup];
    }
    if (index == 5) {
        [[FUManager shareManager] setRenderType:FUDataTypebody];
    }
}

```

#### 更新美颜参数

```C
// 更新美颜参数    
- (void)filterValueChange:(FUBeautyParam *)param{
    [[FUManager shareManager] filterValueChange:param];
}
```

### 三、在 `viewDidLoad:` 中初始化 SDK  并将  demoBar 添加到页面上

```C
    /**faceU */
    [[FUManager shareManager] loadFilter];
    [FUManager shareManager].isRender = YES;
    [FUManager shareManager].showFaceUnityEffect = YES;
    [FUManager shareManager].flipx = YES;
    [FUManager shareManager].trackFlipx = YES;
    [self.view addSubview:self.demoBar];
   
    
```

### 四、视频数据处理

使用FUCamera自采集 `在MLVBLiveRoom.m`,实现FUCameraDelegate的代理
```
- (void)didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    
    [[FUTestRecorder shareRecorder] processFrameWithLog];
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [[FUManager shareManager] renderItemsToPixelBuffer:pixelBuffer];
    [self.glView displayPixelBuffer:pixelBuffer];
    [_livePusher sendVideoSampleBuffer:sampleBuffer];
    
}
```

### 五、销毁道具和切换摄像头

1 视图控制器生命周期结束时 `[[FUManager shareManager] destoryItems];`销毁道具。

2 切换摄像头需要调用 `[[FUManager shareManager] onCameraChange];`切换摄像头

### 关于 FaceUnity SDK 的更多详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)


