//
//  XXTExplorerViewController+UITableViewDropDelegate.m
//  XXTExplorer
//
//  Created by Zheng on 2018/5/14.
//  Copyright © 2018 Zheng. All rights reserved.
//

#import "XXTExplorerViewController+UITableViewDropDelegate.h"
#import "XXTExplorerViewController+SharedInstance.h"
#import "XXTExplorerEntryParser.h"

#import <sys/stat.h>
#import <MobileCoreServices/MobileCoreServices.h>

@implementation XXTExplorerViewController (UITableViewDropDelegate)

XXTE_START_IGNORE_PARTIAL
- (BOOL)tableView:(UITableView *)tableView canHandleDropSession:(id<UIDropSession>)session {
    return YES;
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    
    UITableViewDropProposal *cancelProp = [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    
    if (destinationIndexPath.section != XXTExplorerViewSectionIndexList) {
        return cancelProp;
    }
    
    XXTExplorerEntry *destinationEntry = nil;
    NSUInteger destIndex = destinationIndexPath.row;
    if (destIndex < self.entryList.count) {
        destinationEntry = self.entryList[destinationIndexPath.row];
    }
    
    UIDropOperation dropOperation = UIDropOperationCancel;
    UITableViewDropIntent dropIntent = UITableViewDropIntentAutomatic;
    if (tableView.hasActiveDrag)
    { // local drag
        if (destinationEntry && destinationEntry.isMaskedDirectory)
        {
            dropOperation = UIDropOperationMove;
            dropIntent = UITableViewDropIntentInsertIntoDestinationIndexPath;
        }
        else
        {
            dropOperation = UIDropOperationCancel;
        }
    }
    else
    {
        dropOperation = UIDropOperationCopy;
        if (destinationEntry && destinationEntry.isMaskedDirectory)
            dropIntent = UITableViewDropIntentInsertIntoDestinationIndexPath;
        else
            dropIntent = UITableViewDropIntentInsertAtDestinationIndexPath;
    }
    
    return [[UITableViewDropProposal alloc] initWithDropOperation:dropOperation intent:dropIntent];
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator
{
    
    NSIndexPath *destinationIndexPath = coordinator.destinationIndexPath;
    if (!coordinator.destinationIndexPath) {
        NSUInteger row = [tableView numberOfRowsInSection:XXTExplorerViewSectionIndexList];
        destinationIndexPath = [NSIndexPath indexPathForRow:row inSection:XXTExplorerViewSectionIndexList];
    }
    
    XXTExplorerEntry *destinationEntry = nil;
    NSUInteger destIndex = destinationIndexPath.row;
    if (destIndex < self.entryList.count) {
        destinationEntry = self.entryList[destinationIndexPath.row];
    }
    
    BOOL isMove = (coordinator.proposal.operation == UIDropOperationMove);
    BOOL isInto = (destinationEntry && destinationEntry.isMaskedDirectory);
    
    NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
    NSMutableArray <NSIndexPath *> *indexPathsToRemove = [[NSMutableArray alloc] init];
    NSString *parentPath = nil;
    if (isInto) {
        parentPath = destinationEntry.entryPath;
    } else {
        parentPath = self.entryPath;
    }
    
    NSMutableArray <XXTExplorerEntry *> *entryList = self.entryList;
    XXTExplorerEntryParser *parser = [[self class] explorerEntryParser];
    NSFileManager *manager = [[NSFileManager alloc] init];
    
    NSMutableArray <XXTExplorerEntry *> *entries = [[NSMutableArray alloc] init];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    NSMutableArray <NSIndexPath *> *indexPaths = [[NSMutableArray alloc] init];
    
    dispatch_group_t group = dispatch_group_create();
    [coordinator.items enumerateObjectsUsingBlock:^(id<UITableViewDropItem>  _Nonnull dropItem, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(group);
        UIDragItem *dragItem = dropItem.dragItem;
        [dragItem.itemProvider loadFileRepresentationForTypeIdentifier:(NSString *)kUTTypeItem completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
            NSString *path = [url path];
            if (path)
            {
                NSString *itemComponent = [path lastPathComponent];
                NSString *itemName = [itemComponent stringByDeletingPathExtension];
                NSString *itemExtension = [itemComponent pathExtension];
                NSString *itemDot = @".";
                if (itemExtension.length == 0) {
                    itemDot = @"";
                }
                
                NSString *testItemComponent = [NSString stringWithFormat:@"%@%@%@", itemName, itemDot, itemExtension];
                NSString *testItemPath = [parentPath stringByAppendingPathComponent:testItemComponent];
                
                NSUInteger testIndex = 2;
                struct stat testStat;
                while (0 == lstat(testItemPath.fileSystemRepresentation, &testStat))
                {
                    testItemComponent = [NSString stringWithFormat:@"%@-%lu%@%@", itemName, (unsigned long) testIndex, itemDot, itemExtension];
                    testItemPath = [parentPath stringByAppendingPathComponent:testItemComponent];
                    testIndex++;
                }
                
                BOOL writeResult = NO;
                if (isMove) {
                    writeResult = [manager moveItemAtPath:path toPath:testItemPath error:nil];
                } else {
                    writeResult = [manager copyItemAtPath:path toPath:testItemPath error:nil];
                }
                if (writeResult)
                {
                    XXTExplorerEntry *entry = [parser entryOfPath:testItemPath withError:nil];
                    if (entry)
                    {
                        NSUInteger targetIdx = (destinationIndexPath.row + idx);
                        [indexes addIndex:targetIdx];
                        [entries addObject:entry];
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:targetIdx inSection:XXTExplorerViewSectionIndexList];
                        [indexPaths addObject:indexPath];
                        
                        if (isMove) {
                            NSIndexPath *sourceIndexPath = dropItem.sourceIndexPath;
                            if (sourceIndexPath &&
                                sourceIndexPath.section == XXTExplorerViewSectionIndexList)
                            {
                                NSUInteger srcIndex = sourceIndexPath.row;
                                if (srcIndex >= entryList.count) {
                                    return;
                                }
                                XXTExplorerEntry *sourceEntry = entryList[srcIndex];
                                BOOL removeResult = [manager removeItemAtPath:sourceEntry.entryPath error:nil];
                                if (removeResult)
                                {
                                    [indexesToRemove addIndex:srcIndex];
                                    [indexPathsToRemove addObject:sourceIndexPath];
                                }
                            }
                        }
                    }
                }
                
            }
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (isInto) {
            if (isMove) {
                // remove current paths
                [entryList removeObjectsAtIndexes:[indexesToRemove copy]];
                [tableView deleteRowsAtIndexPaths:[indexPathsToRemove copy] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else {
                // copy, do nothing
            }
        } else {
            if (isMove) {
                // move rows, left empty
            } else {
                // insert new paths
                [entryList insertObjects:entries atIndexes:[indexes copy]];
                [tableView insertRowsAtIndexPaths:[indexPaths copy] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    });
}
XXTE_END_IGNORE_PARTIAL

@end
