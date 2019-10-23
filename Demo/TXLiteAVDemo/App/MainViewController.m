//
//  MainViewController.m
//  RTMPiOSDemo
//
//  Created by rushanting on 2017/4/28.
//  Copyright © 2017年 tencent. All rights reserved.
//

#import "MainViewController.h"
#ifdef ENABLE_PUSH
#import "PublishViewController.h"
#endif
#ifdef ENABLE_PLAY
#import "PlayViewController.h"
#ifndef DISABLE_VOD
#import "PlayVodViewController.h"
#import "DownloadViewController.h"
#endif
#endif
#ifdef ENABLE_UGC
#import "VideoRecordConfigViewController.h"
#import "QBImagePickerController.h"
#import "SuperPlayer.h"
#endif

#import "VideoLoadingController.h"
#import "ColorMacro.h"
#import "MainTableViewCell.h"
#import "TXLiveBase.h"


#define STATUS_BAR_HEIGHT [UIApplication sharedApplication].statusBarFrame.size.height

#define OLD_VOD 0

@interface MainViewController ()<
#ifdef ENABLE_UGC
QBImagePickerControllerDelegate,
#endif
UITableViewDelegate,
UITableViewDataSource,
UIPickerViewDataSource,
UIPickerViewDelegate,
UIAlertViewDelegate
>

@property (nonatomic) NSMutableArray<CellInfo*>* cellInfos;
@property (nonatomic) NSArray<CellInfo*>* addNewCellInfos;
@property (nonatomic) MainTableViewCell *selectedCell;
@property (nonatomic) UITableView* tableView;
@property (nonatomic) UIView*   logUploadView;
@property (nonatomic) UIPickerView* logPickerView;
#ifdef ENABLE_UGC
@property (nonatomic) QBImagePickerMediaType mediaType;
#endif
@property (nonatomic) NSMutableArray* logFilesArray;

@end

@implementation MainViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initCellInfos];
    [self initUI];
}

