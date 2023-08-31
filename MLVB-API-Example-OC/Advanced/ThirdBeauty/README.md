[简体中文](README.cn.md) | English

ThirdBeauty:

1. Download the dependent third-party beauty SDK:https://www.faceunity.com/sdk/FaceUnity-SDK-iOS-v7.4.0.zip
2. Import SDK
    - After the download is complete and decompressed, drag the library folder into the project, and check Copy items if needed.
    - libCNamaSDK.framework is a dynamic library, which needs to be in General->Framworks, Libraries, and Embedded Content
       Add dependencies in , and set Embed to Embed&Sign, otherwise it will crash because the library cannot be found after running.
3. Download FUTRTCDemo：https://github.com/Faceunity/FUTRTCDemo
4. Put the following files in the FaceUnity directory in the FUTRTCDemo project:
    - authpack.h
    - FUBeautyParam.h
    - FUBeautyParam.m
    - FUDateHandle.h
    - FUDateHandle.m
    - FUManager.h
    - FUManager.m
    Drag into the project and check Copy items if needed.
5. Certificate addition: Please contact Faceunity to obtain a test certificate for the certificate key in authpack.h and replace it here (please comment out or delete this error warning after replacement).
6. Uncomment the following in the ThirdBeautyViewController.m file:

    ```
    //#import "FUManager.h"
    ```

    ```
    //@property (strong, nonatomic) FUBeautyParam *beautyParam;
    ```

    ```
    //- (FUBeautyParam *)beautyParam {
    //    if (!_beautyParam) {
    //        _beautyParam = [[FUBeautyParam alloc] init];
    //        _beautyParam.type = FUDataTypeBeautify;
    //        _beautyParam.mParam = @"blur_level";
    //    }
    //    return _beautyParam;
    //}
    ```

    ```
    //    [[FUManager shareManager] loadFilter];
    //    [FUManager shareManager].isRender = YES;
    //    [FUManager shareManager].flipx = YES;
    //    [FUManager shareManager].trackFlipx = YES;
    ```

    ```
    //    self.beautyParam.mValue = sender.value;
    //    [[FUManager shareManager] filterValueChange:self.beautyParam];
    ```

    ```
    //    [[FUManager shareManager] renderItemsToPixelBuffer:frame.pixelBuffer];
    ```

    ```
    //    [[FUManager shareManager] destoryItems];
    ```
7. Command + R to run


