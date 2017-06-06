//
//  XXTExplorerViewController.m
//  XXTExplorer
//
//  Created by Zheng on 25/05/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import <sys/stat.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "XXTExplorerEntryParser.h"
#import "XXTExplorerViewController.h"
#import "XXTExplorerHeaderView.h"
#import "XXTExplorerFooterView.h"
#import "XXTExplorerViewCell.h"
#import "XXTExplorerViewHomeCell.h"
#import "XXTExplorerDefaults.h"
#import "XXTExplorerToolbar.h"
#import "XXTENotificationCenterDefines.h"
#import "UIView+XXTEToast.h"
#import <LGAlertView/LGAlertView.h>
#import "XXTEDispatchDefines.h"
#import "zip.h"

typedef enum : NSUInteger {
    XXTExplorerViewSectionIndexHome = 0,
    XXTExplorerViewSectionIndexList,
    XXTExplorerViewSectionIndexMax
} XXTExplorerViewSectionIndex;

#define XXTEDefaultsBool(key) ([[self.class.explorerDefaults objectForKey:key] boolValue])
#define XXTEDefaultsEnum(key) ([[self.class.explorerDefaults objectForKey:key] unsignedIntegerValue])
#define XXTEDefaultsObject(key) ([self.class.explorerDefaults objectForKey:key])
#define XXTEDefaultsSetBasic(key, value) ([self.class.explorerDefaults setObject:@(value) forKey:key])
#define XXTEDefaultsSetObject(key, obj) ([self.class.explorerDefaults setObject:obj forKey:key])
#define XXTEBuiltInDefaultsBool(key) ([[self.class.explorerBuiltInDefaults objectForKey:key] boolValue])
#define XXTEBuiltInDefaultsEnum(key) ([[self.class.explorerBuiltInDefaults objectForKey:key] unsignedIntegerValue])
#define XXTEBuiltInDefaultsObject(key) ([self.class.explorerBuiltInDefaults objectForKey:key])

@interface XXTExplorerViewController () <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, XXTExplorerToolbarDelegate, XXTESwipeTableCellDelegate, LGAlertViewDelegate>

@property (nonatomic, copy, readonly) NSArray <NSDictionary *> *entryList;
@property (nonatomic, copy, readonly) NSArray <NSDictionary *> *homeEntryList;

@property (nonatomic, strong, readonly) XXTExplorerToolbar *toolbar;
@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, strong, readonly) UIRefreshControl *refreshControl;
@property (nonatomic, strong, readonly) XXTExplorerFooterView *footerView;

@end

@implementation XXTExplorerViewController

+ (UIPasteboard *)explorerPasteboard {
    static UIPasteboard *explorerPasteboard = nil;
    if (!explorerPasteboard) {
        explorerPasteboard = ({
            [UIPasteboard pasteboardWithName:XXTExplorerPasteboardName create:YES];
        });
    }
    return explorerPasteboard;
}

+ (NSString *)rootPath {
    static NSString *rootPath = nil;
    if (!rootPath) {
        rootPath = ({
            [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        });
    }
    return rootPath;
}

+ (NSFileManager *)explorerFileManager {
    static NSFileManager *explorerFileManager = nil;
    if (!explorerFileManager) {
        explorerFileManager = ({
            [[NSFileManager alloc] init];
        });
    }
    return explorerFileManager;
}

+ (NSDateFormatter *)explorerDateFormatter {
    static NSDateFormatter *explorerDateFormatter = nil;
    if (!explorerDateFormatter) {
        explorerDateFormatter = ({
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            dateFormatter;
        });
    }
    return explorerDateFormatter;
}

+ (NSUserDefaults *)explorerDefaults {
    static NSUserDefaults *explorerDefaults = nil;
    if (!explorerDefaults) {
        explorerDefaults = ({
            [NSUserDefaults standardUserDefaults];
        });
    }
    return explorerDefaults;
}

+ (NSDictionary *)explorerBuiltInDefaults {
    static NSDictionary *explorerBuiltInDefaults = nil;
    if (!explorerBuiltInDefaults) {
        explorerBuiltInDefaults = ({
            NSString *builtInDefaultsPath = [[NSBundle mainBundle] pathForResource:@"XXTExplorerBuiltInDefaults" ofType:@"plist"];
            [[NSDictionary alloc] initWithContentsOfFile:builtInDefaultsPath];
        });
    }
    return explorerBuiltInDefaults;
}

+ (XXTExplorerEntryParser *)explorerEntryParser {
    static XXTExplorerEntryParser *explorerEntryParser = nil;
    if (!explorerEntryParser) {
        explorerEntryParser = [[XXTExplorerEntryParser alloc] init];
    }
    return explorerEntryParser;
}

#pragma mark - Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         
     } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         
     }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma mark - UIViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setupWithPath:nil];
    }
    return self;
}

- (instancetype)initWithEntryPath:(NSString *)path {
    if (self = [super init]) {
        [self setupWithPath:path];
    }
    return self;
}

- (void)setupWithPath:(NSString *)path {
    {
        NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"XXTExplorerDefaults" ofType:@"plist"];
        NSDictionary *defaults = [[NSDictionary alloc] initWithContentsOfFile:defaultsPath];
        for (NSString *defaultKey in defaults) {
            if (![self.class.explorerDefaults objectForKey:defaultKey])
            {
                [self.class.explorerDefaults setObject:defaults[defaultKey] forKey:defaultKey];
            }
        }
    }
    {
        if (!path) {
            NSString *initialRelativePath = XXTEBuiltInDefaultsObject(XXTExplorerViewInitialPath);
            NSString *initialPath = [[[self class] rootPath] stringByAppendingPathComponent:initialRelativePath];
            if (![self.class.explorerFileManager fileExistsAtPath:initialPath]) {
                assert(mkdir([initialPath UTF8String], 0755) == 0);
            }
            path = initialPath;
        }
        _entryPath = path;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    if (self == self.navigationController.viewControllers[0]) {
        self.title = NSLocalizedString(@"My Scripts", nil);
    } else {
        self.title = [self.entryPath lastPathComponent];
    }
    
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    _tableView = ({
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44.f, self.view.bounds.size.width, self.view.bounds.size.height - 44.f) style:UITableViewStylePlain];
        tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.allowsSelection = YES;
        tableView.allowsMultipleSelection = NO;
        tableView.allowsSelectionDuringEditing = YES;
        tableView.allowsMultipleSelectionDuringEditing = YES;
        XXTE_START_IGNORE_PARTIAL
        if (XXTE_SYSTEM_9) {
            tableView.cellLayoutMarginsFollowReadableWidth = NO;
        }
        XXTE_END_IGNORE_PARTIAL
        [tableView registerNib:[UINib nibWithNibName:NSStringFromClass([XXTExplorerViewCell class]) bundle:[NSBundle mainBundle]] forCellReuseIdentifier:XXTExplorerViewCellReuseIdentifier];
        [tableView registerNib:[UINib nibWithNibName:NSStringFromClass([XXTExplorerViewHomeCell class]) bundle:[NSBundle mainBundle]] forCellReuseIdentifier:XXTExplorerViewHomeCellReuseIdentifier];
        tableView;
    });
    
    [self.view addSubview:self.tableView];
    
    _toolbar = ({
        XXTExplorerToolbar *toolbar = [[XXTExplorerToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.f)];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        toolbar.tapDelegate = self;
        toolbar;
    });
    [self.view addSubview:self.toolbar];
    
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;
    _refreshControl = ({
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refreshEntryListView:) forControlEvents:UIControlEventValueChanged];
        [tableViewController setRefreshControl:refreshControl];
        refreshControl;
    });
    [self.tableView.backgroundView insertSubview:self.refreshControl atIndex:0];
    
    _footerView = ({
        XXTExplorerFooterView *entryFooterView = [[XXTExplorerFooterView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 48.f)];
        entryFooterView;
    });
    [self.tableView setTableFooterView:self.footerView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationNotification:) name:XXTENotificationEvent object:nil];
    [self updateToolbarButton:self.toolbar];
    [self updateToolbarStatus:self.toolbar];
    [self loadEntryListData];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([self isEditing]) {
        [self setEditing:NO animated:YES];
    }
}