- (void)initCellInfos
{
    _cellInfos = [NSMutableArray new];
    CellInfo* cellInfo = nil;
    
#ifdef ENABLE_PUSH
    cellInfo = [CellInfo new];
    cellInfo.title = @"直播";
    cellInfo.iconName = @"live_room";
    [_cellInfos addObject:cellInfo];
    cellInfo.subCells = ({
        NSMutableArray *subCells = [NSMutableArray new];
        CellInfo* scellInfo;
#ifdef ENABLE_PLAY
        scellInfo = [CellInfo new];
        scellInfo.title = @"美女直播";
        scellInfo.navigateToController = @"LiveRoomListViewController";
        [subCells addObject:scellInfo];
#endif
        scellInfo = [CellInfo new];
        scellInfo.title = @"录屏直播";
        scellInfo.navigateToController = @"Replaykit2ViewController";
        [subCells addObject:scellInfo];
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"小直播";
        scellInfo.navigateToController = nil;
        [subCells addObject:scellInfo];
        
        subCells;
    });
#endif

#if defined(ENABLE_PLAY) && !defined(DISABLE_VOD)


    cellInfo = [CellInfo new];
    cellInfo.title = @"播放器";
    cellInfo.iconName = @"composite";
    [_cellInfos addObject:cellInfo];
    cellInfo.subCells = ({
        NSMutableArray *subCells = [NSMutableArray new];
        CellInfo* scellInfo;
        scellInfo = [CellInfo new];
        scellInfo.title = @"超级播放器";
        scellInfo.navigateToController = @"MoviePlayerViewController";
        [subCells addObject:scellInfo];
        subCells;
    
    });
#endif
    
#ifdef ENABLE_UGC
    cellInfo = [CellInfo new];
    cellInfo.title = @"短视频";
    cellInfo.iconName = @"video";
    [_cellInfos addObject:cellInfo];
    cellInfo.subCells = ({
        NSMutableArray *subCells = [NSMutableArray new];
        CellInfo* scellInfo;
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"视频录制";
        scellInfo.navigateToController = @"VideoRecordConfigViewController";
        [subCells addObject:scellInfo];
        
#ifndef UGC_SMART        
        scellInfo = [CellInfo new];
        scellInfo.title = @"特效编辑";
        scellInfo.navigateToController = @"QBImagePickerController";
        [subCells addObject:scellInfo];
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"视频拼接";
        scellInfo.navigateToController = @"QBImagePickerController";
        [subCells addObject:scellInfo];
        
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"图片转场";
        scellInfo.navigateToController = @"QBImagePickerController";
        [subCells addObject:scellInfo];
#endif
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"视频上传";
        scellInfo.navigateToController = @"QBImagePickerController";
        [subCells addObject:scellInfo];
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"小视频";
        scellInfo.navigateToController = nil;
        [subCells addObject:scellInfo];
        
        subCells;
    });
#endif
    
#if defined(ENABLE_PLAY) && defined(ENABLE_PUSH)
    cellInfo = [CellInfo new];
    cellInfo.title = @"视频通话";
    cellInfo.iconName = @"multi_room";
    [_cellInfos addObject:cellInfo];
    cellInfo.subCells = ({
        NSMutableArray *subCells = [NSMutableArray new];
        CellInfo* scellInfo;
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"双人音视频";
        scellInfo.navigateToController = @"RTCDoubleRoomListViewController";
        [subCells addObject:scellInfo];
        
        scellInfo = [CellInfo new];
        scellInfo.title = @"多人音视频";
        scellInfo.navigateToController = @"RTCMultiRoomListViewController";
        [subCells addObject:scellInfo];
        
        subCells;
    });
#endif
    
    cellInfo = [CellInfo new];
    cellInfo.title = @"调试工具";
    cellInfo.iconName = @"dbg_tool";
    [_cellInfos addObject:cellInfo];
    cellInfo.subCells = ({
        NSMutableArray *subCells = [NSMutableArray new];
        CellInfo* scellInfo;
#ifdef ENABLE_PUSH
        scellInfo = [CellInfo new];
        scellInfo.title = @"RTMP 推流";
        scellInfo.navigateToController = @"PublishViewController";
        [subCells addObject:scellInfo];
#endif
#ifdef ENABLE_PLAY
        scellInfo = [CellInfo new];
        scellInfo.title = @"直播播放器";
        scellInfo.navigateToController = @"PlayViewController";
        [subCells addObject:scellInfo];
#endif
        
#ifndef DISABLE_VOD
        scellInfo = [CellInfo new];
        scellInfo.title = @"点播播放器";
        scellInfo.navigateToController = @"PlayVodViewController";
        [subCells addObject:scellInfo];
#if 0
        scellInfo = [CellInfo new];
        scellInfo.title = @"下载";
        scellInfo.navigateToController = @"DownloadViewController";
        [subCells addObject:scellInfo];
#endif
#endif
#if defined(ENABLE_PLAY) && defined(ENABLE_PUSH)

        scellInfo = [CellInfo new];
        scellInfo.title = @"WebRTC Room";
        scellInfo.navigateToController = @"WebRTCViewController";
        [subCells addObject:scellInfo];
#endif
        subCells;
    });
}

