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
#import "GBAppEvents+Internal.h"

#import <UIKit/UIApplication.h>

#import "GBError.h"
#import "GBLogger.h"
#import "GBRequest+Internal.h"
#import "GBSession+Internal.h"
#import "GBSessionAppEventsState.h"
#import "GBSessionManualTokenCachingStrategy.h"
#import "GBSettings.h"
#import "GBUtility.h"

//
// Public event names
//

// General purpose
NSString *const GBAppEventNameActivatedApp            = @"gb_mobile_activate_app";
NSString *const GBAppEventNameCompletedRegistration   = @"gb_mobile_complete_registration";
NSString *const GBAppEventNameViewedContent           = @"gb_mobile_content_view";
NSString *const GBAppEventNameSearched                = @"gb_mobile_search";
NSString *const GBAppEventNameRated                   = @"gb_mobile_rate";
NSString *const GBAppEventNameCompletedTutorial       = @"gb_mobile_tutorial_completion";

// Ecommerce related
NSString *const GBAppEventNameAddedToCart             = @"gb_mobile_add_to_cart";
NSString *const GBAppEventNameAddedToWishlist         = @"gb_mobile_add_to_wishlist";
NSString *const GBAppEventNameInitiatedCheckout       = @"gb_mobile_initiated_checkout";
NSString *const GBAppEventNameAddedPaymentInfo        = @"gb_mobile_add_payment_info";
NSString *const GBAppEventNamePurchased               = @"gb_mobile_purchase";

// Gaming related
NSString *const GBAppEventNameAchievedLevel           = @"gb_mobile_level_achieved";
NSString *const GBAppEventNameUnlockedAchievement     = @"gb_mobile_achievement_unlocked";
NSString *const GBAppEventNameSpentCredits            = @"gb_mobile_spent_credits";

//
// Public event parameter names
//

NSString *const GBAppEventParameterNameCurrency               = @"gb_currency";
NSString *const GBAppEventParameterNameRegistrationMethod     = @"gb_registration_method";
NSString *const GBAppEventParameterNameContentType            = @"gb_content_type";
NSString *const GBAppEventParameterNameContentID              = @"gb_content_id";
NSString *const GBAppEventParameterNameSearchString           = @"gb_search_string";
NSString *const GBAppEventParameterNameSuccess                = @"gb_success";
NSString *const GBAppEventParameterNameMaxRatingValue         = @"gb_max_rating_value";
NSString *const GBAppEventParameterNamePaymentInfoAvailable   = @"gb_payment_info_available";
NSString *const GBAppEventParameterNameNumItems               = @"gb_num_items";
NSString *const GBAppEventParameterNameLevel                  = @"gb_level";
NSString *const GBAppEventParameterNameDescription            = @"gb_description";

//
// Public event parameter values
//

NSString *const GBAppEventParameterValueNo                    = @"0";
NSString *const GBAppEventParameterValueYes                   = @"1";

//
// Event names internal to this file
//

NSString *const GBAppEventNameLogConversionPixel               = @"gb_log_offsite_pixel";
NSString *const GBAppEventNameFriendPickerUsage                = @"gb_friend_picker_usage";
NSString *const GBAppEventNamePlacePickerUsage                 = @"gb_place_picker_usage";
NSString *const GBAppEventNameLoginViewUsage                   = @"gb_login_view_usage";
NSString *const GBAppEventNameUserSettingsUsage                = @"gb_user_settings_vc_usage";
NSString *const GBAppEventNameShareSheetLaunch                 = @"gb_share_sheet_launch";
NSString *const GBAppEventNameShareSheetDismiss                = @"gb_share_sheet_dismiss";
NSString *const GBAppEventNamePermissionsUILaunch              = @"gb_permissions_ui_launch";
NSString *const GBAppEventNamePermissionsUIDismiss             = @"gb_permissions_ui_dismiss";
NSString *const GBAppEventNameGBDialogsPresentShareDialog   = @"gb_dialogs_present_share";
NSString *const GBAppEventNameGBDialogsPresentShareDialogOG = @"gb_dialogs_present_share_og";


NSString *const GBAppEventNameGBDialogsNativeLoginDialogStart  = @"gb_dialogs_native_login_dialog_start";
NSString *const GBAppEventsNativeLoginDialogStartTime          = @"gb_native_login_dialog_start_time";

NSString *const GBAppEventNameGBDialogsNativeLoginDialogEnd    = @"gb_dialogs_native_login_dialog_end";
NSString *const GBAppEventsNativeLoginDialogEndTime            = @"gb_native_login_dialog_end_time";

NSString *const GBAppEventNameGBDialogsWebLoginCompleted       = @"gb_dialogs_web_login_dialog_complete";
NSString *const GBAppEventsWebLoginE2E                         = @"gb_web_login_e2e";
NSString *const GBAppEventsWebLoginSwitchbackTime              = @"gb_web_login_switchback_time";

NSString *const GBAppEventNameGBSessionAuthStart               = @"gb_mobile_login_start";
NSString *const GBAppEventNameGBSessionAuthEnd                 = @"gb_mobile_login_complete";
NSString *const GBAppEventNameGBSessionAuthMethodStart         = @"gb_mobile_login_method_start";
NSString *const GBAppEventNameGBSessionAuthMethodEnd           = @"gb_mobile_login_method_complete";

// Event Parameters internal to this file
NSString *const GBAppEventParameterConversionPixelID           = @"gb_offsite_pixel_id";
NSString *const GBAppEventParameterConversionPixelValue        = @"gb_offsite_pixel_value";
NSString *const GBAppEventParameterDialogOutcome               = @"gb_dialog_outcome";

// Event parameter values internal to this file
NSString *const GBAppEventsDialogOutcomeValue_Completed = @"Completed";
NSString *const GBAppEventsDialogOutcomeValue_Cancelled = @"Cancelled";
NSString *const GBAppEventsDialogOutcomeValue_Failed    = @"Failed";


