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
#import "GBSessionAppEventsState.h"
#import "GBSystemAccountStoreAdapter.h"

extern NSString *const GBLoginUXClientState;
extern NSString *const GBLoginUXClientStateIsClientState;
extern NSString *const GBLoginUXClientStateIsOpenSession;
extern NSString *const GBLoginUXClientStateIsActiveSession;
extern NSString *const GBLoginUXResponseTypeToken;
extern NSString *const GBLoginUXResponseType;

extern NSString *const GBInnerErrorObjectKey;
extern NSString *const GBSessionDidSetActiveSessionNotificationUserInfoIsOpening;
extern NSString *const GbombNativeApplicationLoginDomain;

@interface GBSession (Internal)

@property (readonly) GBSessionDefaultAudience lastRequestedSystemAudience;
@property (readonly, retain) GBSessionAppEventsState *appEventsState;
@property (readonly) NSThread *affinitizedThread;
@property (atomic, readonly) BOOL isRepairing;

- (void)refreshAccessToken:(NSString*)token expirationDate:(NSDate*)expireDate;
- (BOOL)shouldExtendAccessToken;
- (BOOL)shouldRefreshPermissions;
- (void)refreshPermissions:(NSArray *)permissions;
- (void)closeAndClearTokenInformation:(NSError*) error;
- (void)clearAffinitizedThread;

+ (GBSession*)activeSessionIfExists;

+ (GBSession*)activeSessionIfOpen;

- (NSError*)errorLoginFailedWithReason:(NSString*)errorReason
                             errorCode:(NSString*)errorCode
                            innerError:(NSError*)innerError;

- (BOOL)openFromAccessTokenData:(GBAccessTokenData *)accessTokenData
              completionHandler:(GBSessionStateHandler) handler
   raiseExceptionIfInvalidState:(BOOL)raiseException;

+ (NSError *)sdkSurfacedErrorForNativeLoginError:(NSError *)nativeLoginError;

- (void)repairWithHandler:(GBSessionRequestPermissionResultHandler) handler;

+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                            allowLoginUI:(BOOL)allowLoginUI
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                       completionHandler:(GBSessionStateHandler)handler;

+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                           loginBehavior:(GBSessionLoginBehavior)loginBehavior
                                  isRead:(BOOL)isRead
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                       completionHandler:(GBSessionStateHandler)handler;
@end
