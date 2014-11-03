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

#import "GBSessionAppSwitchingLoginStategy.h"

#import "GBLogger.h"
#import "GBSession+Internal.h"
#import "GBSessionAuthLogger.h"
#import "GBSessionGbombAppNativeLoginStategy.h"
#import "GBSessionGbombAppWebLoginStategy.h"
#import "GBSessionLoginStrategy.h"
#import "GBSessionSafariLoginStategy.h"
#import "GBUtility.h"

// A composite login strategy that tries strategies that require app switching
// (e.g., native gdp, native web gdp, safari)
@interface GBSessionAppSwitchingLoginStategy()

@property (copy, nonatomic, readwrite) NSString *methodName;

@end

@implementation GBSessionAppSwitchingLoginStategy

- (id)init {
    if ((self = [super init])){
        self.methodName = GBSessionAuthLoggerAuthMethodGBApplicationNative;
    }
    return self;
}

- (void)dealloc {
    [_methodName release];
    [super dealloc];
}

- (BOOL)tryPerformAuthorizeWithParams:(GBSessionLoginStrategyParams *)params session:(GBSession *)session logger:(GBSessionAuthLogger *)logger {
    // if the device is running a version of iOS that supports multitasking,
    // try to obtain the access token from the Facebook app installed
    // on the device.
    // If the Facebook app isn't installed or it doesn't support
    // the fbauth:// URL scheme, fall back on Safari for obtaining the access token.
    // This minimizes the chance that the user will have to enter his or
    // her credentials in order to authorize the application.
    BOOL isMultitaskingSupported = [GBUtility isMultitaskingSupported];
    BOOL isURLSchemeRegistered = [session isURLSchemeRegistered];;

    [logger addExtrasForNextEvent:@{
     @"isMultitaskingSupported":@(isMultitaskingSupported),
     @"isURLSchemeRegistered":@(isURLSchemeRegistered)
     }];

    if (isMultitaskingSupported &&
        isURLSchemeRegistered &&
        !TEST_DISABLE_MULTITASKING_LOGIN) {

        NSArray *loginStrategies = @[ [[[GBSessionGbombAppNativeLoginStategy alloc] init] autorelease],
                                      [[[GBSessionGbombAppWebLoginStategy alloc] init] autorelease],
                                      [[[GBSessionSafariLoginStategy alloc] init] autorelease] ];

        for (id<GBSessionLoginStrategy> loginStrategy in loginStrategies) {

            if ([loginStrategy tryPerformAuthorizeWithParams:params session:session logger:logger]) {
                self.methodName = loginStrategy.methodName;
                return YES;
            }
        }

        [session setLoginTypeOfPendingOpenUrlCallback:GBSessionLoginTypeNone];
    }
    return NO;
}

@end