#pragma mark - UINotification

- (void)handleApplicationNotification:(NSNotification *)aNotification {
    NSDictionary *userInfo = aNotification.userInfo;
    NSString *eventType = userInfo[XXTENotificationEventType];
    if ([eventType isEqualToString:XXTENotificationEventTypeInboxMoved]) {
        [self loadEntryListData];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:XXTExplorerViewSectionIndexList] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - XXTExplorerToolbar

- (void)updateToolbarButton:(XXTExplorerToolbar *)toolbar {
    if (XXTEDefaultsEnum(XXTExplorerViewEntryListSortOrderKey) == XXTExplorerViewEntryListSortOrderAsc)
    {
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypeSort status:XXTExplorerToolbarButtonStatusNormal enabled:YES];
    }
    else
    {
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypeSort status:XXTExplorerToolbarButtonStatusSelected enabled:YES];
    }
}

- (void)updateToolbarStatus:(XXTExplorerToolbar *)toolbar {
    if ([[[self class] explorerPasteboard] strings].count > 0) {
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypePaste enabled:YES];
    }
    else
    {
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypePaste enabled:NO];
    }
    if ([self isEditing])
    {
        if (([self.tableView indexPathsForSelectedRows].count) > 0)
        {
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypeShare enabled:YES];
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypeCompress enabled:YES];
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypeTrash enabled:YES];
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypePaste enabled:YES];
        }
        else
        {
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypeShare enabled:NO];
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypeCompress enabled:NO];
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypeTrash enabled:NO];
            [toolbar updateButtonType:XXTExplorerToolbarButtonTypePaste enabled:NO];
        }
    }
    else
    {
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypeScan enabled:YES];
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypeAddItem enabled:YES];
        [toolbar updateButtonType:XXTExplorerToolbarButtonTypeSort enabled:YES];
    }
}

#pragma mark - NSFileManager

- (void)loadEntryListDataWithError:(NSError **)error
{
    {
        if (XXTEDefaultsBool(XXTExplorerViewSectionHomeEnabledKey) &&
            self == self.navigationController.viewControllers[0]) {
            _homeEntryList = XXTEBuiltInDefaultsObject(XXTExplorerViewSectionHomeSeriesKey);
        }
    }
    
    _entryList = ({
        BOOL hidesDot = XXTEDefaultsBool(XXTExplorerViewEntryListHideDotItemKey);
        NSError *localError = nil;
        NSArray <NSString *> *entrySubdirectoryPathList = [self.class.explorerFileManager contentsOfDirectoryAtPath:self.entryPath error:&localError];
        if (localError && error) *error = localError;
        NSMutableArray <NSDictionary *> *entryDirectoryAttributesList = [[NSMutableArray alloc] init];
        NSMutableArray <NSDictionary *> *entryOtherAttributesList = [[NSMutableArray alloc] init];
        for (NSString *entrySubdirectoryName in entrySubdirectoryPathList)
        {
            if (hidesDot && [entrySubdirectoryName hasPrefix:@"."]) {
                continue;
            }
            NSString *entrySubdirectoryPath = [self.entryPath stringByAppendingPathComponent:entrySubdirectoryName];
            NSDictionary *entryAttributes = [self.class.explorerEntryParser entryOfPath:entrySubdirectoryPath withError:&localError];
            if (localError && error)
            {
                *error = localError;
                break;
            }
            // TODO: Parse each entry using XXTExplorerEntryExtensions
            if ([entryAttributes[XXTExplorerViewEntryAttributeMaskType] isEqualToString:XXTExplorerViewEntryAttributeTypeDirectory])
            {
                [entryDirectoryAttributesList addObject:entryAttributes];
            }
            else
            {
                [entryOtherAttributesList addObject:entryAttributes];
            }
        }
        NSString *sortField = XXTEDefaultsObject(XXTExplorerViewEntryListSortFieldKey);
        NSUInteger sortOrder = XXTEDefaultsEnum(XXTExplorerViewEntryListSortOrderKey);
        NSComparator comparator = ^NSComparisonResult(NSDictionary * _Nonnull obj1, NSDictionary * _Nonnull obj2)
        {
            return (sortOrder == XXTExplorerViewEntryListSortOrderAsc) ? [obj1[sortField] compare:obj2[sortField]] : [obj2[sortField] compare:obj1[sortField]];
        };
        [entryDirectoryAttributesList sortUsingComparator:comparator];
        [entryOtherAttributesList sortUsingComparator:comparator];
        
        NSMutableArray <NSDictionary *> *entryAttributesList = [[NSMutableArray alloc] initWithCapacity:entrySubdirectoryPathList.count];
        [entryAttributesList addObjectsFromArray:entryDirectoryAttributesList];
        [entryAttributesList addObjectsFromArray:entryOtherAttributesList];
        entryAttributesList;
    });
    if (error && *error) _entryList = @[]; // clean entry list if error exists
    
    NSUInteger itemCount = self.entryList.count;
    NSString *itemCountString = nil;
    if (itemCount == 0) {
        itemCountString = NSLocalizedString(@"No item", nil);
    } else if (itemCount == 1) {
        itemCountString = NSLocalizedString(@"1 item", nil);
    } else  {
        itemCountString = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), (unsigned long)itemCount];
    }
    NSString *usageString = nil;
    NSError *usageError = nil;
    NSDictionary *fileSystemAttributes = [self.class.explorerFileManager attributesOfFileSystemForPath:self.class.rootPath error:&usageError];
    if (!usageError) {
        NSNumber *deviceFreeSpace = fileSystemAttributes[NSFileSystemFreeSize];
        if (deviceFreeSpace) {
            usageString = [NSByteCountFormatter stringFromByteCount:[deviceFreeSpace unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile];
        }
    }
    NSString *finalFooterString = [NSString stringWithFormat:NSLocalizedString(@"%@, %@ free", nil), itemCountString, usageString];
    [self.footerView.footerLabel setText:finalFooterString];
}

