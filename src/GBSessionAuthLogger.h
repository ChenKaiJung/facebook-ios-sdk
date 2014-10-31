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

#import "GBSession+Internal.h"

// Keys to be used to serialize the logger (e.g. into JSON)
extern NSString *const GBSessionAuthLoggerParamAuthMethodKey;
extern NSString *const GBSessionAuthLoggerParamIDKey;

// The names of the authentication methods that are supported
extern NSString *const GBSessionAuthLoggerAuthMethodIntegrated;
extern NSString *const GBSessionAuthLoggerAuthMethodGBApplicationNative;
extern NSString *const GBSessionAuthLoggerAuthMethodGBApplicationWeb;
extern NSString *const GBSessionAuthLoggerAuthMethodBrowser;
extern NSString *const GBSessionAuthLoggerAuthMethodFallback;

// Well-known result strings.
extern NSString *const GBSessionAuthLoggerResultSuccess;
extern NSString *const GBSessionAuthLoggerResultError;
extern NSString *const GBSessionAuthLoggerResultCancelled;
extern NSString *const GBSessionAuthLoggerResultSkipped;

/*
 * This class is used specifically for logging events during auth/reauth cycles, for internal
 * debugging purposes.
 */
@interface GBSessionAuthLogger : NSObject

@property (nonatomic, readonly) NSString *ID;

/*!
 @abstract
 Returns an initialized GBSessionAuthLogger instance.

 @discussion The passed in GBSession is not retained to avoid circular references
 */
- (id)initWithSession:(GBSession *)session;

/*!
 @abstract
 Returns an initialized GBSessionAuthLogger instance with the passed in parameters. This method
 is designed to be used when deserializing a logger from a URL.

 @discussion The passed in GBSession is not retained to avoid circular references
 */
- (id)initWithSession:(GBSession *)session ID:(NSString *)ID authMethod:(NSString *)authMethod;

/*!
 @abstract
 Add JSON-serializable data to the 'extras' JSON blob that is attached to these auth events. The
 keys and values passed in here will be attached to the next event that is logged via this
 logger, and cleared after that. They are lost if no events are logged after a call to this method.
 Multiple calls to this method between log events, will append all the extras together.
 */
- (void)addExtrasForNextEvent:(NSDictionary *)metadata;

/*!
 @abstract
 Logs the start of an auth request
 */
- (void)logStartAuth;

/*!
 @abstract
 Logs the start of a specific auth method, as part of an auth request (e.g. Native GDP)
 */
- (void)logStartAuthMethod:(NSString *)authMethodName;

/*!
 @abstract
 Logs the end of the last-known auth method with the passed in result and error
 */
- (void)logEndAuthMethodWithResult:(NSString *)result error:(NSError *)error;

/*!
 @abstract
 Logs the end of the overall auth request with the passed in result and error
 */
- (void)logEndAuthWithResult:(NSString *)result error:(NSError *)error;

@end