NSString *const GBAppEventsLoggingResultNotification = @"com.facebook.sdk:GBAppEventsLoggingResultNotification";
NSString *const GBAppEventsActivateAppFlush = @"com.facebook.sdk:GBAppEventsActivateAppFlush%@";

@interface GBAppEvents ()

#pragma mark - typedefs

typedef enum {
    AppSupportsAttributionUnknown,
    AppSupportsAttributionQueryInFlight,
    AppSupportsAttributionTrue,
    AppSupportsAttributionFalse,
} AppSupportsAttributionStatus;

@property (readwrite, atomic) GBAppEventsFlushBehavior     flushBehavior;
@property (readwrite, atomic) BOOL                         haveOutstandingPersistedData;
@property (readwrite, atomic, retain) GBSession                   *lastSessionLoggedTo;
@property (readwrite, atomic, retain) GBSession                   *anonymousSession;
@property (readwrite, atomic, retain) NSTimer                     *flushTimer;
@property (readwrite, atomic, retain) NSTimer                     *attributionIDRecheckTimer;
@property (readwrite, atomic) AppSupportsAttributionStatus appSupportsAttributionStatus;
@property (readwrite, atomic) BOOL                         appSupportsImplicitLogging;
@property (readwrite, atomic) BOOL                         haveFetchedAppSettings;
@property (readwrite, atomic, retain) NSRegularExpression         *eventNameRegex;
@property (readwrite, atomic, retain) NSMutableSet                *validatedIdentifiers;

// Dictionary from appIDs to ClientToken-based app-authenticated session for that appID.
@property (readwrite, atomic, retain) NSMutableDictionary         *appAuthSessions;


@end

@implementation GBAppEvents

NSString *const GBAppEventsPersistedEventsFilename   = @"com-facebook-sdk-AppEventsPersistedEvents.json";

NSString *const GBAppEventsPersistKeyNumSkipped      = @"numSkipped";
NSString *const GBAppEventsPersistKeyEvents          = @"events";


#pragma mark - Constants

const int NUM_LOG_EVENTS_TO_TRY_TO_FLUSH_AFTER       = 100;
const int FLUSH_PERIOD_IN_SECONDS                    = 60;
const int APP_SUPPORTS_ATTRIBUTION_ID_RECHECK_PERIOD = 60 * 60 * 24;
const int MAX_IDENTIFIER_LENGTH                      = 40;



@synthesize
    flushBehavior = _flushBehavior,
    haveOutstandingPersistedData = _haveOutstandingPersistedData,
    lastSessionLoggedTo = _lastSessionLoggedTo,
    anonymousSession = _anonymousSession,
    appAuthSessions = _appAuthSessions,
    flushTimer = _flushTimer,
    attributionIDRecheckTimer = _attributionIDRecheckTimer,
    appSupportsAttributionStatus = _appSupportsAttributionStatus,
    appSupportsImplicitLogging = _appSupportsImplicitLogging,
    haveFetchedAppSettings = _haveFetchedAppSettings,
    eventNameRegex = _eventNameRegex,
    validatedIdentifiers = _validatedIdentifiers;

#pragma mark - logEvent variants

/*
 * Event logging
 */
+ (void)logEvent:(NSString *)eventName {
    [GBAppEvents logEvent:eventName
              parameters:nil];
}

+ (void)logEvent:(NSString *)eventName
      valueToSum:(double)valueToSum {
    [GBAppEvents logEvent:eventName
              valueToSum:valueToSum
              parameters:nil];
}

+ (void)logEvent:(NSString *)eventName
      parameters:(NSDictionary *)parameters {
    [GBAppEvents logEvent:eventName
              valueToSum:nil
              parameters:parameters
                 session:nil];
}

+ (void)logEvent:(NSString *)eventName
      valueToSum:(double)valueToSum
      parameters:(NSDictionary *)parameters {
    [GBAppEvents logEvent:eventName
              valueToSum:[NSNumber numberWithDouble:valueToSum]
              parameters:parameters
                 session:nil];
}

+ (void)logEvent:(NSString *)eventName
      valueToSum:(NSNumber *)valueToSum
      parameters:(NSDictionary *)parameters
         session:(GBSession *)session {
    [GBAppEvents.singleton instanceLogEvent:eventName
                                valueToSum:valueToSum
                                parameters:parameters
                        isImplicitlyLogged:NO
                                   session:session];
}


+ (void)logImplicitEvent:(NSString *)eventName
              valueToSum:(NSNumber *)valueToSum
              parameters:(NSDictionary *)parameters
                 session:(GBSession *)session {

    [GBAppEvents.singleton instanceLogEvent:eventName
                                valueToSum:valueToSum
                                parameters:parameters
                        isImplicitlyLogged:YES
                                   session:session];
}

#pragma mark - logPurchase variants

+ (void)logPurchase:(double)purchaseAmount
           currency:(NSString *)currency {
    [GBAppEvents logPurchase:purchaseAmount
                    currency:currency
                  parameters:nil];
}

+ (void)logPurchase:(double)purchaseAmount
           currency:(NSString *)currency
         parameters:(NSDictionary *)parameters {
    [GBAppEvents logPurchase:purchaseAmount
                    currency:currency
                  parameters:parameters
                     session:nil];

}

