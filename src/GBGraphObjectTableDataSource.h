/*
 * Copyright 2010-present Facebook.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <UIKit/UIKit.h>

#import "FBGraphObject.h"

@protocol GBGraphObjectViewControllerDelegate;
@protocol GBGraphObjectSelectionQueryDelegate;
@protocol GBGraphObjectDataSourceDataNeededDelegate;
@class GBGraphObjectTableCell;

@interface GBGraphObjectTableDataSource : NSObject<UITableViewDataSource>

@property (nonatomic, retain) UIImage *defaultPicture;
@property (nonatomic, assign) id<GBGraphObjectViewControllerDelegate> controllerDelegate;
@property (nonatomic, copy) NSString *groupByField;
@property (nonatomic, assign) BOOL useCollation;
@property (nonatomic) BOOL itemTitleSuffixEnabled;
@property (nonatomic) BOOL itemPicturesEnabled;
@property (nonatomic) BOOL itemSubtitleEnabled;
@property (nonatomic, assign) id<GBGraphObjectSelectionQueryDelegate> selectionDelegate;
@property (nonatomic, assign) id<GBGraphObjectDataSourceDataNeededDelegate> dataNeededDelegate;
@property (nonatomic, copy) NSArray *sortDescriptors;

- (NSString *)fieldsForRequestIncluding:(NSSet *)customFields, ...;

- (void)setSortingBySingleField:(NSString*)fieldName ascending:(BOOL)ascending;
- (void)setSortingByFields:(NSArray*)fieldNames ascending:(BOOL)ascending;

- (void)prepareForNewRequest;
// Clears all graph objects from the data source.
- (void)clearGraphObjects;
// Adds additional graph objects (pass nil to indicate all objects have been added).
- (void)appendGraphObjects:(NSArray *)data;
- (BOOL)hasGraphObjects;

- (void)bindTableView:(UITableView *)tableView;

- (void)cancelPendingRequests;

// Call this when updating any property or if
// delegate.filterIncludesItem would return a different answer now.
- (void)update;

// Returns the graph object at a given indexPath.
- (GBGraphObject *)itemAtIndexPath:(NSIndexPath *)indexPath;

// Returns the indexPath for a given graph object.
- (NSIndexPath *)indexPathForItem:(GBGraphObject *)item;

@end

@protocol GBGraphObjectViewControllerDelegate <NSObject>
@required

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                             titleOfItem:(id<GBGraphObject>)graphObject;

@optional

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                       titleSuffixOfItem:(id<GBGraphObject>)graphObject;

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                          subtitleOfItem:(id<GBGraphObject>)graphObject;

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                        pictureUrlOfItem:(id<GBGraphObject>)graphObject;

- (BOOL)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                filterIncludesItem:(id<GBGraphObject>)item;

- (void)graphObjectTableDataSource:(GBGraphObjectTableDataSource*)dataSource
                customizeTableCell:(GBGraphObjectTableCell*)cell;

@end

@protocol GBGraphObjectSelectionQueryDelegate <NSObject>

- (BOOL)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
             selectionIncludesItem:(id<GBGraphObject>)item;

@end

@protocol GBGraphObjectDataSourceDataNeededDelegate <NSObject>

- (void)graphObjectTableDataSourceNeedsData:(GBGraphObjectTableDataSource *)dataSource triggeredByIndexPath:(NSIndexPath*)indexPath;

@end
