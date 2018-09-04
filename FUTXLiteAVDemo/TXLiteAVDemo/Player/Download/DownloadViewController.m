//
//  DownloadViewController.m
//  TXLiteAVDemo_Enterprise
//
//  Created by annidyfeng on 2018/3/20.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "DownloadViewController.h"
#import "TXVodDownloadManager.h"

@interface DownloadViewController ()<TXVodDownloadDelegate>

@end

@implementation DownloadViewController {
    TXVodDownloadManager *_manager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (_manager == nil) {
        _manager = [TXVodDownloadManager shareInstance];
        [_manager setDownloadPath: [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/downloader"]];
    }
    _manager.delegate = self;
    
    [_manager startDownloadUrl:@"http://1253131631.vod2.myqcloud.com/26f327f9vodgzp1253131631/f4bdff799031868222924043041/playlist.m3u8"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)onDownloadStart:(TXVodDownloadMediaInfo *)mediaInfo;
{
    
}
- (void)onDownloadProgress:(TXVodDownloadMediaInfo *)mediaInfo;
{
    
}
- (void)onDownloadStop:(TXVodDownloadMediaInfo *)mediaInfo;
{
    
}
- (void)onDownloadFinish:(TXVodDownloadMediaInfo *)mediaInfo;
{
    
}
- (void)onDownloadError:(TXVodDownloadMediaInfo *)mediaInfo errorCode:(TXDownloadError)code errorMsg:(NSString *)msg;
{
    
}
@end