- (void)loadEntryListData
{
    NSError *entryLoadError = nil;
    [self loadEntryListDataWithError:&entryLoadError];
    if (entryLoadError) {
        [self.navigationController.view makeToast:[entryLoadError localizedDescription]];
    }
}

- (void)refreshEntryListView:(UIRefreshControl *)refreshControl {
    [self loadEntryListData];
    [self.tableView reloadData];
    if ([refreshControl isRefreshing]) {
        [refreshControl endRefreshing];
    }
}

#pragma mark - UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section)
        {
            return YES;
        }
    }
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            return indexPath;
        } else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            return indexPath;
        }
    }
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            if ([tableView isEditing]) {
                [self updateToolbarStatus:self.toolbar];
            }
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section)
        {
            if ([tableView isEditing]) {
                [self updateToolbarStatus:self.toolbar];
            } else {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                NSDictionary *entryAttributes = self.entryList[indexPath.row];
                if ([entryAttributes[XXTExplorerViewEntryAttributeMaskType] isEqualToString:XXTExplorerViewEntryAttributeTypeBundle]) {
                    
                }
                else if ([entryAttributes[XXTExplorerViewEntryAttributeMaskType] isEqualToString:XXTExplorerViewEntryAttributeTypeDirectory])
                { // Directory or Symbolic Link Directory
                    NSString *directoryPath = entryAttributes[XXTExplorerViewEntryAttributePath];
                    // We'd better try to access it before we enter it.
                    NSError *accessError = nil;
                    [self.class.explorerFileManager contentsOfDirectoryAtPath:directoryPath error:&accessError];
                    if (accessError) {
                        [self.navigationController.view makeToast:[accessError localizedDescription]];
                    }
                    else {
                        XXTExplorerViewController *explorerViewController = [[XXTExplorerViewController alloc] initWithEntryPath:directoryPath];
                        [self.navigationController pushViewController:explorerViewController animated:YES];
                    }
                }
                else if ([entryAttributes[XXTExplorerViewEntryAttributeMaskType] isEqualToString:XXTExplorerViewEntryAttributeTypeRegular])
                {
                    NSString *internalExt = entryAttributes[XXTExplorerViewEntryAttributeInternalExtension];
                    if ([internalExt isEqualToString:XXTExplorerViewEntryAttributeInternalExtensionArchive])
                    {
                        [self tableView:tableView archiveEntryTappedForRowWithIndexPath:indexPath];
                    }
                    else if ([internalExt isEqualToString:XXTExplorerViewEntryAttributeInternalExtensionExecutable])
                    {
                        // TODO: Server Select
                    }
                    else
                    {
                        
                    }
                }
                else
                {
                    [self.navigationController.view makeToast:NSLocalizedString(@"Only regular file, directory and symbolic link are supported.", nil)];
                }
            }
        }
        else if (XXTExplorerViewSectionIndexHome == indexPath.section)
        {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            if ([tableView isEditing]) {
                
            } else {
                NSDictionary *entryAttributes = self.homeEntryList[indexPath.row];
                NSString *directoryRelativePath = entryAttributes[XXTExplorerViewSectionHomeSeriesDetailPathKey];
                NSString *directoryPath = [[[self class] rootPath] stringByAppendingPathComponent:directoryRelativePath];
                NSError *accessError = nil;
                [self.class.explorerFileManager contentsOfDirectoryAtPath:directoryPath error:&accessError];
                if (accessError) {
                    [self.navigationController.view makeToast:[accessError localizedDescription]];
                }
                else {
                    XXTExplorerViewController *explorerViewController = [[XXTExplorerViewController alloc] initWithEntryPath:directoryPath];
                    [self.navigationController pushViewController:explorerViewController animated:YES];
                }
            }
        }
    }
}

- (void)tableView:(UITableView *)tableView archiveEntryTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *entryAttributes = self.entryList[indexPath.row];
    LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Unarchive Confirm", nil)
                                                        message:[NSString stringWithFormat:NSLocalizedString(@"Unarchive \"%@\" to current directory?", nil), entryAttributes[XXTExplorerViewEntryAttributeName]]
                                                          style:LGAlertViewStyleActionSheet
                                                   buttonTitles:@[  ]
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                         destructiveButtonTitle:NSLocalizedString(@"Confirm", nil)
                                                       delegate:self];
    objc_setAssociatedObject(alertView, @selector(alertView:unarchiveEntryAtIndexPath:), indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [alertView showAnimated:YES completionHandler:nil];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (![tableView isEditing]) {
            if (XXTExplorerViewSectionIndexList == indexPath.section) {
                XXTESwipeTableCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                [cell showSwipe:XXTESwipeDirectionLeftToRight animated:YES];
            }
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            return XXTExplorerViewCellHeight;
        }
        else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            return XXTExplorerViewHomeCellHeight;
        }
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == section) {
            return 24.f;
        } // Notice: assume that there will not be any headers for Home section
    }
    return 0;
}

/*
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == section) {
            return 48.f;
        } // Notice: assume that there will not be any headers for Home section
    }
    return 0;
}
*/


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == section) {
            XXTExplorerHeaderView *entryHeaderView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:XXTExplorerEntryHeaderViewReuseIdentifier];
            if (!entryHeaderView) {
                entryHeaderView = [[XXTExplorerHeaderView alloc] initWithReuseIdentifier:XXTExplorerEntryHeaderViewReuseIdentifier];
            }
            NSString *rootPath = [[self class] rootPath];
            NSRange rootRange = [self.entryPath rangeOfString:rootPath];
            if (rootRange.location == 0) {
                NSString *tiledPath = [self.entryPath stringByReplacingCharactersInRange:rootRange withString:@"~"];
                [entryHeaderView.headerLabel setText:tiledPath];
            } else {
                [entryHeaderView.headerLabel setText:self.entryPath];
            }
            return entryHeaderView;
        } // Notice: assume that there will not be any headers for Home section
    }
    return nil;
}