+ (void)logPurchase:(double)purchaseAmount
           currency:(NSString *)currency
         parameters:(NSDictionary *)parameters
            session:(GBSession *)session {

    // A purchase event is just a regular logged event with a given event name
    // and treating the currency value as going into the parameters dictionary.

    NSDictionary *newParameters;
    if (!parameters) {
        newParameters = @{ GBAppEventParameterNameCurrency : currency };
    } else {
        newParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
        [newParameters setValue:currency forKey:GBAppEventParameterNameCurrency];
    }

    [GBAppEvents logEvent:GBAppEventNamePurchased
              valueToSum:[NSNumber numberWithDouble:purchaseAmount]
              parameters:newParameters
                 session:session];

    // Unless the behavior is set to only allow explicit flushing, we go ahead and flush, since purchase events
    // are relatively rare and relatively high value and worth getting across on wire right away.
    if ([GBAppEvents flushBehavior] != GBAppEventsFlushBehaviorExplicitOnly) {
        [GBAppEvents.singleton instanceFlush:GBAppEventsFlushReasonEagerlyFlushingEvent];
    }

}

#pragma mark - Conversion Pixels

// Deprecated... only accessed through GBInsights
+ (void)logConversionPixel:(NSString *)pixelID
              valueOfPixel:(double)value
                   session:(GBSession *)session {

    // This method exists to allow a single API to be invoked to log a conversion pixel from a native mobile app
    // (and thus readily included in a snippet).  It logs the event with known event name and parameter names.
    // Unless the behavior is set to only allow explicit flushing, we go ahead and flush, since pixel firings
    // are relatively rare and relatively high value and worth getting across on wire right away.

    if (!pixelID) {
        [GBAppEvents logAndNotify:@"Conversion Pixel ID cannot be nil"];
        return;
    }

    [GBAppEvents logEvent:GBAppEventNameLogConversionPixel
              valueToSum:[NSNumber numberWithDouble:value]
              parameters:@{ GBAppEventParameterConversionPixelID : pixelID,
                            GBAppEventParameterConversionPixelValue : [NSNumber numberWithDouble:value] }
                 session:session];

    if ([GBAppEvents flushBehavior] != GBAppEventsFlushBehaviorExplicitOnly) {
        [GBAppEvents.singleton instanceFlush:GBAppEventsFlushReasonEagerlyFlushingEvent];
    }
}

#pragma mark - Event usage

// Deprecated... access through GBSettings.limitEventAndDataUsage
+ (BOOL)limitEventUsage {
    return GBSettings.limitEventAndDataUsage;
}

// Deprecated... access through GBSettings.limitEventAndDataUsage
+ (void)setLimitEventUsage:(BOOL)limitEventUsage {
    GBSettings.limitEventAndDataUsage = limitEventUsage;
}

+ (void)activateApp {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // activateApp supercedes publishInstall in the public API, but we need to
    // trigger an install event as before.
    [GBSettings publishInstall:nil];
#pragma clang diagnostic pop

    [GBAppEvents logEvent:GBAppEventNameActivatedApp];
}

#pragma mark - Flushing & Session Management

+ (GBAppEventsFlushBehavior)flushBehavior {
    return GBAppEvents.singleton.flushBehavior;
}

+ (void)setFlushBehavior:(GBAppEventsFlushBehavior)flushBehavior {
    GBAppEvents.singleton.flushBehavior = flushBehavior;
}

+ (void)flush {
    [GBAppEvents.singleton instanceFlush:GBAppEventsFlushReasonExplicit];
}

#pragma mark - Private Methods


+ (GBAppEvents *)singleton {
    static dispatch_once_t pred;
    static GBAppEvents *shared = nil;

    dispatch_once(&pred, ^{
        shared = [[GBAppEvents alloc] init];
    });
    return shared;
}


/**
 *
 * Multithreading Principles
 *
 * Logging events may be invoked from any thread.  The GBSession-specific logging data structures
 * will be locked before being updated.  Flushes, be they invoked explicitly or implicitly, will be
 * dispatched to the main thread.
 *
 * GBSessionAppEventsState is a chunk of state that hangs off of GBSession and holds event state
 * destined for that session.
 *
 * That GBSessionAppEventsState instance itself is used as the synchronization object for most logging
 * state.  For multi-thread accessed global state, we synchronize mostly on the GBAppEvents singleton object.
 *
 * The other singleton state is intended to be accessed from the main thread only (though certain ones, like
 * flushBehavior, are innocuous enough that it doesn't matter).
 *
 * Every method here that is expected to be called from the main thread should have
 * [GBAppEvents ensureOnMainThread] at its top.  This just does an GBConditionalLog if it's not the main thread,
 * but indicates a clear logic error in how this is being used when that occurs.
 */


- (GBAppEvents *)init {
    self = [super init];
    if (self) {
        // Default haveOutstandingPersistedData to YES in case the app was killed before it could upload data
        // This will still require a session and a call to logEvent at some point to set that session up
        self.haveOutstandingPersistedData = YES;
        self.flushBehavior = GBAppEventsFlushBehaviorAuto;
        self.appSupportsAttributionStatus = AppSupportsAttributionUnknown;

        self.appAuthSessions = [[[NSMutableDictionary alloc] init] autorelease];

        // Timer fires unconditionally on a regular interval... handler decides whether to call flush.
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS
                                                           target:self
                                                         selector:@selector(flushTimerFired:)
                                                         userInfo:nil
                                                          repeats:YES];

        self.attributionIDRecheckTimer = [NSTimer scheduledTimerWithTimeInterval:APP_SUPPORTS_ATTRIBUTION_ID_RECHECK_PERIOD
                                                                          target:self
                                                                        selector:@selector(attributionIDRecheckTimerFired:)
                                                                        userInfo:nil
                                                                         repeats:YES];

        // Register an observer to watch for app moving out of the active state, which we use
        // to signal a flush.  Since this is static, we don't unregister anywhere.
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationMovingFromActiveState)
         name:UIApplicationWillResignActiveNotification
         object:NULL];

        // Register for app termination, where we'll persist unsent events.
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationTerminating)
         name:UIApplicationWillTerminateNotification
         object:NULL];

        // And register for app activation, where we'll set up persisted events to be set.
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationDidBecomeActive)
         name:UIApplicationDidBecomeActiveNotification
         object:NULL];
    }

    return self;
}

