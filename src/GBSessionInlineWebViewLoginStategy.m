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

#import "GBSessionInlineWebViewLoginStategy.h"

#import "GBLogger.h"
#import "GBSession+Internal.h"
#import "GBSessionAuthLogger.h"
#import "GBSessionLoginStrategy.h"
#import "GBUtility.h"

@implementation GBSessionInlineWebViewLoginStategy

- (BOOL)tryPerformAuthorizeWithParams:(GBSessionLoginStrategyParams *)params session:(GBSession *)session logger:(GBSessionAuthLogger *)logger {
    if (params.tryFallback) {
        NSDictionary *clientState = @{GBSessionAuthLoggerParamAuthMethodKey: self.methodName,
                                      GBSessionAuthLoggerParamIDKey : logger.ID ?: @""};
        params.webParams[GBLoginUXClientState] = [session jsonClientStateWithDictionary:clientState];
        [session authorizeUsingLoginDialog:params.webParams];
        return YES;
    }
    return NO;
}

- (NSString *)methodName {
    return GBSessionAuthLoggerAuthMethodFallback;
}

@end
