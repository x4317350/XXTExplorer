//
//  XXTExplorerViewController.h
//  XXTExplorer
//
//  Created by Zheng on 25/05/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XXTExplorerDefaults.h"

typedef enum : NSUInteger {
    XXTExplorerViewSectionIndexHome = 0,
    XXTExplorerViewSectionIndexList,
    XXTExplorerViewSectionIndexMax
} XXTExplorerViewSectionIndex;

@class XXTExplorerToolbar, XXTExplorerFooterView;

@interface XXTExplorerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>

@property (nonatomic, copy, readonly) NSString *entryPath;

@property (nonatomic, copy, readonly) NSMutableArray <NSDictionary *> *entryList;
@property (nonatomic, copy, readonly) NSMutableArray <NSDictionary *> *homeEntryList;

@property (nonatomic, assign) XXTExplorerViewEntryListSortField explorerSortField;
@property (nonatomic, assign) XXTExplorerViewEntryListSortOrder explorerSortOrder;

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, strong, readonly) UIRefreshControl *refreshControl;
@property (nonatomic, strong, readonly) XXTExplorerFooterView *footerView;

#pragma mark - toolbar

@property (nonatomic, strong) XXTExplorerToolbar *toolbar;

#pragma mark - status

@property (nonatomic, assign) BOOL busyOperationProgressFlag;

#pragma mark - init

- (instancetype)initWithEntryPath:(NSString *)path;

#pragma mark - reload

- (void)loadEntryListData;
- (void)refreshEntryListView:(UIRefreshControl *)refreshControl;
- (void)reconfigureCellAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForEntryAtPath:(NSString *)entryPath;

#pragma mark - picker

- (BOOL)showsHomeSeries;
- (BOOL)shouldDisplayEntry:(NSDictionary *)entryAttributes;

#pragma mark - fast open

- (void)performViewerActionForEntry:(NSDictionary *)entryAttributes;

@end