// Note: not implementing dealloc() here, as this is used as a singleton and is never expected to be released.

- (BOOL)validateIdentifier:(NSString *)identifier {

    if (identifier == nil || identifier.length == 0 || identifier.length > MAX_IDENTIFIER_LENGTH || ![self regexValidateIdentifier:identifier]) {
        [GBAppEvents logAndNotify:[NSString stringWithFormat:@"Invalid identifier: '%@'.  Must be between 1 and %d characters, and must be contain only alphanumerics, _, - or spaces, starting with alphanumeric or _.",
                                  identifier, MAX_IDENTIFIER_LENGTH]];
        return NO;
    }

    return YES;
}

- (BOOL)regexValidateIdentifier:(NSString *)identifier {

    if (!self.eventNameRegex) {

        // Event name must only have 0-9A-Za-z, underscore, hyphen, and space (but no hyphen or space in the first position).
        NSString *regex = @"^[0-9a-zA-Z_]+[0-9a-zA-Z _-]*$";

        NSError *regexError;
        self.eventNameRegex = [NSRegularExpression regularExpressionWithPattern:regex
                                                                        options:nil
                                                                          error:&regexError];
        self.validatedIdentifiers = [[[NSMutableSet alloc] init] autorelease];
    }

    if (![self.validatedIdentifiers containsObject:identifier]) {
        NSUInteger numMatches = [self.eventNameRegex numberOfMatchesInString:identifier options:nil range:NSMakeRange(0, identifier.length)];
        if (numMatches > 0) {
            [self.validatedIdentifiers addObject:identifier];
        } else {
            return NO;
        }
    }

    return YES;
}

- (void)instanceLogEvent:(NSString *)eventName
              valueToSum:(NSNumber *)valueToSum
              parameters:(NSDictionary *)parameters
      isImplicitlyLogged:(BOOL)isImplicitlyLogged
                 session:(GBSession *)session {

    // Bail out of implicitly logged events if we know we're not doing implicit logging.
    if (isImplicitlyLogged && self.haveFetchedAppSettings && !self.appSupportsImplicitLogging) {
        return;
    }

    __block BOOL failed = NO;

    if (![self validateIdentifier:eventName]) {
        failed = YES;
    }

    // Make sure parameter dictionary is well formed.  Log and exit if not.
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {

        if (![key isKindOfClass:[NSString class]]) {
            [GBAppEvents logAndNotify:[NSString stringWithFormat:@"The keys in the parameters must be NSStrings, '%@' is not.", key]];
            failed = YES;
        }

        if (![self validateIdentifier:key]) {
            failed = YES;
        }

        if (![obj isKindOfClass:[NSString class]] && ![obj isKindOfClass:[NSNumber class]]) {
            [GBAppEvents logAndNotify:[NSString stringWithFormat:@"The values in the parameters dictionary must be NSStrings or NSNumbers, '%@' is not.", obj]];
            failed = YES;
        }

    }
     ];

    if (failed) {
        return;
    }

    // Push the event onto the queue for later flushing.

    GBSession *sessionToLogTo = [self sessionToSendRequestTo:session];
    NSMutableDictionary *eventDictionary = [NSMutableDictionary dictionaryWithDictionary:parameters];

    long logTime = [GBAppEvents unixTimeNow];
    [eventDictionary setObject:eventName forKey:@"_eventName"];
    [eventDictionary setObject:[NSNumber numberWithLong:logTime] forKey:@"_logTime"];

    if (valueToSum != nil) {
        [eventDictionary setObject:valueToSum forKey:@"_valueToSum"];
    }

    if (isImplicitlyLogged) {
        [eventDictionary setObject:@"1" forKey:@"_implicitlyLogged"];
    }

    @synchronized (self) {
        if ([GBSettings appVersion]) {
            [eventDictionary setObject:[GBSettings appVersion] forKey:@"_appVersion"];
        }

        // If this is a different session than the most recent we logged to, set up that earlier session for flushing, and update
        // the most recent.
        if (!self.lastSessionLoggedTo) {
            self.lastSessionLoggedTo = sessionToLogTo;
        }

        if (self.lastSessionLoggedTo != sessionToLogTo) {
            // Since we're not logging to lastSessionLoggedTo, at least for now, set it up for flushing.  If we swap back and
            // forth frequently between sessions, this could be thrashy, but that's not an expected use case of the SDK.
            [self flush:GBAppEventsFlushReasonSessionChange session:self.lastSessionLoggedTo];
            self.lastSessionLoggedTo = sessionToLogTo;
        }

        GBSessionAppEventsState *appEventsState = sessionToLogTo.appEventsState;

        [appEventsState addEvent:eventDictionary isImplicit:isImplicitlyLogged];

        if (!isImplicitlyLogged) {
            [GBLogger singleShotLogEntry:GBLoggingBehaviorAppEvents
                            formatString:@"GBAppEvents: Recording event @ %ld: %@",
                [GBAppEvents unixTimeNow],
                eventDictionary];
        }

        BOOL eventsRetrievedFromPersistedData = NO;
        if (self.haveOutstandingPersistedData) {
            // Now that we have a session, we can read in our persisted data.
            eventsRetrievedFromPersistedData = [self updateAppEventsStateWithPersistedData:sessionToLogTo];
            self.haveOutstandingPersistedData = NO;
        }

        if (self.flushBehavior != GBAppEventsFlushBehaviorExplicitOnly) {

            if (appEventsState.getAccumulatedEventCount > NUM_LOG_EVENTS_TO_TRY_TO_FLUSH_AFTER) {
                [self flush:GBAppEventsFlushReasonEventThreshold session:sessionToLogTo];
            } else if (eventsRetrievedFromPersistedData) {
                [self flush:GBAppEventsFlushReasonPersistedEvents session:sessionToLogTo];
            }

        }
    }
}

