//
//  XXTEMoreAddressCell.m
//  XXTExplorer
//
//  Created by Zheng on 28/06/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEMoreAddressCell.h"

@interface XXTEMoreAddressCell ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *guideWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *rightConstraint;

@end

@implementation XXTEMoreAddressCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.addressLabel.textColor = [UIColor blackColor];
    
    UIView *selectionBackground = [[UIView alloc] init];
    selectionBackground.backgroundColor = XXTColorCellSelected();
    self.selectedBackgroundView = selectionBackground;
    
    if (XXTE_IS_IPHONE_6_BELOW) {
        self.guideWidthConstraint.constant = 0.0;
        self.rightConstraint.constant = 0.0;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (@available(iOS 8.0, *)) {
        
    } else {
        XXTEAutoLabel *label = self.addressLabel;
        CGFloat boundsWidth = CGRectGetWidth(label.bounds);
        if (label.preferredMaxLayoutWidth != boundsWidth) {
            label.preferredMaxLayoutWidth = boundsWidth;
            [label setNeedsUpdateConstraints];
        }
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
