//
//  XUIFileCell.m
//  XXTExplorer
//
//  Created by Zheng on 17/09/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XUIFileCell.h"

#import "XXTExplorerDefaults.h"
#import "XXTExplorerEntryParser.h"
#import "XXTExplorerViewController+SharedInstance.h"

@interface XUIFileCell ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;

@end

@implementation XUIFileCell

@synthesize xui_value = _xui_value, xui_height = _xui_height;

+ (BOOL)xibBasedLayout {
    return YES;
}

+ (BOOL)layoutNeedsTextLabel {
    return NO;
}

+ (BOOL)layoutNeedsImageView {
    return NO;
}

+ (BOOL)layoutRequiresDynamicRowHeight {
    return NO;
}

+ (NSDictionary <NSString *, Class> *)entryValueTypes {
    return
    @{
      @"allowedExtensions": [NSArray class],
      @"initialPath": [NSString class],
      @"value": [NSString class]
      };
}

- (void)setupCell {
    [super setupCell];
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryType = UITableViewCellAccessoryNone;
    
    _xui_height = @(XUIFileCellHeight); // standard height for file cell
    _xui_allowedExtensions = @[ @"lua", @"xxt", @"xpp" ];
    
    [self resetCellState];
}

- (void)setXui_value:(id)xui_value {
    if (!xui_value) {
        _xui_value = xui_value;
        [self resetCellState];
        return;
    }
    NSString *filePath = xui_value;
    if (filePath) {
        XXTExplorerEntry *entryDetail = [XXTExplorerViewController.explorerEntryParser entryOfPath:filePath withError:nil];
        if (entryDetail)
        {
            NSString *entryDisplayName = [entryDetail localizedDisplayName];
            NSString *entryDescription = [entryDetail localizedDescription];
            UIImage *entryIconImage = [entryDetail localizedDisplayIconImage];
            self.nameLabel.text = entryDisplayName;
            self.descriptionLabel.text = entryDescription;
            self.iconImageView.image = entryIconImage;
            _xui_value = xui_value;
            return;
        }
    }
}

- (void)resetCellState {
    self.nameLabel.text = NSLocalizedString(@"Tap here to add a file.", nil);
    self.descriptionLabel.text = [self openWithCellDescriptionFromExtensions:self.xui_allowedExtensions];
    self.iconImageView.image = [UIImage imageNamed:@"XUIFileCellIcon"];
}

- (NSString *)openWithCellDescriptionFromExtensions:(NSArray <NSString *> *)extensions {
    NSMutableString *mutableDescription = [@"" mutableCopy];
    [extensions enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < extensions.count - 1)
            [mutableDescription appendFormat:@"%@, ", obj];
        else
            [mutableDescription appendFormat:@"%@. ", obj];
    }];
    return [[NSString alloc] initWithString:mutableDescription];
}

- (void)setInternalTheme:(XUITheme *)theme {
    [super setInternalTheme:theme];
    self.nameLabel.textColor = theme.labelColor;
    self.descriptionLabel.textColor = theme.valueColor;
}

- (BOOL)canDelete {
    return YES;
}

@end