- (void)instanceFlush:(GBAppEventsFlushReason)flushReason {
    if (self.lastSessionLoggedTo) {  // nil only if no logging yet, instanceLogEvent will fill this in.
        [self flush:flushReason session:self.lastSessionLoggedTo];
    }
}


- (void)flush:(GBAppEventsFlushReason)flushReason
      session:(GBSession *)session {

    // Always flush asynchronously, even on main thread, for two reasons:
    // - most consistent code path for all threads.
    // - allow locks being held by caller to be released prior to actual flushing work being done.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self flushOnMainQueue:flushReason session:session];
    });
}

/*

 Event sending procedure:

 - always executing on the main thread, and the flush is targeted at the appEventsState on the session
 - if request is currently in-flight, return
 - extend the 'inFlight' event list with the list of current events
 - clear out the current event list (since logEvents during this request will add to it)
 - send request
 - if request result is:
   + success: clear out the inFlight event list, invoke the delegate with success
   + server error: clear out the inFlight event list, log, and publish to NotificationCenter with error
   + cannot connect: keep inFlight event list intact

 After N minutes, the process will be re-invoked if there are items in the inFlight list, or
 you haven't chosen ExplicitOnly flush.

 On app deactivation/backgrounding: persist the inFlight events.  No time to try to send.
 On app termination: Persist the inFlight events
 On app activation: Read back from persisted data and flush asap.

 */
- (void)flushOnMainQueue:(GBAppEventsFlushReason)flushReason
                 session:(GBSession *)session {

    [GBAppEvents ensureOnMainThread];
    GBSessionAppEventsState *appEventsState = session.appEventsState;

    // If trying to flush a session already in flight, just ignore and continue to accum events
    // until we try to flush again.
    if (appEventsState.requestInFlight || self.appSupportsAttributionStatus == AppSupportsAttributionQueryInFlight) {
        return;
    }

    NSString *appid = session.appID;

    if (self.appSupportsAttributionStatus == AppSupportsAttributionUnknown) {

        // If we haven't yet determined whether the app supports sending the attribution ID, we'll need
        // to make an initial request to determine this, and then call back in once we know.
        self.appSupportsAttributionStatus = AppSupportsAttributionQueryInFlight;
        [GBUtility fetchAppSettings:appid
                           callback:^(GBFetchedAppSettings *settings, NSError *error) {

                               [GBAppEvents ensureOnMainThread];

                               // Treat an error as if the app doesn't allow sending of attribution ID.
                               self.appSupportsAttributionStatus = settings.supportsAttribution && !error
                                 ? AppSupportsAttributionTrue : AppSupportsAttributionFalse;

                               self.appSupportsImplicitLogging = settings.supportsImplicitSdkLogging;

                               self.haveFetchedAppSettings = YES;

                               // Kick off the original flush, now that we have the info we need.
                               [self flushOnMainQueue:flushReason session:session];
                           }
        ];

        return;

    }

    NSString *jsonEncodedEvents;
    NSUInteger eventCount, numSkipped;
    @synchronized (appEventsState) {

        [appEventsState.inFlightEvents addObjectsFromArray:appEventsState.accumulatedEvents];
        [appEventsState.accumulatedEvents removeAllObjects];
        eventCount = appEventsState.inFlightEvents.count;

        if (!eventCount) {
            return;
        }

        jsonEncodedEvents = [appEventsState jsonEncodeInFlightEvents:self.appSupportsImplicitLogging];
        numSkipped = appEventsState.numSkippedEventsDueToFullBuffer;
    }

    // Move custom events field off the URL and into a POST field only by encoding into UTF8, which the server
    // will then handle as an uploaded file.  It also allows request compression to work on event data.
    NSData *utf8EncodedEvents = [jsonEncodedEvents dataUsingEncoding:NSUTF8StringEncoding];

    if (!utf8EncodedEvents) {
        [GBLogger singleShotLogEntry:GBLoggingBehaviorAppEvents
                            logEntry:@"GBAppEvents: Flushing skipped - no events after removing implicitly logged ones.\n"];
        return;
    }

    NSMutableDictionary *postParameters =
        [NSMutableDictionary dictionaryWithDictionary:
            @{ @"event" : @"CUSTOM_APP_EVENTS",
               @"custom_events_file" : utf8EncodedEvents,
            }
         ];

    if (numSkipped > 0) {
        postParameters[@"num_skipped_events"] = [NSString stringWithFormat:@"%lu", (unsigned long)numSkipped];
    }

    [self appendAttributionAndAdvertiserIDs:postParameters
                                              session:session];

    NSString *loggingEntry = nil;
    if ([[GBSettings loggingBehavior] containsObject:GBLoggingBehaviorAppEvents]) {

        id decodedEvents = [GBUtility simpleJSONDecode:jsonEncodedEvents];
        NSString *prettyPrintedJsonEvents = [GBUtility simpleJSONEncode:decodedEvents
                                                                  error:nil
                                                         writingOptions:NSJSONWritingPrettyPrinted];

        // Remove this param -- just an encoding of the events which we pretty print later.
        NSMutableDictionary *paramsForPrinting = [NSMutableDictionary dictionaryWithDictionary:postParameters];
        [paramsForPrinting removeObjectForKey:@"custom_events_file"];

        loggingEntry = [NSString stringWithFormat:@"GBAppEvents: Flushed @ %ld, %lu events due to '%@' - %@\nEvents: %@",
                         [GBAppEvents unixTimeNow],
                         (unsigned long)eventCount,
                         [GBAppEvents flushReasonToString:flushReason],
                         paramsForPrinting,
                         prettyPrintedJsonEvents];
    }

    GBRequest *request = [[[GBRequest alloc] initWithSession:session
                                                   graphPath:[NSString stringWithFormat:@"%@/activities", appid]
                                                  parameters:postParameters
                                                  HTTPMethod:@"POST"] autorelease];
    request.canCloseSessionOnError = NO;

    [request startWithCompletionHandler:^(GBRequestConnection *connection, id result, NSError *error) {
        [self handleActivitiesPostCompletion:error
                                loggingEntry:loggingEntry
                                     session:session];
    }];

    appEventsState.requestInFlight = YES;
}