- (void)initUI
{
    int originX = 15;
    CGFloat width = self.view.frame.size.width - 2 * originX;
    
    self.view.backgroundColor = UIColorFromRGB(0x0d0d0d);
    
    //大标题
    UILabel* lbHeadLine = [[UILabel alloc] initWithFrame:CGRectMake(originX, 50, width, 48)];
    lbHeadLine.text = @"腾讯视频云";
    lbHeadLine.textColor = UIColorFromRGB(0xffffff);
    lbHeadLine.font = [UIFont systemFontOfSize:24];
    [lbHeadLine sizeToFit];
    [self.view addSubview:lbHeadLine];
    lbHeadLine.center = CGPointMake(lbHeadLine.superview.center.x, lbHeadLine.center.y);
    
    lbHeadLine.userInteractionEnabled = YES;
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [lbHeadLine addGestureRecognizer:tapGesture];
    
    UILongPressGestureRecognizer* pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)]; //提取SDK日志暗号!
    pressGesture.minimumPressDuration = 2.0;
    pressGesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:pressGesture];
    
    
    //副标题
    UILabel* lbSubHead = [[UILabel alloc] initWithFrame:CGRectMake(originX, lbHeadLine.frame.origin.y + lbHeadLine.frame.size.height + 15, width, 30)];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    lbSubHead.text = [NSString stringWithFormat:@"视频云工具包 v%@", version];
    lbSubHead.text = [lbSubHead.text stringByAppendingString:@"\n本APP用于展示腾讯视频云终端产品的各类功能"];
    lbSubHead.numberOfLines = 2;
    lbSubHead.textColor = UIColor.grayColor;
    lbSubHead.textAlignment = NSTextAlignmentCenter;
    lbSubHead.font = [UIFont systemFontOfSize:14];
    lbSubHead.textColor = UIColorFromRGB(0x535353);
    
    //行间距
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:lbSubHead.text];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    [paragraphStyle setLineSpacing:7.5f];//设置行间距
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, lbSubHead.text.length)];
    lbSubHead.attributedText = attributedString;
    
    [lbSubHead sizeToFit];
    
    [self.view addSubview:lbSubHead];
    lbSubHead.userInteractionEnabled = YES;
    [lbSubHead addGestureRecognizer:tapGesture];
    lbSubHead.frame = CGRectMake(lbSubHead.frame.origin.x, self.view.frame.size.height-lbSubHead.frame.size.height-34, lbSubHead.frame.size.width, lbSubHead.frame.size.height);
    lbSubHead.center = CGPointMake(lbSubHead.superview.frame.size.width/2, lbSubHead.center.y);
    
    //功能列表
    int tableviewY = lbSubHead.frame.origin.y + lbSubHead.frame.size.height + 12;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(originX, tableviewY, width, self.view.frame.size.height - tableviewY)];
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    _tableView.frame = CGRectMake(_tableView.frame.origin.x, lbHeadLine.frame.origin.y+lbHeadLine.frame.size.height+12, _tableView.frame.size.width, _tableView.superview.frame.size.height);
    _tableView.frame = CGRectMake(_tableView.frame.origin.x, _tableView.frame.origin.y, _tableView.frame.size.width, _tableView.superview.frame.size.height-_tableView.frame.origin.y);
    
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor clearColor];
    [_tableView setTableFooterView:view];
    
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    _logUploadView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height / 2, self.view.bounds.size.width, self.view.bounds.size.height / 2)];
    _logUploadView.backgroundColor = [UIColor whiteColor];
    _logUploadView.hidden = YES;
    
    _logPickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, _logUploadView.frame.size.height * 0.8)];
    _logPickerView.dataSource = self;
    _logPickerView.delegate = self;
    [_logUploadView addSubview:_logPickerView];
    
    UIButton* uploadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    uploadButton.center = CGPointMake(self.view.bounds.size.width / 2, _logUploadView.frame.size.height * 0.9);
    uploadButton.bounds = CGRectMake(0, 0, self.view.bounds.size.width / 3, _logUploadView.frame.size.height * 0.2);
    [uploadButton setTitle:@"分享上传日志" forState:UIControlStateNormal];
    [uploadButton addTarget:self action:@selector(onSharedUploadLog:) forControlEvents:UIControlEventTouchUpInside];
    [_logUploadView addSubview:uploadButton];
    
    [self.view addSubview:_logUploadView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _cellInfos.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_cellInfos.count < indexPath.row)
        return nil;
    
    static NSString* cellIdentifier = @"MainViewCellIdentifier";
    MainTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[MainTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    CellInfo* cellInfo = _cellInfos[indexPath.row];
    
    [cell setCellData:cellInfo];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!_logUploadView.hidden) {
        _logUploadView.hidden = YES;
    }
    
    if (_cellInfos.count < indexPath.row)
        return ;
    
    MainTableViewCell *currentCell = [tableView cellForRowAtIndexPath:indexPath];
    CellInfo* cellInfo = currentCell.cellData;
    
    if (cellInfo.subCells != nil) {
        [tableView beginUpdates];
        NSMutableArray *indexArray = [NSMutableArray new];
        if (self.addNewCellInfos) {
            NSUInteger deleteFrom = [_cellInfos indexOfObject:self.addNewCellInfos[0]];
            for (int i = 0; i < self.addNewCellInfos.count; i++) {
                [indexArray addObject:[NSIndexPath indexPathForRow:i+deleteFrom inSection:0]];
            }
            [tableView deleteRowsAtIndexPaths:indexArray withRowAnimation:UITableViewRowAnimationAutomatic];
            [_cellInfos removeObjectsInArray:self.addNewCellInfos];
        }
        [tableView endUpdates];
        
        [tableView beginUpdates];
        if (!cellInfo.isUnFold) {
            self.selectedCell.highLight = NO;
            self.selectedCell.cellData.isUnFold = NO;
            
            NSUInteger row = [_cellInfos indexOfObject:cellInfo]+1;
            [indexArray removeAllObjects];
            for (int i = 0; i < cellInfo.subCells.count; i++) {
                [indexArray addObject:[NSIndexPath indexPathForRow:i+row inSection:0]];
            }
            [_cellInfos insertObjects:cellInfo.subCells atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, cellInfo.subCells.count)]];
            [tableView insertRowsAtIndexPaths:indexArray withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [tableView endUpdates];
        
        cellInfo.isUnFold = !cellInfo.isUnFold;
        currentCell.highLight = cellInfo.isUnFold;
        self.selectedCell = currentCell;
        if (cellInfo.isUnFold) {
            self.addNewCellInfos = cellInfo.subCells;
        } else {
            self.addNewCellInfos = nil;
        }
        return;
    }
    
    NSString* controllerClassName = cellInfo.navigateToController;
    Class controllerClass = NSClassFromString(controllerClassName);
    id controller = [[controllerClass alloc] init];
    
