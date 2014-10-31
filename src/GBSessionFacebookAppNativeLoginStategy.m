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

#import "GBSessionFacebookAppNativeLoginStategy.h"

#import "GBLogger.h"
#import "GBSession+Internal.h"
#import "GBSessionAuthLogger.h"
#import "GBSessionLoginStrategy.h"
#import "GBUtility.h"

@implementation GBSessionFacebookAppNativeLoginStategy

- (BOOL)tryPerformAuthorizeWithParams:(GBSessionLoginStrategyParams *)params session:(GBSession *)session logger:(GBSessionAuthLogger *)logger {
    if (params.tryGBAppAuth) {
        GBFetchedAppSettings *fetchedSettings = [GBUtility fetchedAppSettings];
        [logger addExtrasForNextEvent:@{
         @"hasFetchedAppSettings": @(fetchedSettings != nil),
         @"pListFacebookDisplayName": [GBSettings defaultDisplayName] ?: @"<missing>"
         }];
        if ([GBSettings defaultDisplayName] &&            // don't autoselect Native Login unless the app has been setup for it,
            [session.appID isEqualToString:[GBSettings defaultAppID]] && // If the appId has been overridden, then the bridge cannot be used and native login is denied
            (fetchedSettings || params.canFetchAppSettings) &&   // and we have app-settings available to us, or could fetch if needed
            !TEST_DISABLE_FACEBOOKNATIVELOGIN) {
            if (!fetchedSettings) {
                // fetch the settings and call the session auth method again.
                [GBUtility fetchAppSettings:[GBSettings defaultAppID] callback:^(GBFetchedAppSettings * settings, NSError * error) {
                    [session retryableAuthorizeWithPermissions:params.permissions
                                               defaultAudience:params.defaultAudience
                                                integratedAuth:params.tryIntegratedAuth
                                                     GBAppAuth:params.tryGBAppAuth
                                                    safariAuth:params.trySafariAuth
                                                      fallback:params.tryFallback
                                                 isReauthorize:params.isReauthorize
                                           canFetchAppSettings:NO];
                }];
                return YES;
            } else {
                [logger addExtrasForNextEvent:@{
                 @"suppressNativeGdp": @(fetchedSettings.suppressNativeGdp),
                 @"serverAppName": fetchedSettings.serverAppName ?: @"<missing>"
                 }];
                if (!fetchedSettings.suppressNativeGdp) {
                    if (![[GBSettings defaultDisplayName] isEqualToString:fetchedSettings.serverAppName]) {
                        [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors
                                            logEntry:@"PLIST entry for FacebookDisplayName does not match Facebook app name."];
                        [logger addExtrasForNextEvent:@{
                         @"nameMismatch": @(YES)
                         }];
                    }

                    NSDictionary *clientState = @{GBSessionAuthLoggerParamAuthMethodKey: self.methodName,
                                                  GBSessionAuthLoggerParamIDKey : logger.ID ?: @""};

                    GBAppCall *call = [session authorizeUsingFacebookNativeLoginWithPermissions:params.permissions
                                                                                defaultAudience:params.defaultAudience
                                                                                    clientState:clientState];
                    if (call) {
                        [logger addExtrasForNextEvent:@{
                         @"native_auth_appcall_id":call.ID
                         }];

                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}

- (NSString *)methodName {
    return GBSessionAuthLoggerAuthMethodGBApplicationNative;
}

@end