- (void)appendAttributionAndAdvertiserIDs:(NSMutableDictionary *)postParameters
                                            session:(GBSession *)session {

    if (self.appSupportsAttributionStatus == AppSupportsAttributionTrue) {
        NSString *attributionID = [GBUtility attributionID];
        if (attributionID) {
            [postParameters setObject:attributionID forKey:@"attribution"];
        }
    }

    // Send advertiserID if available, and send along whether tracking is enabled too.  That's because
    // we can use the advertiser_id for non-tracking purposes (aggregated Insights/demographics) that doesn't
    // result in advertising targeting that user.
    NSString *advertiserID = [GBUtility advertiserID];
    if (advertiserID) {
        [postParameters setObject:advertiserID forKey:@"advertiser_id"];
    }

    [GBUtility updateParametersWithEventUsageLimitsAndBundleInfo:postParameters];
}

- (BOOL)doesSessionHaveUserToken:(GBSession *)session {
    // Assume that if we're not using an appAuthSession (built from the Client Token) or the anonymous session,
    // then we have a logged in user token.
    GBSession *appAuthSession = [self.appAuthSessions objectForKey:session.appID];
    return session != appAuthSession && session != self.anonymousSession;
}


// Given a candidate session (which may be nil), find the real session to send the GBRequest to (with an access token).
// Precedence: 1) provided session, 2) activeSession, 3) app authenticated session, 4) fully anonymous session.
// When clientToken-annotated calls move outside of the domain of stuff handled in this file, we may want to move this as a
// helper into GBSession.
- (GBSession *)sessionToSendRequestTo:(GBSession *)session {

    if (!session) {
        // Note: activeSession's appID will be [GBSettings defaultAppID] unless otherwise established.
        session = [GBSession activeSession];
    }

    if (!session.accessTokenData.accessToken) {

        NSString *clientToken = [GBSettings clientToken];
        NSString *appID = session.appID;

        if (clientToken && appID) {

            GBSession *appAuthSession = [self.appAuthSessions objectForKey:appID];
            if (!appAuthSession) {

                @synchronized(self) {

                    appAuthSession = [self.appAuthSessions objectForKey:appID];  // in case it snuck in
                    if (!appAuthSession) {

                        GBSessionManualTokenCachingStrategy *tokenCaching = [[GBSessionManualTokenCachingStrategy alloc] init];
                        tokenCaching.accessToken = [NSString stringWithFormat:@"%@|%@", appID, clientToken];
                        tokenCaching.expirationDate = [NSDate dateWithTimeIntervalSinceNow:315360000]; // 10 years from now

                        // Create session with explicit token and stash with appID.
                        appAuthSession = [GBAppEvents unaffinitizedSessionFromToken:tokenCaching
                                                                              appID:appID];
                        [tokenCaching release];

                        [self.appAuthSessions setObject:appAuthSession forKey:appID];
                    }
                }
            }
            session = appAuthSession;

        } else {

            // No clientToken, create session without access token that can be used for logging the events in 'eventsNotRequiringToken', preferring
            // appID coming in with the incoming session (or the activeSession), even if they don't have an access token.
            if (!self.anonymousSession) {

                @synchronized(self) {

                    if (!self.anonymousSession) {  // in case it snuck in
                        self.anonymousSession = [GBAppEvents unaffinitizedSessionFromToken:[GBSessionTokenCachingStrategy nullCacheInstance]
                                                                                     appID:appID];
                    }
                }
            }
            session = self.anonymousSession;
        }

    }

    return session;
}

+ (GBSession *)unaffinitizedSessionFromToken:(GBSessionTokenCachingStrategy *)tokenCachingStrategy
                                       appID:(NSString *)appID {

    // Passing in nil for appID will result in using [GBSettings defaultAppID], and the right exception
    // behavior will happen if that is null.
    GBSession *session = [[[GBSession alloc] initWithAppID:appID
                                               permissions:nil
                                           urlSchemeSuffix:nil
                                        tokenCacheStrategy:tokenCachingStrategy]
                          autorelease];

    // This may have been created off of the main thread, so clear out the affinitizedThread, and it will be
    // reset to the main thread on the first "real" operation on it.
    [session clearAffinitizedThread];

    return session;
}

+ (long)unixTimeNow {
    return (long)round([[NSDate date] timeIntervalSince1970]);
}


