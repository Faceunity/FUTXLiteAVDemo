# FUTXLiteAVDemo 快速接入文档

FUTXLiteAVDemo 是集成了 [Faceunity](https://github.com/Faceunity/FULiveDemo/tree/dev) 面部跟踪和虚拟道具功能 和 腾讯移动直播的Demo。

本文是 FaceUnity SDK 快速对接腾讯移动直播的导读说明，关于 FaceUnity SDK 的更多详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)

注意：本例是示例 Demo , 只在 首页 --> 移动直播 --> MLVBLiveRoom --> 新建直播间 --> 开始直播 内 接入了 FaceUnity 效果，如需更多接入，请用户参照本例自行定义。

### 一、导入 SDK

将 FaceUnity 文件夹全部拖入工程中，并且添加依赖库 `OpenGLES.framework`、`Accelerate.framework`、`CoreMedia.framework`、`AVFoundation.framework`、`libc++.tbd`、`CoreML.framework`

### FaceUnity 模块简介
```C
-FUManager            //nama 业务类
+Lib                  //相芯SDK相关  
    -authpack.h             //权限文件
    -FURenderKit.framework  //FURenderKit动态库      
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
+items         //道具资源 xx.bundel文件
    +美妆         // 美妆 xx.bundle文件
    +贴纸         // 贴纸 xx.bundle文件 
```

### 二、加入展示 FaceUnity SDK 美颜贴纸效果的UI

1、在 `LiveRoomPusherViewController.m`中添加头文件，并创建页面属性

```C
/**faceU */
#import "UIViewController+FaceUnityUIExtension.h"

```

2、在 `viewDidLoad` 中初始化 FaceUnity的界面和 SDK，FaceUnity界面工具和SDK都放在UIViewController+FaceUnityUIExtension中初始化了，也可以自行调用FUAPIDemoBar和FUManager初始化

```objc
[self setupFaceUnity];
```

#### 底部栏切换功能：使用不同的ViewModel控制

```C
-(void)bottomDidChangeViewModel:(FUBaseViewModel *)viewModel {
    if (viewModel.type == FUDataTypeBeauty || viewModel.type == FUDataTypebody) {
        self.renderSwitch.hidden = NO;
    } else {
        self.renderSwitch.hidden = YES;
    }

    [[FUManager shareManager].viewModelManager addToRenderLoop:viewModel];
    
    // 设置人脸数
    [[FUManager shareManager].viewModelManager resetMaxFacesNumber:viewModel.type];
}

```

#### 更新美颜参数

```C
- (IBAction)filterSliderValueChange:(FUSlider *)sender {
    _seletedParam.mValue = @(sender.value * _seletedParam.ratio);
    /**
     * 这里使用抽象接口，有具体子类决定去哪个业务员模块处理数据
     */
    [self.selectedView.viewModel consumerWithData:_seletedParam viewModelBlock:nil];
}
```

### 三、视频数据处理

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

    if ([FUGLContext shareGLContext].currentGLContext != [EAGLContext currentContext]) {
        [[FUGLContext shareGLContext] setCustomGLContext:[EAGLContext currentContext]];
    }
    FURenderInput *input = [[FURenderInput alloc] init];
    input.renderConfig.imageOrientation = FUImageOrientationUP;
    input.renderConfig.isFromFrontCamera = _livePusher.frontCamera;
    input.renderConfig.isFromMirroredCamera =_livePusher.frontCamera;
    input.renderConfig.stickerFlipH = YES;
    FUTexture tex = {texture, CGSizeMake(width, height)};
    input.texture = tex;
    
    //开启重力感应，内部会自动计算正确方向，设置fuSetDefaultRotationMode，无须外面设置
    input.renderConfig.gravityEnable = YES;
    input.renderConfig.textureTransform = CCROT0_FLIPVERTICAL;
    
    FURenderOutput *output = [[FURenderKit shareRenderKit] renderWithInput:input];
    if (output) {
        return output.texture.ID;
    }
    return texture ;
}

```

### 五、销毁道具和切换摄像头

1 视图控制器生命周期结束时 `[[FUManager shareManager] destoryItems];`销毁道具。

2 切换摄像头需要调用 `[[FUManager shareManager] onCameraChange];`切换摄像头

#### 关于 FaceUnity SDK 的更多详细说明，请参看 [FULiveDemo](https://github.com/Faceunity/FULiveDemo/tree/dev)