#ifdef ENABLE_PLAY
    if ([cellInfo.title isEqualToString:@"直播播放器"]) {
        ((PlayViewController*)controller).isLivePlay = YES;
    }
    else if ([cellInfo.title isEqualToString:@"低延时播放"]) {
        ((PlayViewController*)controller).isLivePlay = YES;
        ((PlayViewController*)controller).isRealtime = YES;
    }
#endif
    
    
#ifdef ENABLE_UGC
    if ([controller isKindOfClass:[VideoRecordConfigViewController class]]) {
        controller = [[VideoRecordConfigViewController alloc] initWithNibName:@"VideoRecordConfigViewController" bundle:nil];
    }
    if ([controller isKindOfClass:[QBImagePickerController class]]) {
        QBImagePickerController* imagePicker = ((QBImagePickerController*)controller);
        imagePicker.delegate = self;
        imagePicker.mediaType = QBImagePickerMediaTypeVideo;
        if ([cellInfo.title isEqualToString:@"视频拼接"]) {
            imagePicker.allowsMultipleSelection = YES;
            imagePicker.showsNumberOfSelectedAssets = YES;
            imagePicker.maximumNumberOfSelection = 10;
            _mediaType = QBImagePickerMediaTypeVideo;
        }
        else if([cellInfo.title isEqualToString:@"视频上传"]){
            imagePicker.allowsMultipleSelection = NO;
            imagePicker.showsNumberOfSelectedAssets = NO;
            _mediaType = QBImagePickerMediaTypeVideo;
        }
#ifndef UGC_SMART
        else if([cellInfo.title isEqualToString:@"特效编辑"]){
            imagePicker.allowsMultipleSelection = NO;
            imagePicker.showsNumberOfSelectedAssets = NO;
            imagePicker.mediaType = QBImagePickerMediaTypeVideo;
            _mediaType = imagePicker.mediaType;
        }
        else if([cellInfo.title isEqualToString:@"图片转场"]){
            imagePicker.allowsMultipleSelection = YES;
            imagePicker.minimumNumberOfSelection = 3;
            imagePicker.showsNumberOfSelectedAssets = YES;
            imagePicker.mediaType = QBImagePickerMediaTypeImage;
            _mediaType = imagePicker.mediaType;
        }
#endif
//
//        else{
//            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"选择图片还是视频编辑？" message:nil delegate:self cancelButtonTitle:@"图片" otherButtonTitles:@"视频", nil];
//            [alert show];
//            return;
//        }
    }
    if ([cellInfo.title isEqualToString:@"小视频"]) {
//        NSString *urlStr = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=%@", @"1374099214"];
        NSString *urlStr = [NSString stringWithFormat:@"http://itunes.apple.com/cn/app/id1374099214?mt=8"];
        //打开链接地址
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
        
        return;
    }
#endif
#ifdef ENABLE_PUSH
    if ([cellInfo.title isEqualToString:@"小直播"]) {
//        NSString *urlStr = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=%@", @"1132521667"];
        NSString *urlStr = [NSString stringWithFormat:@"http://itunes.apple.com/cn/app/id1132521667?mt=8"];
        //打开链接地址
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
        
        return;
    }
#endif
    [self.navigationController pushViewController:controller animated:YES];
}

