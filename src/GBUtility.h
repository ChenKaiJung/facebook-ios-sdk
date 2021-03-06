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
#import <UIKit/UIKit.h>

#import "GBFetchedAppSettings.h"

@class GBRequest;
@class GBSession;

@protocol GBGraphObject;

typedef enum GBAdvertisingTrackingStatus {
    GBAdvertisingTrackingAllowed,
    GBAdvertisingTrackingDisallowed,
    GBAdvertisingTrackingUnspecified
} GBAdvertisingTrackingStatus;

@interface GBUtility : NSObject

+ (NSDictionary*)queryParamsDictionaryFromGBURL:(NSURL*)url;
+ (NSDictionary*)dictionaryByParsingURLQueryPart:(NSString *)encodedString;
+ (NSString *)stringBySerializingQueryParameters:(NSDictionary *)queryParameters;
+ (NSString *)stringByURLDecodingString:(NSString*)escapedString;
+ (NSString*)stringByURLEncodingString:(NSString*)unescapedString;
+ (id<GBGraphObject>)graphObjectInArray:(NSArray*)array withSameIDAs:(id<GBGraphObject>)item;

+ (unsigned long)currentTimeInMilliseconds;
+ (NSTimeInterval)randomTimeInterval:(NSTimeInterval)minValue withMaxValue:(NSTimeInterval)maxValue;
+ (void)centerView:(UIView*)view tableView:(UITableView*)tableView;
+ (NSString *)stringGBIDFromObject:(id)object;
+ (NSString *)stringAppBaseUrlFromAppId:(NSString *)appID urlSchemeSuffix:(NSString *)urlSchemeSuffix;
+ (NSDate*)expirationDateFromExpirationTimeIntervalString:(NSString*)expirationTime;
+ (NSDate*)expirationDateFromExpirationUnixTimeString:(NSString*)expirationTime;
+ (NSBundle *)facebookSDKBundle;
+ (NSString *)localizedStringForKey:(NSString *)key
                        withDefault:(NSString *)value;
+ (NSString *)localizedStringForKey:(NSString *)key
                        withDefault:(NSString *)value
                           inBundle:(NSBundle *)bundle;
// Returns YES when the bundle identifier is for one of the native facebook apps
+ (BOOL)isFacebookBundleIdentifier:(NSString *)bundleIdentifier;

+ (BOOL)isPublishPermission:(NSString*)permission;
+ (BOOL)areAllPermissionsReadPermissions:(NSArray*)permissions;
+ (NSArray*)addBasicInfoPermission:(NSArray*)permissions;
+ (void)fetchAppSettings:(NSString *)appID
                callback:(void (^)(GBFetchedAppSettings *, NSError *))callback;
// Only returns nil if no settings have been fetched; otherwise it returns the last fetched settings.
// If the settings are stale, an async request will be issued to fetch them.
+ (GBFetchedAppSettings *)fetchedAppSettings;
+ (NSString *)attributionID;
+ (NSString *)advertiserID;
+ (GBAdvertisingTrackingStatus)advertisingTrackingStatus;
+ (void)updateParametersWithEventUsageLimitsAndBundleInfo:(NSMutableDictionary *)parameters;

// Encode a data structure in JSON, any errors will just be logged.
+ (NSString *)simpleJSONEncode:(id)data;
+ (id)simpleJSONDecode:(NSString *)jsonEncoding;
+ (NSString *)simpleJSONEncode:(id)data
                         error:(NSError **)error
                writingOptions:(NSJSONWritingOptions)writingOptions;
+ (id)simpleJSONDecode:(NSString *)jsonEncoding
                 error:(NSError **)error;
+ (BOOL) isRetinaDisplay;
+ (NSString *)newUUIDString;
+ (BOOL)isRegisteredURLScheme:(NSString *)urlScheme;

+ (NSString *) buildGbombUrlWithPre:(NSString*)pre;
+ (NSString *) buildGbombUrlWithPre:(NSString*)pre
                              withPost:(NSString *)post;
+ (BOOL)isMultitaskingSupported;
+ (BOOL)isSystemAccountStoreAvailable;
+ (void)deleteGbombCookies;
+ (NSString *)sdkBaseURL;
+ (NSString *)dialogBaseURL;
+ (NSString *)getSystemVersion;
+ (NSString *)getSystemName;
+ (NSString *)getSystemModel;
@end

#define GBConditionalLog(condition, desc, ...) \
do { \
    if (!(condition)) { \
        NSString *msg = [NSString stringWithFormat:(desc), ##__VA_ARGS__]; \
        NSLog(@"GBConditionalLog: %@", msg); \
    } \
} while(NO)

#define GB_BASE_URL @"gbombgames.com"