- (void)handleActivitiesPostCompletion:(NSError *)error
                          loggingEntry:(NSString *)loggingEntry
                               session:(GBSession *)session {

    typedef enum {
        FlushResultSuccess,
        FlushResultServerError,
        FlushResultNoConnectivity
    } FlushResult;

    [GBAppEvents ensureOnMainThread];

    FlushResult flushResult = FlushResultSuccess;
    if (error) {

        NSInteger errorCode = [[[error userInfo] objectForKey:GBErrorHTTPStatusCodeKey] integerValue];

        // We interpret a 400 coming back from GBRequestConnection as a server error due to improper data being
        // sent down.  Otherwise we assume no connectivity, or another condition where we could treat it as no connectivity.
        flushResult = errorCode == 400 ? FlushResultServerError : FlushResultNoConnectivity;
    }

    GBSessionAppEventsState *appEventsState = session.appEventsState;
    BOOL allEventsAreImplicit = YES;
    @synchronized (appEventsState) {
        if (flushResult != FlushResultNoConnectivity) {
            for (NSDictionary *eventAndImplicitFlag in appEventsState.inFlightEvents) {
                if (![eventAndImplicitFlag[kGBAppEventIsImplicit] boolValue]) {
                    allEventsAreImplicit = NO;
                    break;
                }
            }

            // Either success or a real server error.  Either way, no more in flight events.
            [appEventsState clearInFlightAndStats];
        }

        appEventsState.requestInFlight = NO;
    }

    if (flushResult == FlushResultServerError) {
        [GBAppEvents logAndNotify:[error description] allowLogAsDeveloperError:!allEventsAreImplicit];
    }

    NSString *resultString = @"<unknown>";
    switch (flushResult) {
        case FlushResultSuccess:
            resultString = @"Success";
            break;

        case FlushResultNoConnectivity:
            resultString = @"No Connectivity";
            break;

        case FlushResultServerError:
            resultString = [NSString stringWithFormat:@"Server Error - %@", [error description]];
            break;
    }

    [GBLogger singleShotLogEntry:GBLoggingBehaviorAppEvents
                    formatString:@"%@\nFlush Result : %@", loggingEntry, resultString];
}


- (void)flushTimerFired:(id)arg {
    [GBAppEvents ensureOnMainThread];

    @synchronized (self) {
        if (self.flushBehavior != GBAppEventsFlushBehaviorExplicitOnly) {
            if (self.lastSessionLoggedTo.appEventsState.inFlightEvents.count > 0 ||
                self.lastSessionLoggedTo.appEventsState.accumulatedEvents.count > 0) {

                [self flush:GBAppEventsFlushReasonTimer session:self.lastSessionLoggedTo];
            }
        }
    }
}

- (void)attributionIDRecheckTimerFired:(id)arg {
    // Reset app attribution status so it will be re-fetched in the event there was a server change.
    self.appSupportsAttributionStatus = AppSupportsAttributionUnknown;
}

- (void)applicationDidBecomeActive {

    [GBAppEvents ensureOnMainThread];

    // We associate the deserialized persisted data with the current session.
    // It's possible we'll get false attribution if the user identity has changed
    // between the time the data was persisted and now, but we'll accept these
    // anomolies in the aggregate data (which should be rare anyhow).

    // Can only actively update state and log when we have a session, otherwise we
    // set a BOOL to tell us to update as soon as we can afterwards.
    if (self.lastSessionLoggedTo) {

        BOOL eventsRetrieved = [self updateAppEventsStateWithPersistedData:self.lastSessionLoggedTo];

        if (eventsRetrieved && self.flushBehavior != GBAppEventsFlushBehaviorExplicitOnly) {
            [self flush:GBAppEventsFlushReasonPersistedEvents session:self.lastSessionLoggedTo];
        }

    } else {

        self.haveOutstandingPersistedData = YES;

    }
}

// Read back previously persisted events, if any, into specified session, returning whether any events were retrieved.
- (BOOL)updateAppEventsStateWithPersistedData:(GBSession *)session {

    BOOL eventsRetrieved = NO;
    NSDictionary *persistedData = [GBAppEvents retrievePersistedAppEventData];
    if (persistedData) {

        [GBAppEvents clearPersistedAppEventData];

        GBSessionAppEventsState *appEventsState = session.appEventsState;
        @synchronized (appEventsState) {
            appEventsState.numSkippedEventsDueToFullBuffer += [[persistedData objectForKey:GBAppEventsPersistKeyNumSkipped] integerValue];
            NSArray *retrievedObjects = [persistedData objectForKey:GBAppEventsPersistKeyEvents];
            if (retrievedObjects.count) {
                [appEventsState.inFlightEvents addObjectsFromArray:retrievedObjects];
                eventsRetrieved = YES;
            }
        }
    }

    return eventsRetrieved;
}

- (void)applicationMovingFromActiveState {
    // When moving from active state, we don't have time to wait for the result of a flush, so
    // just persist events to storage, and we'll process them at the next activation.
    [self persistDataIfNotInFlight];
}

- (void)applicationTerminating {
    // When terminating, we don't have time to wait for the result of a flush, so
    // just persist events to storage, and we'll process them at the next activation.
    [self persistDataIfNotInFlight];
}

- (void)persistDataIfNotInFlight {
    [GBAppEvents ensureOnMainThread];

    GBSessionAppEventsState *appEventsState = self.lastSessionLoggedTo.appEventsState;
    if (appEventsState.requestInFlight) {
        // In flight request may or may not succeed, so there's no right thing to do here.  Err by just not doing anything on termination;
        return;
    }

    // Persist right away if needed (rather than trying one last sync) since we're about to be booted out.
    [GBAppEvents persistAppEventsData:appEventsState];
}

+ (void)logAndNotify:(NSString *)msg allowLogAsDeveloperError:(BOOL *)allowLogAsDeveloperError {

    // capture reason and nested code as user info
    NSDictionary* userinfo = [NSDictionary dictionaryWithObject:msg forKey:GBErrorAppEventsReasonKey];

    // create error object
    NSError *err = [NSError errorWithDomain:FacebookSDKDomain
                                       code:GBErrorAppEvents
                                   userInfo:userinfo];

    NSString *behaviorToLog = GBLoggingBehaviorAppEvents;
    if (allowLogAsDeveloperError) {
        if ([[GBSettings loggingBehavior] containsObject:GBLoggingBehaviorDeveloperErrors]) {
            // Rather than log twice, prefer 'DeveloperErrors' if it's set over AppEvents.
            behaviorToLog = GBLoggingBehaviorDeveloperErrors;
        }
    }

    [GBLogger singleShotLogEntry:behaviorToLog logEntry:msg];

    [[NSNotificationCenter defaultCenter] postNotificationName:GBAppEventsLoggingResultNotification
                                                        object:err];
}