#ifdef ENABLE_UGC
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    QBImagePickerController* imagePicker = [[QBImagePickerController alloc] init];
    imagePicker.delegate = self;
    if (buttonIndex == 0) {
        imagePicker.allowsMultipleSelection = YES;
        imagePicker.minimumNumberOfSelection = 3;
        imagePicker.showsNumberOfSelectedAssets = YES;
        imagePicker.mediaType = QBImagePickerMediaTypeImage;
        _mediaType = imagePicker.mediaType;
    }else{
        imagePicker.allowsMultipleSelection = NO;
        imagePicker.showsNumberOfSelectedAssets = NO;
        imagePicker.mediaType = QBImagePickerMediaTypeVideo;
        _mediaType = imagePicker.mediaType;
    }
    [self.navigationController pushViewController:imagePicker animated:YES];
}
#endif

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CellInfo* cellInfo = _cellInfos[indexPath.row];
    if (cellInfo.subCells != nil) {
        return 65;
    }
    return 51;
}

#ifdef ENABLE_UGC
#pragma mark - QBImagePickerControllerDelegate
- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets
{
    [self.navigationController popViewControllerAnimated:YES];
    
    VideoLoadingController *loadvc = [[VideoLoadingController alloc] init];
    NSInteger selectedRow = _tableView.indexPathForSelectedRow.row;
    if (selectedRow >= _cellInfos.count)
        return;
    
    CellInfo* cellInfo = _cellInfos[selectedRow];
    if ([cellInfo.title isEqualToString:@"特效编辑"] || [cellInfo.title isEqualToString:@"图片转场"]) {
        loadvc.composeMode = ComposeMode_Edit;
    } else if ([cellInfo.title isEqualToString:@"视频拼接"]) {
        loadvc.composeMode = ComposeMode_Join;
    } else if ([cellInfo.title isEqualToString:@"视频上传"]) {
        loadvc.composeMode = ComposeMode_Upload;
    }
    else return;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:loadvc];
    [self presentViewController:nav animated:YES completion:nil];
    [loadvc exportAssetList:assets assetType:_mediaType == QBImagePickerMediaTypeImage ? AssetType_Image : AssetType_Video];
    
    if (SuperPlayerWindowShared.isShowing) {
        [SuperPlayerWindowShared hide];
        [SuperPlayerWindowShared.superPlayer resetPlayer];
    }
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    NSLog(@"imagePicker Canceled.");
    
    [self.navigationController popViewControllerAnimated:YES];
    
}
#endif

- (void)handleLongPress:(UILongPressGestureRecognizer *)pressRecognizer
{
    if (pressRecognizer.state == UIGestureRecognizerStateBegan) {
        NSLog(@"long Press");
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *logDoc = [NSString stringWithFormat:@"%@%@", paths[0], @"/log"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray* fileArray = [fileManager contentsOfDirectoryAtPath:logDoc error:nil];
        self.logFilesArray = [NSMutableArray new];
        for (NSString* logName in fileArray) {
            if ([logName hasSuffix:@"xlog"]) {
                [self.logFilesArray addObject:logName];
            }
        }
        
        _logUploadView.alpha = 0.1;
        [UIView animateWithDuration:0.5 animations:^{
            _logUploadView.hidden = NO;
            _logUploadView.alpha = 1;
        }];
        [_logPickerView reloadAllComponents];
    }
}

- (void)handleTap:(UITapGestureRecognizer*)tapRecognizer
{
    if (!_logUploadView.hidden) {
        _logUploadView.hidden = YES;
    }
}

- (void)onSharedUploadLog:(UIButton*)sender
{
    NSInteger row = [_logPickerView selectedRowInComponent:0];
    if (row < self.logFilesArray.count) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *logDoc = [NSString stringWithFormat:@"%@%@", paths[0], @"/log"];
        NSString* logPath = [logDoc stringByAppendingPathComponent:self.logFilesArray[row]];
        NSURL *shareobj = [NSURL fileURLWithPath:logPath];
        UIActivityViewController *activityView = [[UIActivityViewController alloc] initWithActivityItems:@[shareobj] applicationActivities:nil];
        [self presentViewController:activityView animated:YES completion:^{
            _logUploadView.hidden = YES;
        }];
    }
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.logFilesArray.count;
}

- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (row < self.logFilesArray.count) {
        return (NSString*)self.logFilesArray[row];
    }
    
    return nil;
}

@end
