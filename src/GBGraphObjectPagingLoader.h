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

#import <Foundation/Foundation.h>

#import "GBGraphObjectTableDataSource.h"

@class GBRequest;
@class GBSession;
@protocol GBGraphObjectPagingLoaderDelegate;

typedef enum {
    // Paging links will be followed as soon as one set of results is loaded
    GBGraphObjectPagingModeImmediate,
    // Paging links will be followed as soon as one set of results is loaded, even without a view
    GBGraphObjectPagingModeImmediateViewless,
    // Paging links will be followed only when the user scrolls to the bottom of the table
    GBGraphObjectPagingModeAsNeeded
} GBGraphObjectPagingMode;

@interface GBGraphObjectPagingLoader : NSObject<GBGraphObjectDataSourceDataNeededDelegate>

@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) GBGraphObjectTableDataSource *dataSource;
@property (nonatomic, retain) GBSession *session;
@property (nonatomic, assign) id<GBGraphObjectPagingLoaderDelegate> delegate;
@property (nonatomic, readonly) GBGraphObjectPagingMode pagingMode;
@property (nonatomic, readonly) BOOL isResultFromCache;

- (id)initWithDataSource:(GBGraphObjectTableDataSource*)aDataSource
              pagingMode:(GBGraphObjectPagingMode)pagingMode;
- (void)startLoadingWithRequest:(GBRequest*)request
                  cacheIdentity:(NSString*)cacheIdentity
          skipRoundtripIfCached:(BOOL)skipRoundtripIfCached;
- (void)addResultsAndUpdateView:(NSDictionary*)results;
- (void)cancel;
- (void)reset;

@end

@protocol GBGraphObjectPagingLoaderDelegate <NSObject>

@optional

- (void)pagingLoader:(GBGraphObjectPagingLoader*)pagingLoader willLoadURL:(NSString*)url;
- (void)pagingLoader:(GBGraphObjectPagingLoader*)pagingLoader didLoadData:(NSDictionary*)results;
- (void)pagingLoaderDidFinishLoading:(GBGraphObjectPagingLoader*)pagingLoader;
- (void)pagingLoader:(GBGraphObjectPagingLoader*)pagingLoader handleError:(NSError*)error;
- (void)pagingLoaderWasCancelled:(GBGraphObjectPagingLoader*)pagingLoader;

@end
