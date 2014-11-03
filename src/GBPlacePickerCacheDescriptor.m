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

#import "GBPlacePickerCacheDescriptor.h"

#import "GBGraphObjectPagingLoader.h"
#import "GBGraphObjectTableDataSource.h"
#import "GBPlacePickerViewController+Internal.h"
#import "GBPlacePickerViewController.h"

@interface GBPlacePickerCacheDescriptor () <GBGraphObjectPagingLoaderDelegate>

@property (nonatomic, readwrite) CLLocationCoordinate2D locationCoordinate;
@property (nonatomic, readwrite) NSInteger radiusInMeters;
@property (nonatomic, readwrite) NSInteger resultsLimit;
@property (nonatomic, readwrite, copy) NSString *searchText;
@property (nonatomic, readwrite, copy) NSSet *fieldsForRequest;
@property (nonatomic, readwrite, retain) GBGraphObjectPagingLoader *loader;

// this property is only used by unit tests, and should not be removed or made public
@property (nonatomic, readwrite, assign) BOOL hasCompletedFetch;

@end

@implementation GBPlacePickerCacheDescriptor

@synthesize locationCoordinate = _locationCoordinate,
            radiusInMeters = _radiusInMeters,
            resultsLimit = _resultsLimit,
            searchText = _searchText,
            fieldsForRequest = _fieldsForRequest,
            loader = _loader,
            hasCompletedFetch = _hasCompletedFetch;

- (id)initWithLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate
                  radiusInMeters:(NSInteger)radiusInMeters
                      searchText:(NSString*)searchText
                    resultsLimit:(NSInteger)resultsLimit
                fieldsForRequest:(NSSet*)fieldsForRequest {
    self = [super init];
    if (self) {
        self.locationCoordinate = locationCoordinate;
        self.radiusInMeters = radiusInMeters <= 0 ? defaultRadius : radiusInMeters;
        self.searchText = searchText;
        self.resultsLimit = resultsLimit <= 0 ? defaultResultsLimit : resultsLimit;
        self.fieldsForRequest = fieldsForRequest;
        self.hasCompletedFetch = NO;
    }
    return self;
}

- (void)dealloc {
    self.fieldsForRequest = nil;
    self.searchText = nil;
    self.loader = nil;
    [super dealloc];
}

- (void)prefetchAndCacheForSession:(GBSession*)session {
    // Place queries require a session, so do nothing if we don't have one.
    if (session == nil) {
        return;
    }

    // datasource has some field ownership, so we need one here
    GBGraphObjectTableDataSource *datasource = [[[GBGraphObjectTableDataSource alloc] init] autorelease];

    // create the request object that we will start with
    GBRequest *request = [GBPlacePickerViewController requestForPlacesSearchAtCoordinate:self.locationCoordinate
                                                                          radiusInMeters:self.radiusInMeters
                                                                            resultsLimit:self.resultsLimit
                                                                              searchText:self.searchText
                                                                                  fields:self.fieldsForRequest
                                                                              datasource:datasource
                                                                                 session:session];

    self.loader.delegate = nil;
    self.loader = [[[GBGraphObjectPagingLoader alloc] initWithDataSource:datasource
                                                              pagingMode:GBGraphObjectPagingModeAsNeeded]
                   autorelease];
    self.loader.session = session;
    self.loader.delegate = self;

    // make sure we are around to handle the delegate call
    [self retain];

    // seed the cache
    [self.loader startLoadingWithRequest:request
                           cacheIdentity:GBPlacePickerCacheIdentity
                   skipRoundtripIfCached:NO];
}

- (void)pagingLoaderDidFinishLoading:(GBGraphObjectPagingLoader *)pagingLoader {
    self.loader.delegate = nil;
    self.loader = nil;
    self.hasCompletedFetch = YES;

    // achieving detachment
    [self release];
}

@end