/*
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == section) {
            XXTExplorerFooterView *entryFooterView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:XXTExplorerEntryFooterViewReuseIdentifier];
            if (!entryFooterView) {
                entryFooterView = [[XXTExplorerFooterView alloc] initWithReuseIdentifier:XXTExplorerEntryFooterViewReuseIdentifier];
            }
            NSUInteger itemCount = self.entryList.count;
            NSString *itemCountString = nil;
            if (itemCount == 0) {
                itemCountString = NSLocalizedString(@"No item", nil);
            } else if (itemCount == 1) {
                itemCountString = NSLocalizedString(@"1 item", nil);
            } else  {
                itemCountString = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), (unsigned long)itemCount];
            }
            NSString *usageString = nil;
            NSError *usageError = nil;
            NSDictionary *fileSystemAttributes = [self.explorerFileManager attributesOfFileSystemForPath:self.entryPath error:&usageError];
            if (!usageError) {
                NSNumber *deviceFreeSpace = fileSystemAttributes[NSFileSystemFreeSize];
                if (deviceFreeSpace) {
                    usageString = [NSByteCountFormatter stringFromByteCount:[deviceFreeSpace unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile];
                }
            }
            NSString *finalFooterString = [NSString stringWithFormat:NSLocalizedString(@"%@, %@ free", nil), itemCountString, usageString];
            [entryFooterView.footerLabel setText:finalFooterString];
            return entryFooterView;
        } // Notice: assume that there will not be any footer for Home section
    }
    return nil;
}
*/

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.tableView) {
        return XXTExplorerViewSectionIndexMax;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexHome == section) {
            return self.homeEntryList.count;
        }
        else if (XXTExplorerViewSectionIndexList == section) {
            return self.entryList.count;
        }
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.tableView) {
        if (XXTExplorerViewSectionIndexList == indexPath.section) {
            XXTExplorerViewCell *entryCell = [tableView dequeueReusableCellWithIdentifier:XXTExplorerViewCellReuseIdentifier];
            if (!entryCell) {
                entryCell = [[XXTExplorerViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:XXTExplorerViewCellReuseIdentifier];
            }
            entryCell.delegate = self;
            entryCell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            entryCell.entryIconImageView.image = self.entryList[indexPath.row][XXTExplorerViewEntryAttributeIconImage];
            entryCell.entryTitleLabel.text = self.entryList[indexPath.row][XXTExplorerViewEntryAttributeName];
            entryCell.entrySubtitleLabel.text = [self.class.explorerDateFormatter stringFromDate:self.entryList[indexPath.row][XXTExplorerViewEntryAttributeCreationDate]];
            UILongPressGestureRecognizer *cellLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(entryCellDidLongPress:)];
            cellLongPressGesture.delegate = self;
            [entryCell addGestureRecognizer:cellLongPressGesture];
            return entryCell;
        }
        else if (XXTExplorerViewSectionIndexHome == indexPath.section) {
            XXTExplorerViewHomeCell *entryCell = [tableView dequeueReusableCellWithIdentifier:XXTExplorerViewHomeCellReuseIdentifier];
            if (!entryCell) {
                entryCell = [[XXTExplorerViewHomeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:XXTExplorerViewHomeCellReuseIdentifier];
            }
            entryCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            entryCell.entryIconImageView.image = [UIImage imageNamed:self.homeEntryList[indexPath.row][XXTExplorerViewSectionHomeSeriesDetailIconKey]];
            entryCell.entryTitleLabel.text = self.homeEntryList[indexPath.row][XXTExplorerViewSectionHomeSeriesDetailTitleKey];
            entryCell.entrySubtitleLabel.text = self.homeEntryList[indexPath.row][XXTExplorerViewSectionHomeSeriesDetailSubtitleKey];
            return entryCell;
        }
    }
    return [UITableViewCell new];
}

#pragma mark - UILongPressGestureRecognizer

