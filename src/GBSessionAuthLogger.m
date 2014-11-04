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

#import "GBSessionAuthLogger.h"

#import "GBAppEvents+Internal.h"
#import "GBError.h"
#import "GBUtility.h"

// NOTE: The parameters are prefixed with a number (0-9) to allow us to determine sort order.
// These keys are sorted on the backend before being mapped to custom columns. Determining the order
// on the client will make it easier to parse through logs, and will allow future columns to be mapped
// predictably on the backend.
NSString *const GBSessionAuthLoggerParamIDKey = @"0_auth_logger_id";
NSString *const GBSessionAuthLoggerParamTimestampKey = @"1_timestamp_ms";
NSString *const GBSessionAuthLoggerParamResultKey = @"2_result";
NSString *const GBSessionAuthLoggerParamAuthMethodKey = @"3_method";
NSString *const GBSessionAuthLoggerParamErrorCodeKey = @"4_error_code";
NSString *const GBSessionAuthLoggerParamErrorMessageKey = @"5_error_message";
NSString *const GBSessionAuthLoggerParamExtrasKey = @"6_extras";

NSString *const GBSessionAuthLoggerAuthMethodIntegrated = @"integrated_auth";
NSString *const GBSessionAuthLoggerAuthMethodGBApplicationNative = @"fb_application_native_auth";
NSString *const GBSessionAuthLoggerAuthMethodGBApplicationWeb = @"fb_application_web_auth";
NSString *const GBSessionAuthLoggerAuthMethodBrowser = @"browser_auth";
NSString *const GBSessionAuthLoggerAuthMethodFallback = @"fallback_auth";

NSString *const GBSessionAuthLoggerResultSuccess = @"success";
NSString *const GBSessionAuthLoggerResultError = @"error";
NSString *const GBSessionAuthLoggerResultCancelled = @"cancelled";
NSString *const GBSessionAuthLoggerResultSkipped = @"skipped";

NSString *const GBSessionAuthLoggerParamEmptyValue = @"";

@interface GBSessionAuthLogger ()

@property (nonatomic, readwrite, copy) NSString *ID;
@property (nonatomic, retain) NSMutableDictionary *extras;
@property (nonatomic, assign) GBSession *session;
@property (nonatomic, copy) NSString *authMethod;

@end

@implementation GBSessionAuthLogger

- (id)initWithSession:(GBSession *)session {
    return [self initWithSession:session
                              ID:nil
                      authMethod:nil];
}

- (id)initWithSession:(GBSession *)session ID:(NSString *)ID authMethod:(NSString *)authMethod {
    self = [super init];
    if (self) {
        self.ID = ID ?: [[GBUtility newUUIDString] autorelease];
        self.authMethod = authMethod;
        self.extras = [NSMutableDictionary dictionary];
        self.session = session;
    }
    return self;
}

- (void)dealloc {
    [_ID release];
    [_extras release];
    [_authMethod release];

    [super dealloc];
}

- (void)addExtrasForNextEvent:(NSDictionary *)extras {
    [self.extras addEntriesFromDictionary:extras];
}

- (void)logEvent:(NSString *)eventName params:(NSMutableDictionary *)params {
    if (!self.session || !self.ID) {
        return;
    }

    NSString *extrasJSONString = [GBUtility simpleJSONEncode:self.extras];
    if (extrasJSONString) {
        params[GBSessionAuthLoggerParamExtrasKey] = extrasJSONString;
    }

    [self.extras removeAllObjects];

    [GBAppEvents logImplicitEvent:eventName valueToSum:nil parameters:params session:self.session];
}

- (void)logEvent:(NSString *)eventName result:(NSString *)result error:(NSError *)error {
    NSMutableDictionary *params = [[self newEventParameters] autorelease];

    params[GBSessionAuthLoggerParamResultKey] = result;

    if ([error.domain isEqualToString:GbombSDKDomain]) {
        // tease apart the structure.

        // first see if there is an explicit message in the error's userInfo. If not, default to the reason,
        // which is less useful.
        NSString *value = error.userInfo[@"error_message"] ?: error.userInfo[GBErrorLoginFailedReason];
        if (value) {
            params[GBSessionAuthLoggerParamErrorMessageKey] = value;
        }

        value = error.userInfo[GBErrorLoginFailedOriginalErrorCode] ?: [NSString stringWithFormat:@"%ld", (long)error.code];
        if (value) {
            params[GBSessionAuthLoggerParamErrorCodeKey] = value;
        }

        NSError *innerError = error.userInfo[GBErrorInnerErrorKey];
        value = innerError.userInfo[@"error_message"] ?: innerError.userInfo[GBErrorLoginFailedReason];
        if (value) {
            [self addExtrasForNextEvent:@{@"inner_error_message": value}];
        }

        value = innerError.userInfo[GBErrorLoginFailedOriginalErrorCode] ?: [NSString stringWithFormat:@"%ld", (long)innerError.code];
        if (value) {
            [self addExtrasForNextEvent:@{@"inner_error_code": value}];
        }
    } else if (error) {
        params[GBSessionAuthLoggerParamErrorCodeKey] = [NSNumber numberWithInteger:error.code];
    }

    [self logEvent:eventName params:params];
}

- (void)logStartAuth {
    [self logEvent:GBAppEventNameGBSessionAuthStart params:[[self newEventParameters] autorelease]];
}

- (void)logStartAuthMethod:(NSString *)authMethodName {
    self.authMethod = authMethodName;
    [self logEvent:GBAppEventNameGBSessionAuthMethodStart params:[[self newEventParameters] autorelease]];
}

- (void)logEndAuthMethodWithResult:(NSString *)result error:(NSError *)error {
    [self logEvent:GBAppEventNameGBSessionAuthMethodEnd result:result error:error];
    self.authMethod = nil;
}

- (void)logEndAuthWithResult:(NSString *)result error:(NSError *)error {
    [self logEvent:GBAppEventNameGBSessionAuthEnd result:result error:error];
}

- (NSMutableDictionary *)newEventParameters {
    NSMutableDictionary *eventParameters = [[NSMutableDictionary alloc] init];

    // NOTE: We ALWAYS add all params to each event, to ensure predictable mapping on the backend.
    eventParameters[GBSessionAuthLoggerParamIDKey] = self.ID ?: GBSessionAuthLoggerParamEmptyValue;
    eventParameters[GBSessionAuthLoggerParamTimestampKey] = [NSNumber numberWithDouble:round(1000 * [[NSDate date] timeIntervalSince1970])];
    eventParameters[GBSessionAuthLoggerParamResultKey] = GBSessionAuthLoggerParamEmptyValue;
    eventParameters[GBSessionAuthLoggerParamAuthMethodKey] = self.authMethod ?: GBSessionAuthLoggerParamEmptyValue;
    eventParameters[GBSessionAuthLoggerParamErrorCodeKey] = GBSessionAuthLoggerParamEmptyValue;
    eventParameters[GBSessionAuthLoggerParamErrorMessageKey] = GBSessionAuthLoggerParamEmptyValue;
    eventParameters[GBSessionAuthLoggerParamExtrasKey] = GBSessionAuthLoggerParamEmptyValue;

    return eventParameters;
}

@end
