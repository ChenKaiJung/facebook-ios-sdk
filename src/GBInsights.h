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

#import "GBSession.h"

/*!
 @typedef GBInsightsFlushBehavior enum

 @abstract This enum has been deprecated in favor of GBAppEventsFlushBehavior.
 */
__attribute__ ((deprecated("use GBAppEventsFlushBehavior instead")))
typedef enum {
    GBInsightsFlushBehaviorAuto __attribute__ ((deprecated("use GBAppEventsFlushBehaviorAuto instead"))),
    GBInsightsFlushBehaviorExplicitOnly __attribute__ ((deprecated("use GBAppEventsFlushBehaviorExplicitOnly instead"))),
} GBInsightsFlushBehavior;

extern NSString *const GBInsightsLoggingResultNotification __attribute__((deprecated));

/*!
 @class GBInsights

 @abstract This class has been deprecated in favor of GBAppEvents.
 */
__attribute__ ((deprecated("Use the GBAppEvents class instead")))
@interface GBInsights : NSObject

+ (NSString *)appVersion __attribute__((deprecated));
+ (void)setAppVersion:(NSString *)appVersion __attribute__((deprecated("use [GBSettings setAppVersion] instead")));

+ (void)logPurchase:(double)purchaseAmount currency:(NSString *)currency __attribute__((deprecated("use [GBAppEvents logPurchase] instead")));
+ (void)logPurchase:(double)purchaseAmount currency:(NSString *)currency parameters:(NSDictionary *)parameters __attribute__((deprecated("use [GBAppEvents logPurchase] instead")));
+ (void)logPurchase:(double)purchaseAmount currency:(NSString *)currency parameters:(NSDictionary *)parameters session:(GBSession *)session __attribute__((deprecated("use [GBAppEvents logPurchase] instead")));

+ (void)logConversionPixel:(NSString *)pixelID valueOfPixel:(double)value __attribute__((deprecated));
+ (void)logConversionPixel:(NSString *)pixelID valueOfPixel:(double)value session:(GBSession *)session __attribute__((deprecated));

+ (GBInsightsFlushBehavior)flushBehavior __attribute__((deprecated("use [GBAppEvents flushBehavior] instead")));
+ (void)setFlushBehavior:(GBInsightsFlushBehavior)flushBehavior __attribute__((deprecated("use [GBAppEvents setFlushBehavior] instead")));

+ (void)flush __attribute__((deprecated("use [GBAppEvents flush] instead")));

@end
