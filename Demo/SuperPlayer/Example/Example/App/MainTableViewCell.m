//
//  MainTableViewCell.m
//  RTMPiOSDemo
//
//  Created by rushanting on 2017/5/3.
//  Copyright © 2017年 tencent. All rights reserved.
//

#import "MainTableViewCell.h"
#import "ColorMacro.h"
#import "UIView+MMLayout.h"

@implementation CellInfo
- (id)init {
    self = [super init];
  
    return self;
}
@end


@interface MainTableViewCell () {
    UIView*         _backgroundView;
    UIImageView*    _iconImageView;
    UILabel*        _titleLabel;
    UIImageView*    _detailImageView;
}

@end

@implementation MainTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}



- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        _backgroundView = [[UIView alloc] init];
        [self addSubview:_backgroundView];
        
        _iconImageView = [[UIImageView alloc] init];
        _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        [_backgroundView addSubview:_iconImageView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        _titleLabel.font = [UIFont systemFontOfSize:20];
        _titleLabel.textColor = UIColor.whiteColor;
        [_backgroundView addSubview:_titleLabel];

        _detailImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"arrow"]];
        [_backgroundView addSubview:_detailImageView];
        _detailImageView.hidden = YES;

    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    
    
    if (_cellData.subCells != nil) {
        _iconImageView.hidden = NO;
        _detailImageView.hidden = YES;
        _titleLabel.font = [UIFont systemFontOfSize:20];
    } else {
        _iconImageView.hidden = YES;
        _detailImageView.hidden = NO;
        _titleLabel.font = [UIFont systemFontOfSize:16];
    }
    
    if (_cellData.subCells) {
        _backgroundView.frame = CGRectMake(0, 10, self.frame.size.width, 55);
    } else {
        _backgroundView.frame = CGRectMake(0, 0, self.frame.size.width, 50);
    }
    
    _titleLabel.m_center().m_left(25);
    if (_iconImageView.image) {
        _iconImageView.m_center().m_right(25);
    }
    _detailImageView.m_center().m_right(25);
}

- (void)setCellData:(CellInfo*)cellInfo
{
    _cellData = cellInfo;
    UIImage* image = cellInfo.iconName != nil ? [UIImage imageNamed:cellInfo.iconName] : nil;
    _iconImageView.image = image;
    [_iconImageView sizeToFit];
    _titleLabel.text = cellInfo.title;
    [_titleLabel sizeToFit];
    self.highLight = _cellData.expanded;
    
}

- (void)setHighLight:(BOOL)highLight {
    if (highLight) {
        _backgroundView.backgroundColor = UIColorFromRGB(0x555555);
    } else {
        _backgroundView.backgroundColor = UIColorFromRGB(0x2a2a2a);
    }
    _highLight = highLight;
}

@end