- (void)entryCellDidLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (![self isEditing] && recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [recognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
        [self setEditing:YES animated:YES];
        if (self.tableView.delegate) {
            [self.tableView.delegate tableView:self.tableView willSelectRowAtIndexPath:indexPath];
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
            [self.tableView.delegate tableView:self.tableView didSelectRowAtIndexPath:indexPath];
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return (!self.isEditing);
}

#pragma mark - XXTExplorerToolbarDelegate

- (void)toolbar:(XXTExplorerToolbar *)toolbar buttonTypeTapped:(NSString *)buttonType {
    if (toolbar == self.toolbar) {
        if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypeScan])
        {
            
        }
        else if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypeAddItem])
        {
            
        }
        else if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypeSort])
        {
            if (XXTEDefaultsEnum(XXTExplorerViewEntryListSortOrderKey) != XXTExplorerViewEntryListSortOrderAsc)
            {
                XXTEDefaultsSetBasic(XXTExplorerViewEntryListSortOrderKey, XXTExplorerViewEntryListSortOrderAsc);
                XXTEDefaultsSetObject(XXTExplorerViewEntryListSortFieldKey, XXTExplorerViewEntryAttributeName);
            }
            else
            {
                XXTEDefaultsSetBasic(XXTExplorerViewEntryListSortOrderKey, XXTExplorerViewEntryListSortOrderDesc);
                XXTEDefaultsSetObject(XXTExplorerViewEntryListSortFieldKey, XXTExplorerViewEntryAttributeCreationDate);
            }
            [self updateToolbarButton:self.toolbar];
            [self loadEntryListData];
            [self.tableView reloadData];
        }
        else if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypePaste])
        {
            NSArray <NSIndexPath *> *selectedIndexPaths = [self.tableView indexPathsForSelectedRows];
            if (!selectedIndexPaths) {
                selectedIndexPaths = @[];
            }
            NSString *formatString = nil;
            if (selectedIndexPaths.count == 1) {
                NSIndexPath *firstIndexPath = selectedIndexPaths[0];
                NSDictionary *firstAttributes = self.entryList[firstIndexPath.row];
                formatString = [NSString stringWithFormat:NSLocalizedString(@"\"%@\"", nil), firstAttributes[XXTExplorerViewEntryAttributeName]];
            } else {
                formatString = [NSString stringWithFormat:NSLocalizedString(@"%d items", nil), selectedIndexPaths.count];
            }
            BOOL clearEnabled = NO;
            NSArray <NSString *> *pasteboardArray = [self.class.explorerPasteboard strings];
            NSUInteger pasteboardCount = pasteboardArray.count;
            NSString *pasteboardFormatString = nil;
            if (pasteboardCount == 0)
            {
                pasteboardFormatString = NSLocalizedString(@"No item", nil);
                clearEnabled = NO;
            }
            else
            {
                if (pasteboardCount == 1) {
                    pasteboardFormatString = NSLocalizedString(@"1 item", nil);
                } else {
                    pasteboardFormatString = [NSString stringWithFormat:NSLocalizedString(@"%d items", nil), pasteboardCount];
                }
                clearEnabled = YES;
            }
            if ([self isEditing])
            {
                LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Pasteboard", nil)
                                                                    message:[NSString stringWithFormat:NSLocalizedString(@"%@ stored.", nil), pasteboardFormatString]
                                                                      style:LGAlertViewStyleActionSheet
                                                               buttonTitles:@[
                                                                              [NSString stringWithFormat:@"Copy %@", formatString]
                                                                              ]
                                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                     destructiveButtonTitle:NSLocalizedString(@"Clear Pasteboard", nil)
                                                                   delegate:self];
                alertView.destructiveButtonEnabled = clearEnabled;
                alertView.buttonsIconImages = @[ [UIImage imageNamed:XXTExplorerAlertViewActionPasteboardExportCopy] ];
                objc_setAssociatedObject(alertView, [XXTExplorerAlertViewAction UTF8String], XXTExplorerAlertViewActionPasteboardImport, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(alertView, [XXTExplorerAlertViewContext UTF8String], selectedIndexPaths, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(alertView, @selector(alertView:clearPasteboardEntriesStored:), selectedIndexPaths, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [alertView showAnimated];
            }
            else
            {
                NSString *entryName = [self.entryPath lastPathComponent];
                LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Pasteboard", nil)
                                                                    message:[NSString stringWithFormat:NSLocalizedString(@"%@ stored.", nil), pasteboardFormatString]
                                                                      style:LGAlertViewStyleActionSheet
                                                               buttonTitles:@[
                                                                              [NSString stringWithFormat:@"Paste to \"%@\"", entryName],
                                                                              [NSString stringWithFormat:@"Move to \"%@\"", entryName],
                                                                              [NSString stringWithFormat:@"Create Link at \"%@\"", entryName]
                                                                              ]
                                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                     destructiveButtonTitle:NSLocalizedString(@"Clear Pasteboard", nil)
                                                                   delegate:self];
                alertView.destructiveButtonEnabled = clearEnabled;
                alertView.buttonsEnabled = (pasteboardCount != 0);
                alertView.buttonsIconImages = @[ [UIImage imageNamed:XXTExplorerAlertViewActionPasteboardExportPaste], [UIImage imageNamed:XXTExplorerAlertViewActionPasteboardExportCut], [UIImage imageNamed:XXTExplorerAlertViewActionPasteboardExportLink] ];
                objc_setAssociatedObject(alertView, [XXTExplorerAlertViewAction UTF8String], XXTExplorerAlertViewActionPasteboardExport, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(alertView, [XXTExplorerAlertViewContext UTF8String], self.entryPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(alertView, @selector(alertView:clearPasteboardEntriesStored:), selectedIndexPaths, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [alertView showAnimated];
            }
        }
        else if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypeCompress])
        {
            NSArray <NSIndexPath *> *selectedIndexPaths = [self.tableView indexPathsForSelectedRows];
            NSString *formatString = nil;
            if (selectedIndexPaths.count == 1) {
                NSIndexPath *firstIndexPath = selectedIndexPaths[0];
                NSDictionary *firstAttributes = self.entryList[firstIndexPath.row];
                formatString = [NSString stringWithFormat:@"\"%@\"", firstAttributes[XXTExplorerViewEntryAttributeName]];
            } else {
                formatString = [NSString stringWithFormat:NSLocalizedString(@"%d items", nil), selectedIndexPaths.count];
            }
            LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Archive Confirm", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"Archive %@?", nil), formatString]
                                                                  style:LGAlertViewStyleActionSheet
                                                           buttonTitles:@[  ]
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                 destructiveButtonTitle:NSLocalizedString(@"Confirm", nil)
                                                               delegate:self];
            objc_setAssociatedObject(alertView, @selector(alertView:archiveEntriesAtIndexPaths:), selectedIndexPaths, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [alertView showAnimated:YES completionHandler:nil];
        }
        else if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypeShare])
        {
            
        }
        else if ([buttonType isEqualToString:XXTExplorerToolbarButtonTypeTrash])
        {
            NSArray <NSIndexPath *> *selectedIndexPaths = [self.tableView indexPathsForSelectedRows];
            NSString *formatString = nil;
            if (selectedIndexPaths.count == 1) {
                NSIndexPath *firstIndexPath = selectedIndexPaths[0];
                NSDictionary *firstAttributes = self.entryList[firstIndexPath.row];
                formatString = [NSString stringWithFormat:@"\"%@\"", firstAttributes[XXTExplorerViewEntryAttributeName]];
            } else {
                formatString = [NSString stringWithFormat:NSLocalizedString(@"%d items", nil), selectedIndexPaths.count];
            }
            LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Delete Confirm", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"Delete %@?\nThis operation cannot be revoked.", nil), formatString]
                                                                  style:LGAlertViewStyleActionSheet
                                                           buttonTitles:@[  ]
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                 destructiveButtonTitle:NSLocalizedString(@"Confirm", nil)
                                                               delegate:self];
            objc_setAssociatedObject(alertView, @selector(alertView:removeEntriesAtIndexPaths:), selectedIndexPaths, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [alertView showAnimated:YES completionHandler:nil];
        }
    }
}

#pragma mark - UIViewController (UIViewControllerEditing)

- (BOOL)isEditing {
    return [self.tableView isEditing];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    if (editing) {
        [self.toolbar updateStatus:XXTExplorerToolbarStatusEditing];
    }
    else
    {
        [self.toolbar updateStatus:XXTExplorerToolbarStatusDefault];
    }
    [self updateToolbarStatus:self.toolbar];
}

#pragma mark - XXTESwipeTableCellDelegate

- (BOOL)swipeTableCell:(XXTESwipeTableCell *) cell canSwipe:(XXTESwipeDirection) direction fromPoint:(CGPoint) point {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSDictionary *entryDetail = self.entryList[indexPath.row];
    if (entryDetail) {
        return YES;
    }
    return NO;
}

- (BOOL)swipeTableCell:(XXTESwipeTableCell *) cell tappedButtonAtIndex:(NSInteger)index direction:(XXTESwipeDirection)direction fromExpansion:(BOOL)fromExpansion {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSDictionary *entryDetail = self.entryList[indexPath.row];
    if (direction == XXTESwipeDirectionLeftToRight)
    {
        
    }
    else if (direction == XXTESwipeDirectionRightToLeft)
    {
        LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Delete Confirm", nil)
                                                            message:[NSString stringWithFormat:NSLocalizedString(@"Delete \"%@\"?\nThis operation cannot be revoked.", nil), entryDetail[XXTExplorerViewEntryAttributeName]]
                                                              style:LGAlertViewStyleActionSheet
                                                       buttonTitles:@[  ]
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                             destructiveButtonTitle:NSLocalizedString(@"Confirm", nil)
                                                           delegate:self];
        objc_setAssociatedObject(alertView, @selector(alertView:removeEntryCell:), cell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [alertView showAnimated:YES completionHandler:nil];
    }
    return NO;
}

