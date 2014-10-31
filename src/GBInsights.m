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

#import "GBInsights.h"

#import <UIKit/UIApplication.h>

#import "GBAppEvents+Internal.h"
#import "GBAppEvents.h"
#import "GBSettings.h"

// Constant needs to match GBAppEventsLoggingResultNotification.
NSString *const GBInsightsLoggingResultNotification = @"com.facebook.sdk:GBAppEventsLoggingResultNotification";

@interface GBInsights ()

@end

@implementation GBInsights

+ (NSString *)appVersion {
    return [GBSettings appVersion];
}

+ (void)setAppVersion:(NSString *)appVersion {
    [GBSettings setAppVersion:appVersion];
}

+ (void)logPurchase:(double)purchaseAmount currency:(NSString *)currency {
    [GBInsights logPurchase:purchaseAmount currency:currency parameters:nil];
}

+ (void)logPurchase:(double)purchaseAmount currency:(NSString *)currency parameters:(NSDictionary *)parameters {
    [GBInsights logPurchase:purchaseAmount currency:currency parameters:parameters session:nil];
}

+ (void)logPurchase:(double)purchaseAmount currency:(NSString *)currency parameters:(NSDictionary *)parameters session:(GBSession *)session {
    [GBAppEvents logPurchase:purchaseAmount currency:currency parameters:parameters session:session];
}

+ (void)logConversionPixel:(NSString *)pixelID valueOfPixel:(double)value {
    [GBInsights logConversionPixel:pixelID valueOfPixel:value session:nil];
}
+ (void)logConversionPixel:(NSString *)pixelID valueOfPixel:(double)value session:(GBSession *)session {
    [GBAppEvents logConversionPixel:pixelID valueOfPixel:value session:session];
}

+ (GBInsightsFlushBehavior)flushBehavior {
    return [GBAppEvents flushBehavior];
}

+ (void)setFlushBehavior:(GBInsightsFlushBehavior)flushBehavior {
    [GBAppEvents setFlushBehavior:flushBehavior];
}

+ (void)flush {
    [GBAppEvents flush];
}

@end
