//
//  XXTEEditorController+Settings.h
//  XXTExplorer
//
//  Created by Zheng on 17/08/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XXTEEditorController.h"

@interface XXTEEditorController (Settings)

- (void)backButtonItemTapped:(UIBarButtonItem *)sender;

- (void)searchButtonItemTapped:(UIBarButtonItem *)sender;
- (void)symbolsButtonItemTapped:(UIBarButtonItem *)sender;
- (void)statisticsButtonItemTapped:(UIBarButtonItem *)sender;
- (void)settingsButtonItemTapped:(UIBarButtonItem *)sender;

- (BOOL)isSearchButtonItemAvailable;
- (BOOL)isSymbolsButtonItemAvailable;
- (BOOL)isStatisticsButtonItemAvailable;
- (BOOL)isSettingsButtonItemAvailable;

@end