- (NSArray *)swipeTableCell:(XXTESwipeTableCell *)cell swipeButtonsForDirection:(XXTESwipeDirection)direction
             swipeSettings:(XXTESwipeSettings *)swipeSettings expansionSettings:(XXTESwipeExpansionSettings *)expansionSettings {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSDictionary *entryDetail = self.entryList[indexPath.row];
    if (direction == XXTESwipeDirectionLeftToRight)
    {
        NSMutableArray *swipeButtons = [[NSMutableArray alloc] init];
        
        if (YES == [entryDetail[XXTExplorerViewEntryAttributePermission] containsObject:XXTExplorerViewEntryAttributePermissionExecuteable])
        {
            XXTESwipeButton *swipeLaunchButton = [XXTESwipeButton buttonWithTitle:nil icon:[UIImage imageNamed:@"XXTExplorerActionIconLaunch"]
                                                                  backgroundColor:[XXTE_COLOR colorWithAlphaComponent:1.f]
                                                                           insets:UIEdgeInsetsMake(0, 24, 0, 24)];
            [swipeButtons addObject:swipeLaunchButton];
        }
        if (YES == [entryDetail[XXTExplorerViewEntryAttributePermission] containsObject:XXTExplorerViewEntryAttributePermissionEditable]
            && [entryDetail[XXTExplorerViewEntryAttributeType] isEqualToString:XXTExplorerViewEntryAttributeTypeRegular])
        {
            XXTESwipeButton *swipeEditButton = [XXTESwipeButton buttonWithTitle:nil icon:[UIImage imageNamed:@"XXTExplorerActionIconEdit"]
                                                                backgroundColor:[XXTE_COLOR colorWithAlphaComponent:.8f]
                                                                         insets:UIEdgeInsetsMake(0, 24, 0, 24)];
            [swipeButtons addObject:swipeEditButton];
        }
        XXTESwipeButton *swipePropertyButton = [XXTESwipeButton buttonWithTitle:nil icon:[UIImage imageNamed:@"XXTExplorerActionIconProperty"]
                                                                backgroundColor:[XXTE_COLOR colorWithAlphaComponent:.6f]
                                                                         insets:UIEdgeInsetsMake(0, 24, 0, 24)];
        [swipeButtons addObject:swipePropertyButton];
        return swipeButtons;
    }
    else if (direction == XXTESwipeDirectionRightToLeft)
    {
        XXTESwipeButton *swipeTrashButton = [XXTESwipeButton buttonWithTitle:nil icon:[UIImage imageNamed:@"XXTExplorerActionIconTrash"]
                                                             backgroundColor:XXTE_DANGER_COLOR
                                                                      insets:UIEdgeInsetsMake(0, 24, 0, 24)];
        return @[ swipeTrashButton ];
    }
    return @[];
}

#pragma mark - LGAlertViewDelegate

- (void)alertView:(LGAlertView *)alertView clickedButtonAtIndex:(NSUInteger)index title:(NSString *)title {
    NSString *action = objc_getAssociatedObject(alertView, [XXTExplorerAlertViewAction UTF8String]);
    id obj = objc_getAssociatedObject(alertView, [XXTExplorerAlertViewContext UTF8String]);
    if (action) {
        objc_setAssociatedObject(alertView, [XXTExplorerAlertViewAction UTF8String], nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(alertView, [XXTExplorerAlertViewContext UTF8String], nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if ([action isEqualToString:XXTExplorerAlertViewActionPasteboardImport])
        {
            if (index == 0)
            {
                [self alertView:alertView copyPasteboardItemsAtIndexPaths:obj];
            }
        }
        else if ([action isEqualToString:XXTExplorerAlertViewActionPasteboardExport])
        {
            if (index == 0)
            {
                [self alertView:alertView pastePasteboardItemsAtPath:obj];
            }
            else if (index == 1)
            {
                [self alertView:alertView movePasteboardItemsAtPath:obj];
            }
            else if (index == 2)
            {
                [self alertView:alertView symlinkPasteboardItemsAtPath:obj];
            }
        }
    }
    objc_removeAssociatedObjects(alertView);
}

- (void)alertView:(LGAlertView *)alertView copyPasteboardItemsAtIndexPaths:(NSArray <NSIndexPath *> *)indexPaths {
    NSMutableArray <NSString *> *selectedEntryPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        [selectedEntryPaths addObject:self.entryList[indexPath.row][XXTExplorerViewEntryAttributePath]];
    }
    [self.class.explorerPasteboard setStrings:[[NSArray alloc] initWithArray:selectedEntryPaths]];
    [alertView dismissAnimated];
    [self setEditing:NO animated:YES];
}

- (void)alertView:(LGAlertView *)alertView movePasteboardItemsAtPath:(NSString *)path {
    
}

- (void)alertView:(LGAlertView *)alertView pastePasteboardItemsAtPath:(NSString *)path {
    
}

- (void)alertView:(LGAlertView *)alertView symlinkPasteboardItemsAtPath:(NSString *)path {
    
}

- (void)alertViewDestructed:(LGAlertView *)alertView {
    SEL selectors[] = {
        @selector(alertView:removeEntryCell:),
        @selector(alertView:removeEntriesAtIndexPaths:),
        @selector(alertView:archiveEntriesAtIndexPaths:),
        @selector(alertView:unarchiveEntryAtIndexPath:),
        @selector(alertView:clearPasteboardEntriesStored:)
    };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    for (int i = 0; i < sizeof(selectors) / sizeof(SEL); i++) {
        SEL selector = selectors[i];
        id obj = objc_getAssociatedObject(alertView, selector);
        if (obj) {
            objc_setAssociatedObject(alertView, selector, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self performSelector:selector withObject:alertView withObject:obj];
            break;
        }
    }
    objc_removeAssociatedObjects(alertView);
#pragma clang diagnostic pop
}

- (void)alertViewCancelled:(LGAlertView *)alertView {
    objc_removeAssociatedObjects(alertView);
    [alertView dismissAnimated];
}

- (void)alertView:(LGAlertView *)alertView removeEntryCell:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSDictionary *entryDetail = self.entryList[indexPath.row];
    NSString *entryPath = entryDetail[XXTExplorerViewEntryAttributePath];
    NSString *entryName = entryDetail[XXTExplorerViewEntryAttributeName];
    NSUInteger entryCount = 1;
    LGAlertView *alertView1 = [[LGAlertView alloc] initWithActivityIndicatorAndTitle:NSLocalizedString(@"Delete", nil)
                                                                            message:[NSString stringWithFormat:NSLocalizedString(@"Deleting \"%@\"", nil), entryName]
                                                                              style:LGAlertViewStyleActionSheet
                                                                  progressLabelText:entryPath
                                                                       buttonTitles:nil
                                                                  cancelButtonTitle:nil
                                                             destructiveButtonTitle:nil
                                                                           delegate:self];
    if (alertView && alertView.isShowing) {
        [alertView transitionToAlertView:alertView1 completionHandler:nil];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSError *error = nil;
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSMutableArray <NSString *> *recursiveSubpaths = [[NSMutableArray alloc] initWithObjects:entryPath, nil];
            while (recursiveSubpaths.count != 0) {
                if (error != nil) {
                    break;
                }
                NSString *enumPath = [recursiveSubpaths lastObject];
                dispatch_async_on_main_queue(^{
                    alertView1.progressLabelText = enumPath;
                });
                [recursiveSubpaths removeLastObject];
                BOOL isDirectory = NO;
                if ([fileManager fileExistsAtPath:enumPath isDirectory:&isDirectory]) {
                    if (isDirectory) {
                        NSArray <NSString *> *groupSubpaths = [fileManager contentsOfDirectoryAtPath:enumPath error:&error];
                        if (groupSubpaths.count == 0) {
                            
                        } else {
                            NSMutableArray <NSString *> *groupSubpathsAppended = [[NSMutableArray alloc] initWithCapacity:groupSubpaths.count];
                            for (NSString *groupSubpath in groupSubpaths) {
                                [groupSubpathsAppended addObject:[enumPath stringByAppendingPathComponent:groupSubpath]];
                            }
                            [recursiveSubpaths addObject:enumPath];
                            [recursiveSubpaths addObjectsFromArray:groupSubpathsAppended];
                            continue;
                        }
                    }
                    [fileManager removeItemAtPath:enumPath error:&error];
                }
            }
            NSMutableArray <NSIndexPath *> *deletedPaths = [[NSMutableArray alloc] initWithCapacity:entryCount];
            if ([fileManager fileExistsAtPath:entryPath] == NO) {
                [deletedPaths addObject:indexPath];
            }
            dispatch_async_on_main_queue(^{
                [alertView1 dismissAnimated];
                if (error == nil) {
                    [self loadEntryListData];
                    [self.tableView beginUpdates];
                    [self.tableView deleteRowsAtIndexPaths:deletedPaths withRowAnimation:UITableViewRowAnimationFade];
                    [self.tableView endUpdates];
                } else {
                    [self.navigationController.view makeToast:[error localizedDescription]];
                }
            });
        });
    });
}

