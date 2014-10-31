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

#import "GBCacheDescriptor.h"
#import "GBRequest.h"
#import "GBWebDialogs.h"

/*!
 @class GBFrictionlessRecipientCache

 @abstract
 Maintains a cache of friends that can recieve application requests from the user in
 using the frictionless feature of the requests web dialog.

 This class follows the `GBCacheDescriptor` pattern used elsewhere in the SDK, and applications may call
 one of the prefetchAndCacheForSession methods to fetch a friend list prior to the
 point where a dialog is presented. The cache is also updated with each presentation of the request
 dialog using the cache instance.
 */
@interface GBFrictionlessRecipientCache : GBCacheDescriptor<GBWebDialogsDelegate>

/*!
 @abstract
 Initializes an empty cache instance
 */
- (id)init;

/*! @abstract An array containing the list of known GBIDs for recipients enabled for frictionless requests */
@property (nonatomic, readwrite, copy) NSArray *recipientIDs;

/*!
 @abstract
 Checks to see if a given user or GBID for a user is known to be enabled for
 frictionless requestests

 @param user An NSString, NSNumber of `GBGraphUser` representing a user to check
 */
- (BOOL)isFrictionlessRecipient:(id)user;

/*!
 @abstract
 Checks to see if a collection of users or GBIDs for users are known to be enabled for
 frictionless requestests

 @param users An NSArray of NSString, NSNumber of `GBGraphUser` objects
 representing users to check
 */
- (BOOL)areFrictionlessRecipients:(NSArray*)users;

/*!
 @abstract
 Issues a request and fills the cache with a list of users to use for frictionless requests

 @param session The session to use for the request; nil indicates that the Active Session should
 be used
 */
- (void)prefetchAndCacheForSession:(GBSession *)session;

/*!
 @abstract
 Issues a request and fills the cache with a list of users to use for frictionless requests

 @param session The session to use for the request; nil indicates that the Active Session should
 be used

 @param handler An optional completion handler, called when the request for cached users has
 completed. It can be useful to use the handler to enable UI or perform other request-related
 operations, after the cache is populated.
 */
- (void)prefetchAndCacheForSession:(GBSession *)session
                 completionHandler:(GBRequestHandler)handler;

@end