+ (void)logAndNotify:(NSString *)msg {
    [GBAppEvents logAndNotify:msg allowLogAsDeveloperError:YES];
}

#pragma mark - event log persistence

+ (void)persistAppEventsData:(GBSessionAppEventsState *)appEventsState {

    [GBAppEvents ensureOnMainThread];
    NSString *content;

    // We just persist from the last session being logged to.  When we switch sessions, we flush out
    // the one being moved away from.  So, modulo in-flight sessions, the only one with real data will
    // be the last one.

    @synchronized (appEventsState) {
        [appEventsState.inFlightEvents addObjectsFromArray:appEventsState.accumulatedEvents];
        [appEventsState.accumulatedEvents removeAllObjects];

        [GBLogger singleShotLogEntry:GBLoggingBehaviorAppEvents
                        formatString:@"GBAppEvents Persist: Writing %lu events", (unsigned long)appEventsState.inFlightEvents.count];

        if (!appEventsState.inFlightEvents.count) {
            return;
        }

        NSDictionary *appEventData = @{
            GBAppEventsPersistKeyNumSkipped   : [NSNumber numberWithInt:appEventsState.numSkippedEventsDueToFullBuffer],
            GBAppEventsPersistKeyEvents       : appEventsState.inFlightEvents,
        };

        content = [GBUtility simpleJSONEncode:appEventData];

        [appEventsState clearInFlightAndStats];
    }

    //save content to the documents directory
    [content writeToFile:[GBAppEvents persistenceFilePath]
              atomically:YES
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];

}

+ (NSDictionary *)retrievePersistedAppEventData {

    NSString *content = [[NSString alloc] initWithContentsOfFile:[GBAppEvents persistenceFilePath]
                                                    usedEncoding:nil
                                                           error:nil];
    NSDictionary *results = [GBUtility simpleJSONDecode:content];
    [content release];

    [GBLogger singleShotLogEntry:GBLoggingBehaviorAppEvents
                    formatString:@"GBAppEvents Persist: Read %lu events",
                    (unsigned long)(results ? [[results objectForKey:GBAppEventsPersistKeyEvents] count] : 0)];
    return results;
}

+ (void)clearPersistedAppEventData {

    [GBLogger singleShotLogEntry:GBLoggingBehaviorAppEvents
                        logEntry:@"GBAppEvents Persist: Clearing"];
    [[NSFileManager defaultManager] removeItemAtPath:[GBAppEvents persistenceFilePath] error:nil];
}

+ (NSString *)persistenceFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDirectory = [paths objectAtIndex:0];
    return [docDirectory stringByAppendingPathComponent:GBAppEventsPersistedEventsFilename];
}

+ (void)ensureOnMainThread {
    GBConditionalLog([NSThread isMainThread], @"*** This method expected to be called on the main thread.");
}

#pragma mark - Custom Audience token stuff

// This code lives here in GBAppEvents because it shares many of the runtime characteristics of the GBAppEvents logging,
// even though the public exposure is elsewhere

+ (GBRequest *)customAudienceThirdPartyIDRequest:(GBSession *)session {
    return [GBAppEvents.singleton instanceCustomAudienceThirdPartyIDRequest:session];
}


- (GBRequest *)instanceCustomAudienceThirdPartyIDRequest:(GBSession *)session {

    // Rules for how we use the attribution ID / advertiser ID for an 'custom_audience_third_party_id' Graph API request
    // 1) if the OS tells us that the user has Limited Ad Tracking, then just don't send, and return a nil in the token.
    // 2) if the app has set 'limitEventAndDataUsage', this effectively implies that app-initiated ad targeting shouldn't happen,
    //    so use that data here to return nil as well.
    // 3) if we have a user session token, then no need to send attribution ID / advertiser ID back as the udid parameter
    // 4) otherwise, send back the udid parameter.

    if ([GBUtility advertisingTrackingStatus] == AdvertisingTrackingDisallowed || [GBSettings limitEventAndDataUsage]) {
        return nil;
    }

    GBSession *sessionToSendRequestTo = [self sessionToSendRequestTo:session];
    NSString *udid = nil;
    if (![self doesSessionHaveUserToken:sessionToSendRequestTo]) {

        // We don't have a logged in user, so we need some form of udid representation.  Prefer
        // advertiser ID if available, and back off to attribution ID if not.
        udid = [GBUtility advertiserID];
        if (!udid) {
            udid = [GBUtility attributionID];
        }

        if (!udid) {
            // No udid, and no user token.  No point in making the request.
            return nil;
        }
    }

    NSDictionary *parameters = nil;
    if (udid) {
        parameters = @{ @"udid" : udid };
    }

    NSString *graphPath = [NSString stringWithFormat:@"%@/custom_audience_third_party_id", sessionToSendRequestTo.appID];
    GBRequest *request = [[[GBRequest alloc] initWithSession:sessionToSendRequestTo
                                                   graphPath:graphPath
                                                  parameters:parameters
                                                  HTTPMethod:nil]
                          autorelease];
    request.canCloseSessionOnError = NO;

    return request;
}

+ (NSString *)flushReasonToString:(GBAppEventsFlushReason)flushReason {

    NSString *result = @"Unknown";
    switch (flushReason) {
        case GBAppEventsFlushReasonExplicit:
            result = @"Explicit";
            break;

        case GBAppEventsFlushReasonTimer:
            result = @"Timer";
            break;

        case GBAppEventsFlushReasonSessionChange:
            result = @"SessionChange";
            break;

        case GBAppEventsFlushReasonPersistedEvents:
            result = @"PersistedEvents";
            break;

        case GBAppEventsFlushReasonEventThreshold:
            result = @"EventCountThreshold";
            break;

        case GBAppEventsFlushReasonEagerlyFlushingEvent:
            result = @"EagerlyFlushingEvent";
            break;
    }

    return result;
}

@end