- (void)alertView:(LGAlertView *)alertView removeEntriesAtIndexPaths:(NSArray <NSIndexPath *> *)indexPaths {
    NSMutableArray <NSString *> *entryPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        [entryPaths addObject:self.entryList[indexPath.row][XXTExplorerViewEntryAttributePath]];
    }
    NSUInteger entryCount = entryPaths.count;
    NSString *entryDisplayName = nil;
    if (entryCount == 1) {
        entryDisplayName = [NSString stringWithFormat:@"\"%@\"", [entryPaths[0] lastPathComponent]];
    } else {
        entryDisplayName = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), entryPaths.count];
    }
    LGAlertView *alertView1 = [[LGAlertView alloc] initWithActivityIndicatorAndTitle:NSLocalizedString(@"Delete", nil)
                                                                             message:[NSString stringWithFormat:NSLocalizedString(@"Deleting %@", nil), entryDisplayName]
                                                                               style:LGAlertViewStyleActionSheet
                                                                   progressLabelText:@"..."
                                                                        buttonTitles:nil
                                                                   cancelButtonTitle:nil
                                                              destructiveButtonTitle:nil
                                                                            delegate:self];
    if (alertView && alertView.isShowing) {
        [alertView transitionToAlertView:alertView1 completionHandler:nil];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSError *error = nil;
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSMutableArray <NSString *> *recursiveSubpaths = [[NSMutableArray alloc] initWithArray:entryPaths];
            while (recursiveSubpaths.count != 0) {
                if (error != nil) {
                    break;
                }
                NSString *enumPath = [recursiveSubpaths lastObject];
                dispatch_async_on_main_queue(^{
                    alertView1.progressLabelText = enumPath;
                });
                [recursiveSubpaths removeLastObject];
                BOOL isDirectory = NO;
                if ([fileManager fileExistsAtPath:enumPath isDirectory:&isDirectory]) {
                    if (isDirectory) {
                        NSArray <NSString *> *groupSubpaths = [fileManager contentsOfDirectoryAtPath:enumPath error:&error];
                        if (groupSubpaths.count == 0) {
                            
                        } else {
                            NSMutableArray <NSString *> *groupSubpathsAppended = [[NSMutableArray alloc] initWithCapacity:groupSubpaths.count];
                            for (NSString *groupSubpath in groupSubpaths) {
                                [groupSubpathsAppended addObject:[enumPath stringByAppendingPathComponent:groupSubpath]];
                            }
                            [recursiveSubpaths addObject:enumPath];
                            [recursiveSubpaths addObjectsFromArray:groupSubpathsAppended];
                            continue;
                        }
                    }
                    [fileManager removeItemAtPath:enumPath error:&error];
                }
            }
            NSMutableArray <NSIndexPath *> *deletedPaths = [[NSMutableArray alloc] initWithCapacity:entryCount];
            for (NSUInteger i = 0; i < entryPaths.count; i++) {
                NSString *entryPath = entryPaths[i];
                if ([fileManager fileExistsAtPath:entryPath] == NO) {
                    [deletedPaths addObject:indexPaths[i]];
                }
            }
            dispatch_async_on_main_queue(^{
                [alertView1 dismissAnimated];
                [self setEditing:NO animated:YES];
                [self loadEntryListData];
                [self.tableView beginUpdates];
                [self.tableView deleteRowsAtIndexPaths:deletedPaths withRowAnimation:UITableViewRowAnimationFade];
                [self.tableView endUpdates];
                if (error) {
                    [self.navigationController.view makeToast:[error localizedDescription]];
                }
            });
        });
    });
}

