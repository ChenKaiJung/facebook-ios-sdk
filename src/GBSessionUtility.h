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

// An internal only utility class for logic related
// to GBSession but are not directly related to a session instance.
@interface GBSessionUtility : NSObject

+ (BOOL)isOpenSessionResponseURL:(NSURL *)url;
+ (NSDictionary *)clientStateFromQueryParams:(NSDictionary *)params;
+ (NSDictionary *)queryParamsFromLoginURL:(NSURL *)url
                                    appID:(NSString *)appID
                          urlSchemeSuffix:(NSString *)urlSchemeSuffix;
+ (NSString *)sessionStateDescription:(GBSessionState)sessionState;
+ (void)addWebLoginStartTimeToParams:(NSMutableDictionary *)params;
+ (NSDate *)expirationDateFromResponseParams:(NSDictionary *)parameters;
+ (BOOL)areRequiredPermissions:(NSArray*)requiredPermissions
          aSubsetOfPermissions:(NSArray*)cachedPermissions;
+ (void)validateRequestForPermissions:(NSArray*)permissions
                      defaultAudience:(GBSessionDefaultAudience)defaultAudience
                   allowSystemAccount:(BOOL)allowSystemAccount
                               isRead:(BOOL)isRead;
@end
