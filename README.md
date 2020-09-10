# FUTXLiteAVDemo 快速接入文档

FUTXLiteAVDemo 是集成了 [Faceunity](https://github.com/Faceunity/FULiveDemo/tree/dev) 面部跟踪和虚拟道具功能 和 腾讯移动直播的Demo。

本文是 FaceUnity SDK 快速对接腾讯移动直播的导读说明，关于 FaceUnity SDK 的更多详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)

注意：本例是示例 Demo , 只在 首页 --> 移动直播 --> MLVBLiveRoom --> 新建直播间 --> 开始直播 内 接入了 FaceUnity 效果，如需更多接入，请用户参照本例自行定义。

### 一、导入 SDK

将 FaceUnity 文件夹全部拖入工程中，并且添加依赖库 `OpenGLES.framework`、`Accelerate.framework`、`CoreMedia.framework`、`AVFoundation.framework`、`libc++.tbd`、`CoreML.framework`

### FaceUnity 模块简介
```C
+Helpers                //业务管理类文件夹
    -FUManager              //nama 业务类
    -FUCamera               //视频采集类 (本demo未用到)  
+Lib                    //nama SDK  
    -authpack.h             //权限文件
    +libCNamaSDK.framework      
        +Headers
            -funama.h          //C 接口
            -FURenderer.h      //OC 接口
    +Resources
        +model              //AI模型
            -ai_face_processor.bundle      // 人脸识别AI能力模型，需要默认加载
            -ai_face_processor_lite.bundle // 人脸识别AI能力模型，轻量版
            -ai_gesture.bundle             // 手势识别AI能力模型
            -ai_human_processor.bundle     // 人体点位AI能力模型
        +graphics        //随库发版的重要模块资源
            -body_slim.bundle              // 美体道具
            -controller.bundle             // Avatar 道具
            -face_beautification.bundle    // 美颜道具
            -face_makeup.bundle            // 美妆道具
            -fuzzytoonfilter.bundle        // 动漫滤镜道具
            -fxaa.bundle                   // 3D 绘制抗锯齿
            -tongue.bundle                 // 舌头跟踪数据包
    +FUAPIDemoBar     //美颜工具条,可自定义
    +道具贴纸         //道具贴纸 xx.bundel文件
    + 美体            // 美体相关资源
    +美妆          // 美妆 xx.bundel文件
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
[FUManager shareManager].flipx = YES;
[FUManager shareManager].trackFlipx = YES;
[self.view addSubview:self.demoBar];
[FUManager shareManager].showFaceUnityEffect = YES ;
    
```

### 四、视频数据处理

1、在`MLVBLiveRoom.m` 中 初始化推流`initLivePusher`设置_livePusher的代理
    
```C
// 增加此代理，拿到视频数据回调
//TXVideoCustomProcessDelegate
_livePusher.videoProcessDelegate = self ;

```

2、TXVideoCustomProcessDelegate方法中处理数据

```C
#pragma mark - 视频数据回调
- (GLuint)onPreProcessTexture:(GLuint)texture width:(CGFloat)width height:(CGFloat)height {
    
    if ([FUManager shareManager].showFaceUnityEffect) {
        
        texture = [[FUManager shareManager] renderItemWithTexture:texture Width:width Height:height];
    }
    
    return texture ;
}

```

### 五、销毁道具和切换摄像头

1 视图控制器生命周期结束时 `[[FUManager shareManager] destoryItems];`销毁道具。

2 切换摄像头需要调用 `[[FUManager shareManager] onCameraChange];`切换摄像头

#### 关于 FaceUnity SDK 的更多详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)


