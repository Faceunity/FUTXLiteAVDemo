# FUTXLiteAVDemo 快速集成文档

FUTXLiteAVDemo 是集成了 Faceunity 面部跟踪和虚拟道具功能 和 [腾讯移动直播](https://cloud.tencent.com/document/product/454/7873) 功能的 Demo。

本文是 FaceUnity SDK 快速对接融云 腾讯移动直播 的快速导读说明，关于 `FaceUnity SDK` 的详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)

由于腾讯直播sdk过大，运行demo需要下载[TXLiteAVSDK_Professional下载](https://cloud.tencent.com/document/product/454/7873)

**注意：本例是示例 Demo , 只在 首页 --> 直播 --> 美女直播 --> 新建直播间 --> 开始直播 内 接入了 FaceUnity 效果，如需更多接入，请用户参照本例自行定义。** 

## 主要文件说明

**FUManager** 对 FaceUnity SDK 接口和数据的简单封装。
**FUAPIDemoBar.framework** 展示 FaceUnity 效果的UI。
## 快速集成方法

### 一、获取视频数据回调

1、在 `LiveRoom.m` 内修改 `- (void)initLivePusher` 方法如下：

```C
- (void)initLivePusher {
    if (_livePusher == nil) {
        TXLivePushConfig *config = [[TXLivePushConfig alloc] init];
        config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
        config.pauseFps = 15;
        config.pauseTime = 300;
       
        _videoQuality = VIDEO_QUALITY_HIGH_DEFINITION;
        _livePusher = [[TXLivePush alloc] initWithConfig:config];
        _livePusher.delegate = self;
        
        // 增加此代理，拿到视频数据回调
        _livePusher.videoProcessDelegate = self ;
        
        [_livePusher setVideoQuality:_videoQuality adjustBitrate:NO adjustResolution:NO];
        [_livePusher setLogViewMargin:UIEdgeInsetsMake(120, 10, 60, 10)];
        config.videoEncodeGop = 5;
        [_livePusher setConfig:config];
    }
}

```

2、在 `LiveRoom.m` 内遵循代理 `TXVideoCustomProcessDelegate`

3、实现 `TXVideoCustomProcessDelegate ` 中的代理方法如下：

```C
- (GLuint)onPreProcessTexture:(GLuint)texture width:(CGFloat)width height:(CGFloat)height {
    
    if ([FUManager shareManager].showFaceUnityEffect) {
        texture = [[FUManager shareManager] renderItemWithTexture:texture Width:width Height:height];
    }
    
    return texture ;
}

```

### 二、接入 Faceunity SDK

将  FaceUnity  文件夹全部拖入工程中，并且添加依赖库 OpenGLES.framework、Accelerate.framework、CoreMedia.framework、AVFoundation.framework、stdc++.tbd

#### 1、快速加载道具

在 `LiveRoomPusherViewController.m` 的 `- (void)viewWillAppear:(BOOL)animated ` 方法中 调用 `[[FUManager shareManager] loadItems]` 加载贴纸道具及美颜道具如下：

```C
[[FUManager shareManager] loadItems];
[self.view addSubview:self.demoBar];
[FUManager shareManager].showFaceUnityEffect = YES ;
```


#### 2、道具切换

调用 `[[FUManager shareManager] loadItem: itemName];` 切换道具

#### 3、更新美颜参数

```C
- (void)demoBarDidSelectedItem:(NSString *)itemName {
    
    [[FUManager shareManager] loadItem:itemName];
}


- (void)demoBarBeautyParamChanged {
    
    [FUManager shareManager].skinDetectEnable = _demoBar.skinDetectEnable;
    [FUManager shareManager].blurShape = _demoBar.blurShape;
    [FUManager shareManager].blurLevel = _demoBar.blurLevel ;
    [FUManager shareManager].whiteLevel = _demoBar.whiteLevel;
    [FUManager shareManager].redLevel = _demoBar.redLevel;
    [FUManager shareManager].eyelightingLevel = _demoBar.eyelightingLevel;
    [FUManager shareManager].beautyToothLevel = _demoBar.beautyToothLevel;
    [FUManager shareManager].faceShape = _demoBar.faceShape;
    [FUManager shareManager].enlargingLevel = _demoBar.enlargingLevel;
    [FUManager shareManager].thinningLevel = _demoBar.thinningLevel;
    [FUManager shareManager].enlargingLevel_new = _demoBar.enlargingLevel_new;
    [FUManager shareManager].thinningLevel_new = _demoBar.thinningLevel_new;
    [FUManager shareManager].jewLevel = _demoBar.jewLevel;
    [FUManager shareManager].foreheadLevel = _demoBar.foreheadLevel;
    [FUManager shareManager].noseLevel = _demoBar.noseLevel;
    [FUManager shareManager].mouthLevel = _demoBar.mouthLevel;
    
    [FUManager shareManager].selectedFilter = _demoBar.selectedFilter ;
    [FUManager shareManager].selectedFilterLevel = _demoBar.selectedFilterLevel;
}

```

#### 4、道具销毁

调用 `[[FUManager shareManager] destoryItems];` 销毁贴纸及美颜道具。

**注：关于 `FaceUnity SDK` 的详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)**