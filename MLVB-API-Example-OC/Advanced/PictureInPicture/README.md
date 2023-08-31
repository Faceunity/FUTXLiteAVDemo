[简体中文](README.cn.md) | English

## Sample Code

## Picture-in-picture

### iOS platform (requires iOS15 and above support)

1. First you need to enable background mode
 ![](https://qcloudimg.tencent-cloud.cn/raw/5f757cbcce02e4e555826b16e3eaa3b2.png)
 
2. Initialize the `V2TXLivePlayer` instance object of the SDK and enable custom rendering and background decoding capabilities.

``` objc
	/// Enable custom rendering interface
	[_livePlayer enableObserveVideoFrame:YES pixelFormat:V2TXLivePixelFormatNV12 bufferType:V2TXLiveBufferTypePixelBuffer];
    /// Enable background decoding capability
	[_livePlayer setProperty:@"enableBackgroundDecoding" value:@(YES)];
```

3. Determine whether to enable the PIP function, and create a PIP content source and a PIP controller if supported.

``` objc
	 if (@available(iOS 15.0, *)) {
		if ([AVPictureInPictureController isPictureInPictureSupported]) {
			//Enable picture-in-picture background sound permission
			NSError *error = nil;
			[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
			[[AVAudioSession sharedInstance] setActive:YES error:nil];
			if (error) {
				NSLog(@"%@%@",Localize(@"MLVB-API-Example.Home.PermissionFailed"),error);
			}          
			/// Create a video rendering layer AVSampleBufferDisplayLayer
			[self setupSampleBufferDisplayLayer];
			[self.view.layer addSublayer:self.sampleBufferDisplayLayer];
			/// Initialize the picture-in-picture content source
			AVPictureInPictureControllerContentSource *contentSource = [[AVPictureInPictureControllerContentSource alloc] initWithSampleBufferDisplayLayer:self.sampleBufferDisplayLayer playbackDelegate:self];
			/// Initialize the picture-in-picture controller
			self.pipViewController = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
			self.pipViewController.delegate = self;
			self.pipViewController.canStartPictureInPictureAutomaticallyFromInline = YES;
		}
	}
```

4. After starting to pull the stream, process the video frame in the SDK callback of custom rendering, and convert the video frame (CVPixelBuffer) to (CMSampleBuffer) and send it to AVSampleBufferDisplayLayer for rendering.


``` objc 
- (void)onRenderVideoFrame:(id<V2TXLivePlayer>)player frame:(V2TXLiveVideoFrame *)videoFrame {
    /// The picture-in-picture function needs to get the pixelBuffer format data of the video
    if (videoFrame.bufferType != V2TXLiveBufferTypeTexture && videoFrame.pixelFormat != V2TXLivePixelFormatTexture2D) {
        [self dispatchPixelBuffer:videoFrame.pixelBuffer];
    }
}

//Pack pixelBuffer into samplebuffer and send it to displayLayer
- (void)dispatchPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return;
    }
    //Do not set specific time information
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    //Get video information
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(videoInfo);
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    [self enqueueSampleBuffer:sampleBuffer toLayer:self.sampleBufferDisplayLayer];
    CFRelease(sampleBuffer);
}
```

5. Turn on/off the picture-in-picture function


``` objc
	//Turn on picture-in-picture when the picture-in-picture button is clicked
	if (self.pipViewController.isPictureInPictureActive) {
		[self.pipViewController stopPictureInPicture];
	} else {
		[self.pipViewController startPictureInPicture];
	}
```
So far, the picture-in-picture function of the iOS platform has been implemented. For the specific example code, please refer to the PictureInPictureViewController.m file in the API-Example project.
