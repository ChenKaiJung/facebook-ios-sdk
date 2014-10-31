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

#import "GBAppEvents.h"

@class GBRequest;

// Internally known event names

/*! Use to log that the share dialog was launched */
extern NSString *const GBAppEventNameShareSheetLaunch;

/*! Use to log that the share dialog was dismissed */
extern NSString *const GBAppEventNameShareSheetDismiss;

/*! Use to log that the permissions UI was launched */
extern NSString *const GBAppEventNamePermissionsUILaunch;

/*! Use to log that the permissions UI was dismissed */
extern NSString *const GBAppEventNamePermissionsUIDismiss;

/*! Use to log that the friend picker was launched and completed */
extern NSString *const GBAppEventNameFriendPickerUsage;

/*! Use to log that the place picker dialog was launched and completed */
extern NSString *const GBAppEventNamePlacePickerUsage;

/*! Use to log that the login view was used */
extern NSString *const GBAppEventNameLoginViewUsage;

/*! Use to log that the user settings view controller was used */
extern NSString *const GBAppEventNameUserSettingsUsage;

// Internally known event parameters

/*! String parameter specifying the outcome of a dialog invocation */
extern NSString *const GBAppEventParameterDialogOutcome;

/*! Use to log the result of a call to GBDialogs canPresentShareDialogWithParams: */
extern NSString *const GBAppEventNameGBDialogsPresentShareDialog;

/*! Use to log the result of a call to GBDialogs canPresentShareDialogWithOpenGraphActionParams: */
extern NSString *const GBAppEventNameGBDialogsPresentShareDialogOG;

/*! Use to log the start of an auth request that cannot be fulfilled by the token cache */
extern NSString *const GBAppEventNameGBSessionAuthStart;

/*! Use to log the end of an auth request that was not fulfilled by the token cache */
extern NSString *const GBAppEventNameGBSessionAuthEnd;

/*! Use to log the start of a specific auth method as part of an auth request */
extern NSString *const GBAppEventNameGBSessionAuthMethodStart;

/*! Use to log the end of the last tried auth method as part of an auth request */
extern NSString *const GBAppEventNameGBSessionAuthMethodEnd;

/*! Use to log the timestamp for the transition to the Facebook native login dialog */
extern NSString *const GBAppEventNameGBDialogsNativeLoginDialogStart;

/*! Use to log the timestamp for the transition back to the app after the Facebook native login dialog */
extern NSString *const GBAppEventNameGBDialogsNativeLoginDialogEnd;

/*! Use to log the e2e timestamp metrics for web login */
extern NSString *const GBAppEventNameGBDialogsWebLoginCompleted;

// Internally known event parameter values

extern NSString *const GBAppEventsDialogOutcomeValue_Completed;
extern NSString *const GBAppEventsDialogOutcomeValue_Cancelled;
extern NSString *const GBAppEventsDialogOutcomeValue_Failed;

extern NSString *const GBAppEventsNativeLoginDialogStartTime;
extern NSString *const GBAppEventsNativeLoginDialogEndTime;

extern NSString *const GBAppEventsWebLoginE2E;
extern NSString *const GBAppEventsWebLoginSwitchbackTime;

typedef enum {
    GBAppEventsFlushReasonExplicit,
    GBAppEventsFlushReasonTimer,
    GBAppEventsFlushReasonSessionChange,
    GBAppEventsFlushReasonPersistedEvents,
    GBAppEventsFlushReasonEventThreshold,
    GBAppEventsFlushReasonEagerlyFlushingEvent
} GBAppEventsFlushReason;

@interface GBAppEvents (Internal)

+ (void)logImplicitEvent:(NSString *)eventName
              valueToSum:(NSNumber *)valueToSum
              parameters:(NSDictionary *)parameters
                 session:(GBSession *)session;

+ (GBRequest *)customAudienceThirdPartyIDRequest:(GBSession *)session;

// *** Expose internally for testing/mocking only ***
+ (GBAppEvents *)singleton;
- (void)handleActivitiesPostCompletion:(NSError *)error
                          loggingEntry:(NSString *)loggingEntry
                               session:(GBSession *)session;

+ (void)logConversionPixel:(NSString *)pixelID
              valueOfPixel:(double)value
                   session:(GBSession *)session;

- (void)instanceFlush:(GBAppEventsFlushReason)flushReason;

// *** end ***

@end