- (void)alertView:(LGAlertView *)alertView archiveEntriesAtIndexPaths:(NSArray <NSIndexPath *> *)indexPaths {
    NSString *currentPath = self.entryPath;
    NSMutableArray <NSString *> *entryNames = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        [entryNames addObject:self.entryList[indexPath.row][XXTExplorerViewEntryAttributeName]];
    }
    NSUInteger entryCount = entryNames.count;
    NSString *entryDisplayName = nil;
    NSString *archiveName = nil;
    if (entryCount == 1) {
        archiveName = entryNames[0];
        entryDisplayName = [NSString stringWithFormat:@"\"%@\"", archiveName];
    } else {
        archiveName = @"Archive";
        entryDisplayName = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), entryNames.count];
    }
    NSString *archiveNameWithExt = [NSString stringWithFormat:@"%@.zip", archiveName];
    NSString *archivePath = [currentPath stringByAppendingPathComponent:archiveNameWithExt];
    NSUInteger archiveIndex = 2;
    while ([self.class.explorerFileManager fileExistsAtPath:archivePath])
    {
        archiveNameWithExt = [NSString stringWithFormat:@"%@-%lu.zip", archiveName, archiveIndex];
        archivePath = [currentPath stringByAppendingPathComponent:archiveNameWithExt];
        archiveIndex++;
    }
    LGAlertView *alertView1 = [[LGAlertView alloc] initWithActivityIndicatorAndTitle:NSLocalizedString(@"Archive", nil)
                                                                             message:[NSString stringWithFormat:NSLocalizedString(@"Archive %@ to \"%@\"", nil), entryDisplayName, archiveNameWithExt]
                                                                               style:LGAlertViewStyleActionSheet
                                                                   progressLabelText:@"..."
                                                                        buttonTitles:nil
                                                                   cancelButtonTitle:nil
                                                              destructiveButtonTitle:nil
                                                                            delegate:self];
    if (alertView && alertView.isShowing) {
        [alertView transitionToAlertView:alertView1 completionHandler:nil];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSError *error = nil;
            struct zip_t *zip = zip_open([archivePath fileSystemRepresentation], ZIP_DEFAULT_COMPRESSION_LEVEL, 'w');
            BOOL result = (zip != NULL);
            if (result) {
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                NSMutableArray <NSString *> *recursiveSubnames = [[NSMutableArray alloc] initWithArray:entryNames];
                while (recursiveSubnames.count != 0) {
                    if (error != nil) {
                        break;
                    }
                    NSString *enumName = [recursiveSubnames lastObject];
                    NSString *enumPath = [currentPath stringByAppendingPathComponent:enumName];
                    dispatch_async_on_main_queue(^{
                        alertView1.progressLabelText = enumPath;
                    });
                    [recursiveSubnames removeLastObject];
                    BOOL isDirectory = NO;
                    if ([fileManager fileExistsAtPath:enumPath isDirectory:&isDirectory]) {
                        if (isDirectory) {
                            NSArray <NSString *> *groupSubnames = [fileManager contentsOfDirectoryAtPath:enumPath error:&error];
                            if (groupSubnames.count == 0) {
                                enumName = [enumName stringByAppendingString:@"/"];
                            } else {
                                NSMutableArray <NSString *> *groupSubnamesAppended = [[NSMutableArray alloc] initWithCapacity:groupSubnames.count];
                                for (NSString *groupSubname in groupSubnames) {
                                    [groupSubnamesAppended addObject:[enumName stringByAppendingPathComponent:groupSubname]];
                                }
                                [recursiveSubnames addObjectsFromArray:groupSubnamesAppended];
                                continue;
                            }
                        }
                        zip_entry_open(zip, [enumName fileSystemRepresentation]);
                        {
                            zip_entry_fwrite(zip, [enumPath fileSystemRepresentation]);
                        }
                        zip_entry_close(zip);
                    }
                }
                zip_close(zip);
            }
            else
            {
                error = [NSError errorWithDomain:NSPOSIXErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot create archive file \"%@\".", nil), archivePath] }];
            }
            dispatch_async_on_main_queue(^{
                [alertView1 dismissAnimated];
                [self setEditing:NO animated:YES];
                [self loadEntryListData];
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:XXTExplorerViewSectionIndexList] withRowAnimation:UITableViewRowAnimationFade];
                if (error) {
                    [self.navigationController.view makeToast:[error localizedDescription]];
                }
            });
        });
    });
}

- (void)alertView:(LGAlertView *)alertView unarchiveEntryAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *entryAttributes = self.entryList[indexPath.row];
    NSString *entryName = entryAttributes[XXTExplorerViewEntryAttributeName];
    NSString *entryPath = entryAttributes[XXTExplorerViewEntryAttributePath];
    NSString *destinationPath = [entryPath stringByDeletingPathExtension];
    NSString *destinationPathWithIndex = destinationPath;
    NSUInteger destinationIndex = 2;
    while ([self.class.explorerFileManager fileExistsAtPath:destinationPathWithIndex])
    {
        destinationPathWithIndex = [NSString stringWithFormat:@"%@-%lu", destinationPath, destinationIndex];
        destinationIndex++;
    }
    NSString *destinationName = [destinationPathWithIndex lastPathComponent];
    LGAlertView *alertView1 = [[LGAlertView alloc] initWithActivityIndicatorAndTitle:NSLocalizedString(@"Unarchive", nil)
                                                                             message:[NSString stringWithFormat:NSLocalizedString(@"Unarchiving \"%@\" to \"%@\"", nil), entryName, destinationName]
                                                                               style:LGAlertViewStyleActionSheet
                                                                   progressLabelText:entryPath
                                                                        buttonTitles:nil
                                                                   cancelButtonTitle:nil
                                                              destructiveButtonTitle:nil
                                                                            delegate:self];
    if (alertView && alertView.isShowing) {
        [alertView transitionToAlertView:alertView1 completionHandler:nil];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            BOOL result = NO;
            NSError *error = nil;
            result = (mkdir([destinationPathWithIndex fileSystemRepresentation], 0755) == 0);
            if (result) {
                int (^extract_callback)(const char *, void *) = ^int (const char *filename, void *arg)
                {
                    dispatch_sync_on_main_queue(^{
                        alertView1.progressLabelText = [NSString stringWithUTF8String:filename];
                    });
                    return 0;
                };
                int arg = 2;
                int status = zip_extract([entryPath fileSystemRepresentation], [destinationPathWithIndex fileSystemRepresentation], extract_callback, &arg);
                result = (status == 0);
                if (result) {
                    
                }
                else
                {
                    error = [NSError errorWithDomain:NSPOSIXErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot read archive file \"%@\".", nil), entryPath] }];
                }
            }
            else
            {
                error = [NSError errorWithDomain:NSPOSIXErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot create destination directory \"%@\".", nil), destinationPathWithIndex] }];
            }
            dispatch_async_on_main_queue(^{
                [alertView1 dismissAnimated];
                [self setEditing:NO animated:YES];
                [self loadEntryListData];
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:XXTExplorerViewSectionIndexList] withRowAnimation:UITableViewRowAnimationFade];
                if (error) {
                    [self.navigationController.view makeToast:[error localizedDescription]];
                }
            });
        });
    });
}

- (void)alertView:(LGAlertView *)alertView clearPasteboardEntriesStored:(NSArray <NSIndexPath *> *)indexPaths {
    [self.class.explorerPasteboard setStrings:@[]];
    [alertView dismissAnimated];
    [self updateToolbarStatus:self.toolbar];
}

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [XXTExplorerViewController dealloc]");
#endif
}

@end
