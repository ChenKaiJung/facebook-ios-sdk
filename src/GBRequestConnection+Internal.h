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

#import "GBRequestConnection.h"
#import "GBRequestMetadata.h"

@class GBRequestConnectionRetryManager;

@interface GBRequestConnection (Internal)

@property (nonatomic, readonly) BOOL isResultFromCache;
@property (nonatomic, readonly) NSMutableArray *requests;
@property (nonatomic, readonly) GBRequestConnectionRetryManager *retryManager;

- (id)initWithMetadata:(NSArray *)metadataArray;

- (void)startWithCacheIdentity:(NSString*)cacheIdentity
         skipRoundtripIfCached:(BOOL)consultCache;

- (GBRequestMetadata *) getRequestMetadata:(GBRequest *)request;

@end
