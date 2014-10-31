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

#import "GbombSDK.h"

// A category on GBSession to declare members that GBSessionLoginStrategy
// implementations needs access to (aka "friend" access).
@interface GBSession (GBSessionLoginStrategy)

- (void)authorizeUsingSystemAccountStore:(NSArray*)permissions
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                           isReauthorize:(BOOL)isReauthorize;
- (GBAppCall *)authorizeUsingFacebookNativeLoginWithPermissions:(NSArray*)permissions
                                                defaultAudience:(GBSessionDefaultAudience)defaultAudience
                                                    clientState:(NSDictionary *)clientState;
- (BOOL)isURLSchemeRegistered;
- (NSString *)jsonClientStateWithDictionary:(NSDictionary *)dictionary;
- (void)retryableAuthorizeWithPermissions:(NSArray*)permissions
                          defaultAudience:(GBSessionDefaultAudience)defaultAudience
                           integratedAuth:(BOOL)tryIntegratedAuth
                                GBAppAuth:(BOOL)tryGBAppAuth
                               safariAuth:(BOOL)trySafariAuth
                                 fallback:(BOOL)tryFallback
                            isReauthorize:(BOOL)isReauthorize
                      canFetchAppSettings:(BOOL)canFetchAppSettings;
- (BOOL)authorizeUsingFacebookApplication:(NSMutableDictionary *)params;
- (BOOL)authorizeUsingSafari:(NSMutableDictionary *)params;
- (void)setLoginTypeOfPendingOpenUrlCallback:(GBSessionLoginType) loginType;
- (void)authorizeUsingLoginDialog:(NSMutableDictionary *)params;

@end

