//
// Created by Zheng on 26/07/2017.
// Copyright (c) 2017 Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XXTEViewer.h"

@class XUITheme, XUIAdapter;

@interface XUIViewController : UIViewController <XXTEViewer>

@property (nonatomic, strong) XUITheme *theme;
@property (nonatomic, strong) XUIAdapter *adapter;

@end
