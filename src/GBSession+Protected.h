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

#import "GBSession.h"

// Methods here are meant to be used only by internal subclasses of GBSession
// and not by any other classes, external or internal.
@interface GBSession (Protected)

// Permissions are technically associated with a GBAccessTokenData instance
// but we support initializing an GBSession before acquiring a token. This property
// tracks that initialized array so that the pass-through permissions property
// can essentially return self.GBAccessTokenData.permissions ?: self.initializedPermissions
@property (readonly, copy) NSArray *initializedPermissions;

- (BOOL)transitionToState:(GBSessionState)state
      withAccessTokenData:(GBAccessTokenData *)tokenData
              shouldCache:(BOOL)shouldCache;
- (void)transitionAndCallHandlerWithState:(GBSessionState)status
                                    error:(NSError*)error
                                tokenData:(GBAccessTokenData *)tokenData
                              shouldCache:(BOOL)shouldCache;
- (void)authorizeWithPermissions:(NSArray*)permissions
                        behavior:(GBSessionLoginBehavior)behavior
                 defaultAudience:(GBSessionDefaultAudience)audience
                   isReauthorize:(BOOL)isReauthorize;
- (BOOL)handleReauthorize:(NSDictionary*)parameters
              accessToken:(NSString*)accessToken;

@end
