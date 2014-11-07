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

#import "GBSession.h"
#import "GBSession+Internal.h"

#import <Accounts/Accounts.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>

#import "GBAccessTokenData+Internal.h"
#import "GBAppBridge.h"
#import "GBAppCall+Internal.h"
#import "GBAppEvents+Internal.h"
#import "GBAppEvents.h"
#import "GBDataDiskCache.h"
#import "GBDialogs+Internal.h"
#import "GBError.h"
#import "GBLogger.h"
#import "GBLoginDialog.h"
#import "GBLoginDialogParams.h"
#import "GBSession+Protected.h"
#import "GBSessionAppSwitchingLoginStategy.h"
#import "GBSessionAuthLogger.h"
#import "GBSessionInlineWebViewLoginStategy.h"
#import "GBSessionSystemLoginStategy.h"
#import "GBSessionTokenCachingStrategy.h"
#import "GBSessionUtility.h"
#import "GBSettings+Internal.h"
#import "GBSettings.h"
#import "GBSystemAccountStoreAdapter.h"
#import "GBUtility.h"
#import "Gbomb.h"

static NSString *const GBAuthURLScheme = @"gbauth";
static NSString *const GBAuthURLPath = @"authorize";
//static NSString *const GBRedirectURL = @"gbconnect://success";
static NSString *const GBLoginDialogMethod = @"oauth";
static NSString *const GBLoginUXClientID = @"client_id";
static NSString *const GBLoginUXRedirectURI = @"redirect_uri";
static NSString *const GBLoginUXTouch = @"touch";
static NSString *const GBLoginUXDisplay = @"display";
static NSString *const GBLoginUXIOS = @"ios";
static NSString *const GBLoginUXSDK = @"sdk";
//static NSString *const GBLoginUXReturnScopesYES = @"true";
//static NSString *const GBLoginUXReturnScopes = @"return_scopes";
static NSString *const GBLoginParamsExpiresIn = @"expires_in";
static NSString *const GBLoginParamsPermissions = @"permissions";
static NSString *const GBLoginParamsGrantedscopes = @"granted_scopes";
NSString *const GBLoginUXResponseTypeToken = @"code";
NSString *const GBLoginUXResponseType = @"response_type";


// client state related strings
NSString *const GBLoginUXClientState = @"state";
NSString *const GBLoginUXClientStateIsClientState = @"com.facebook.sdk_client_state";
NSString *const GBLoginUXClientStateIsOpenSession = @"is_open_session";
NSString *const GBLoginUXClientStateIsActiveSession = @"is_active_session";

// the following constant strings are used by NSNotificationCenter
NSString *const GBSessionDidSetActiveSessionNotification = @"com.facebook.sdk:GBSessionDidSetActiveSessionNotification";
NSString *const GBSessionDidUnsetActiveSessionNotification = @"com.facebook.sdk:GBSessionDidUnsetActiveSessionNotification";
NSString *const GBSessionDidBecomeOpenActiveSessionNotification = @"com.facebook.sdk:GBSessionDidBecomeOpenActiveSessionNotification";
NSString *const GBSessionDidBecomeClosedActiveSessionNotification = @"com.facebook.sdk:GBSessionDidBecomeClosedActiveSessionNotification";
NSString *const GBSessionDidSetActiveSessionNotificationUserInfoIsOpening = @"com.facebook.sdk:GBSessionDidSetActiveSessionNotificationUserInfoIsOpening";

// the following const strings name properties for which KVO is manually handled
// if name changes occur, these strings must be modified to match, else KVO will fail
static NSString *const GBisOpenPropertyName = @"isOpen";
static NSString *const GBstatusPropertyName = @"state";
static NSString *const GBaccessTokenPropertyName = @"accessToken";
static NSString *const GBexpirationDatePropertyName = @"expirationDate";
static NSString *const GBaccessTokenDataPropertyName = @"accessTokenData";

static int const GBTokenExtendThresholdSeconds = 24 * 60 * 60;  // day
static int const GBTokenRetryExtendSeconds = 60 * 60;           // hour

// the following constant strings are used as keys into response url parameters during authorization flow

// Key used to access an inner error object in the response parameters. Currently used by Native Login only.
NSString *const GBInnerErrorObjectKey = @"inner_error_object";

NSString *const GbombNativeApplicationLoginDomain = @"com.gbombgames.platform.login";

// module scoped globals
static GBSession *g_activeSession = nil;

@interface GBSession () <GBLoginDialogDelegate> {
    @protected
    // public-property ivars
    NSString *_urlSchemeSuffix;

    // private property and non-property ivars
    BOOL _isInStateTransition;
    GBSessionLoginType _loginTypeOfPendingOpenUrlCallback;
    GBSessionDefaultAudience _defaultDefaultAudience;
    GBSessionLoginBehavior _loginBehavior;
}

// private setters
@property (readwrite) GBSessionState state;
@property (readwrite, copy) NSString *appID;
@property (readwrite, copy) NSString *urlSchemeSuffix;
@property (readwrite, copy) GBAccessTokenData *accessTokenData;
@property (readwrite, copy) NSArray *initializedPermissions;
@property (readwrite, assign) GBSessionDefaultAudience lastRequestedSystemAudience;
// A hack to the session state machine to enable repairing of sessions
// (i.e., for sessions whose token have been invalidated such as by
// expiration or password change was NOT un-tossed). We use this flag
// to avoid changing the GBSessionState surface area and to re-use
// the re-auth flow.
@property (atomic, assign) BOOL isRepairing;


// private properties
@property (readwrite, retain) GBSessionTokenCachingStrategy *tokenCachingStrategy;
@property (readwrite, copy) NSDate *attemptedRefreshDate;
@property (readwrite, copy) NSDate *attemptedPermissionsRefreshDate;
@property (readwrite, copy) GBSessionStateHandler loginHandler;
@property (readwrite, copy) GBSessionRequestPermissionResultHandler reauthorizeHandler;
@property (readonly) NSString *appBaseUrl;
@property (readwrite, retain) GBLoginDialog *loginDialog;
@property (readwrite, retain) NSThread *affinitizedThread;
@property (readwrite, retain) GBSessionAppEventsState *appEventsState;
@property (readwrite, retain) GBSessionAuthLogger *authLogger;

@property (readwrite, copy) NSString *code;
//@property (readwrite, copy) NSString *sessionKey;
@property (readwrite, copy) NSDictionary *parameters;
@property (readwrite, copy) NSString *redirectUri;
@end

@implementation GBSession : NSObject

#pragma mark Lifecycle

- (id)init {
    return [self initWithAppID:nil
                   permissions:nil
               urlSchemeSuffix:nil
            tokenCacheStrategy:nil];
}

- (id)initWithPermissions:(NSArray*)permissions {
    return [self initWithAppID:nil
                   permissions:permissions
               urlSchemeSuffix:nil
            tokenCacheStrategy:nil];
}

- (id)initWithAppID:(NSString*)appID
        permissions:(NSArray*)permissions
    urlSchemeSuffix:(NSString*)urlSchemeSuffix
 tokenCacheStrategy:(GBSessionTokenCachingStrategy*)tokenCachingStrategy {
    return [self initWithAppID:appID
                   permissions:permissions
               defaultAudience:GBSessionDefaultAudienceNone
               urlSchemeSuffix:urlSchemeSuffix
            tokenCacheStrategy:tokenCachingStrategy];
}

- (id)initWithAppID:(NSString*)appID
        permissions:(NSArray*)permissions
    defaultAudience:(GBSessionDefaultAudience)defaultAudience
    urlSchemeSuffix:(NSString*)urlSchemeSuffix
 tokenCacheStrategy:(GBSessionTokenCachingStrategy*)tokenCachingStrategy {
    self = [super init];
    if (self) {

        // setup values where nil implies a default
        if (!appID) {
            appID = [GBSettings defaultAppID];
        }
        if (!permissions) {
            permissions = [NSArray array];
        }
        if (!urlSchemeSuffix) {
            urlSchemeSuffix = [GBSettings defaultUrlSchemeSuffix];
        }
        if (!tokenCachingStrategy) {
            tokenCachingStrategy = [GBSessionTokenCachingStrategy defaultInstance];
        }

        // if we don't have an appID by here, fail -- this is almost certainly an app-bug
        if (!appID) {
            [[NSException exceptionWithName:GBInvalidOperationException
                                     reason:@"GBSession: No AppID provided; either pass an "
                                            @"AppID to init, or add a string valued key with the "
                                            @"appropriate id named FacebookAppID to the bundle *.plist"
                                   userInfo:nil]
             raise];
        }

        // assign arguments;
        _appID = [appID copy];
        _initializedPermissions = [permissions copy];
        _urlSchemeSuffix = [urlSchemeSuffix copy];
        _tokenCachingStrategy = [tokenCachingStrategy retain];

        // additional setup
        _isInStateTransition = NO;
        _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeNone;
        _defaultDefaultAudience = defaultAudience;
        _appEventsState = [[GBSessionAppEventsState alloc] init];

        _attemptedRefreshDate = [[NSDate distantPast] copy];
        _attemptedPermissionsRefreshDate = [[NSDate distantPast] copy];
        _state = GBSessionStateCreated;
        _affinitizedThread = [[NSThread currentThread] retain];

        [GBLogger registerCurrentTime:GBLoggingBehaviorPerformanceCharacteristics
                              withTag:self];
        //GBAccessTokenData *cachedTokenData = [self.tokenCachingStrategy fetchGBAccessTokenData];
        GBAccessTokenData *cachedTokenData = nil;
        if (cachedTokenData && ![self initializeFromCachedToken:cachedTokenData withPermissions:permissions]){
            [self.tokenCachingStrategy clearToken];
        };

        [GBSettings autoPublishInstall:self.appID];
        _loginBehavior = GBSessionLoginBehaviorUseSystemAccountIfPresent;
    }
    return self;
}

// Helper method to initialize current state from a cached token. This will transition to
// GBSessionStateCreatedTokenLoaded if the `cachedToken` is viable and return YES. Otherwise, it returns NO.
// This method will return NO immediately if the current state is not GBSessionStateCreated.
- (BOOL)initializeFromCachedToken:(GBAccessTokenData *) cachedToken withPermissions:(NSArray *)permissions
{
    if (cachedToken && self.state == GBSessionStateCreated) {
        BOOL isSubset = [GBSessionUtility areRequiredPermissions:permissions
                                            aSubsetOfPermissions:cachedToken.permissions];

        if (isSubset && (NSOrderedDescending == [cachedToken.expirationDate compare:[NSDate date]])) {
            [self transitionToState:GBSessionStateCreatedTokenLoaded
                withAccessTokenData:cachedToken
                        shouldCache:NO];
            return YES;
        }
    }
    return NO;
}

- (void)dealloc {
    [_loginDialog release];
    [_attemptedRefreshDate release];
    [_attemptedPermissionsRefreshDate release];
    [_accessTokenData release];
    [_reauthorizeHandler release];
    [_loginHandler release];
    [_appID release];
    [_urlSchemeSuffix release];
    [_initializedPermissions release];
    [_tokenCachingStrategy release];
    [_affinitizedThread release];
    [_appEventsState release];
    [_authLogger release];
    [_code release];
    [_parameters release];
    [_redirectUri release];
    [super dealloc];
}

#pragma mark - Public Properties

- (NSArray *)permissions {
    if (self.accessTokenData) {
        return self.accessTokenData.permissions;
    } else {
        return self.initializedPermissions;
    }
}

- (NSDate *)refreshDate {
    return self.accessTokenData.refreshDate;
}

- (NSString *)accessToken {
    return self.accessTokenData.accessToken;
}

- (NSDate *)expirationDate {
    return self.accessTokenData.expirationDate;
}

- (GBSessionLoginType) loginType {
    if (self.accessTokenData) {
        return self.accessTokenData.loginType;
    } else {
        return GBSessionLoginTypeNone;
    }
}

#pragma mark - Public Members

- (void)openWithRedirectUri:(NSString*)redirectUri
        completionHandler:(GBSessionStateHandler)handler {
    //[self openWithBehavior:GBSessionLoginBehaviorWithFallbackToWebView completionHandler:handler];
    if(!redirectUri) {
        NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];        
        _redirectUri=[infoDict objectForKey:@"FacebookRedirectUri"];
    }
    else {
        _redirectUri=[redirectUri copy];
    }
    [self openWithBehavior:GBSessionLoginBehaviorForcingWebView completionHandler:handler];
}

- (void)openWithCompletionHandler:(GBSessionStateHandler)handler {
    //[self openWithBehavior:GBSessionLoginBehaviorWithFallbackToWebView completionHandler:handler];
    [self openWithBehavior:GBSessionLoginBehaviorForcingWebView completionHandler:handler];
}

- (void)openWithBehavior:(GBSessionLoginBehavior)behavior
       completionHandler:(GBSessionStateHandler)handler {

    [self checkThreadAffinity];

    switch (behavior) {
        case GBSessionLoginBehaviorForcingWebView:
        case GBSessionLoginBehaviorUseSystemAccountIfPresent:
        case GBSessionLoginBehaviorWithFallbackToWebView:
        case GBSessionLoginBehaviorWithNoFallbackToWebView:
            // valid behavior; no-op.
            break;
        default:
            [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors formatString:@"%d is not a valid GBSessionLoginBehavior. Ignoring open call.", behavior];
            return;
    }
    if (!(self.state == GBSessionStateCreated ||
          self.state == GBSessionStateCreatedTokenLoaded)) {
        // login may only be called once, and only from one of the two initial states
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBSession: an attempt was made to open an already opened or closed session"
                               userInfo:nil]
         raise];
    }
    _loginBehavior = behavior;
    if (handler != nil) {
        // Note blocks are not value comparable, so this can intentionally result in false positives; nonetheless, let's
        // log it for easier identification/reporting in case developers do run into this edge case unexpectedly.
        if (self.loginHandler != NULL && self.loginHandler != handler) {
            [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors logEntry:@"An existing state change handler was assigned to the session and will be overwritten."];
        }
        self.loginHandler = handler;
    }

    // normal login depends on the availability of a valid cached token
    if (self.state == GBSessionStateCreated) {

        // set the state and token info
        [self transitionToState:GBSessionStateCreatedOpening
            withAccessTokenData:nil
                    shouldCache:NO];

        [self authorizeWithPermissions:self.initializedPermissions
                              behavior:behavior
                       defaultAudience:_defaultDefaultAudience
                         isReauthorize:NO];

    } else { // self.status == GBSessionStateLoadedValidToken

        // this case implies that a valid cached token was found, and preserves the
        // "1-session-1-identity" rule, by transitioning to logged in, without a transition to login UX
        [self transitionAndCallHandlerWithState:GBSessionStateOpen
                                          error:nil
                                      tokenData:nil
                                    shouldCache:NO];
    }
}

- (void)reauthorizeWithPermissions:(NSArray*)permissions
                          behavior:(GBSessionLoginBehavior)behavior
                 completionHandler:(GBSessionReauthorizeResultHandler)handler {
    [self reauthorizeWithPermissions:permissions
                              isRead:NO
                            behavior:behavior
                     defaultAudience:GBSessionDefaultAudienceNone
                   completionHandler:handler];
}

- (void)reauthorizeWithReadPermissions:(NSArray*)readPermissions
                     completionHandler:(GBSessionReauthorizeResultHandler)handler {
    [self requestNewReadPermissions:readPermissions
                  completionHandler:handler];
}

- (void)reauthorizeWithPublishPermissions:(NSArray*)writePermissions
                        defaultAudience:(GBSessionDefaultAudience)audience
                      completionHandler:(GBSessionReauthorizeResultHandler)handler {
    [self requestNewPublishPermissions:writePermissions
                       defaultAudience:audience
                     completionHandler:handler];
}

- (void)requestNewReadPermissions:(NSArray*)readPermissions
                completionHandler:(GBSessionRequestPermissionResultHandler)handler {
    [self reauthorizeWithPermissions:readPermissions
                              isRead:YES
                            behavior:_loginBehavior
                     defaultAudience:GBSessionDefaultAudienceNone
                   completionHandler:handler];
}

- (void)requestNewPublishPermissions:(NSArray*)writePermissions
                     defaultAudience:(GBSessionDefaultAudience)audience
                   completionHandler:(GBSessionRequestPermissionResultHandler)handler {
    [self reauthorizeWithPermissions:writePermissions
                              isRead:NO
                            behavior:_loginBehavior
                     defaultAudience:audience
                   completionHandler:handler];
}

- (void)close {
    [self checkThreadAffinity];

    GBSessionState state;
    if (self.state == GBSessionStateCreatedOpening) {
        state = GBSessionStateClosedLoginFailed;
    } else {
        state = GBSessionStateClosed;
    }

    [self transitionAndCallHandlerWithState:state
                                      error:nil
                                  tokenData:nil
                                shouldCache:NO];
}

- (void)closeAndClearTokenInformation {
    [self closeAndClearTokenInformation:nil];
}

// Helper method to transistion token state correctly when
// the app is called back in cases of either app switch
// or GBLoginDialog
- (BOOL)handleAuthorizationCallbacks:(NSString *)accessToken params:(NSDictionary *)params loginType:(GBSessionLoginType)loginType {
    // Make sure our logger is setup to finish up the authorization roundtrip
    if (!self.authLogger) {
        NSDictionary *clientState = [GBSessionUtility clientStateFromQueryParams:params];
        NSString *ID = clientState[GBSessionAuthLoggerParamIDKey];
        NSString *authMethod = clientState[GBSessionAuthLoggerParamAuthMethodKey];
        if (ID || authMethod) {
            self.authLogger = [[[GBSessionAuthLogger alloc] initWithSession:self ID:ID authMethod:authMethod] autorelease];
        }
    }

    switch (self.state) {
        case GBSessionStateCreatedOpening:
            return [self handleAuthorizationOpen:params
                                     accessToken:accessToken
                                       loginType:loginType];
        case GBSessionStateOpen:
        case GBSessionStateOpenTokenExtended:
            if (loginType == GBSessionLoginTypeNone){
                // If loginType == None, then we were not expecting a re-auth
                // and entered here from an app link into an existing session
                // so we should immediately return NO to prevent a false transition
                // to TokenExtended.
                return NO;
            } else {
                return [self handleReauthorize:params
                                   accessToken:accessToken];
            }
        default:
            return NO;
    }
}

- (BOOL)handleOpenURL:(NSURL *)url {
    [self checkThreadAffinity];

    NSDictionary *params = [GBSessionUtility queryParamsFromLoginURL:url
                                                        appID:self.appID
                                              urlSchemeSuffix:self.urlSchemeSuffix];

    // if the URL's structure doesn't match the structure used for Facebook authorization, abort.
    if (!params) {
        // We need to not discard native login responses, since the app might not have updated its
        // AppDelegate to call into GBAppCall. We are impersonating the native Facebook application's
        // bundle Id here. This is no less secure than old GBSession url handling
        __block BOOL completionHandlerFound = YES;
        BOOL handled = [[GBAppBridge sharedInstance] handleOpenURL:url
                                                 sourceApplication:@"com.facebook.Facebook"
                                                           session:self
                                                   fallbackHandler:^(GBAppCall *call) {
                                                       completionHandlerFound = NO;
                                                   }];
        return handled && completionHandlerFound;
    }
    GBSessionLoginType loginType = _loginTypeOfPendingOpenUrlCallback;
    _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeNone;

    NSString *accessToken = [params objectForKey:@"access_token"];

    return [self handleAuthorizationCallbacks:accessToken params:params loginType:loginType];
}

- (BOOL)openFromAccessTokenData:(GBAccessTokenData *)accessTokenData completionHandler:(GBSessionStateHandler) handler {
    return [self openFromAccessTokenData:accessTokenData
                       completionHandler:handler
            raiseExceptionIfInvalidState:YES];
}

- (void)handleDidBecomeActive {
    // Unexpected calls to app delegate's applicationDidBecomeActive are
    // handled by this method. If a pending fast-app-switch [re]authorization
    // is in flight, it is cancelled. Otherwise, this method is a no-op.
    [self authorizeRequestWasImplicitlyCancelled];

    // This is forward-compatibility. If an AppDelegate isn't updated to use AppCall,
    // we still want to provide a good AppBridge experience if possible.
    [[GBAppBridge sharedInstance] handleDidBecomeActive];
}

- (BOOL)isOpen {
    return GB_ISSESSIONOPENWITHSTATE(self.state);
}

- (NSString*)urlSchemeSuffix {
    [self checkThreadAffinity];
    return _urlSchemeSuffix ? _urlSchemeSuffix : @"";
}

// actually a private member, but wanted to be close to its public colleague
- (void)setUrlSchemeSuffix:(NSString*)newValue {
    if (_urlSchemeSuffix != newValue) {
        [_urlSchemeSuffix release];
        _urlSchemeSuffix = [(newValue ? newValue : @"") copy];
    }
}

- (void)setStateChangeHandler:(GBSessionStateHandler)stateChangeHandler {
    if (stateChangeHandler != NULL) {
        if (self.loginHandler) {
            [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors logEntry:@"An existing state change handler was assigned to the session and will be overwritten."];
        }
        self.loginHandler = [stateChangeHandler copy];
    }
}

#pragma mark -
#pragma mark Class Methods

+ (BOOL)openActiveSessionWithAllowLoginUI:(BOOL)allowLoginUI {
    return [GBSession openActiveSessionWithPermissions:nil
                                          allowLoginUI:allowLoginUI
                                    allowSystemAccount:YES
                                                isRead:YES
                                       defaultAudience:GBSessionDefaultAudienceNone
                                     completionHandler:nil];
}

+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                            allowLoginUI:(BOOL)allowLoginUI
                       completionHandler:(GBSessionStateHandler)handler {
    return [GBSession openActiveSessionWithPermissions:permissions
                                          allowLoginUI:allowLoginUI
                                       defaultAudience:GBSessionDefaultAudienceNone
                                     completionHandler:handler];
}

// This should only be used by internal code that needs to support mixed
// permissions backwards compability and specify an audience.
+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                            allowLoginUI:(BOOL)allowLoginUI
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                       completionHandler:(GBSessionStateHandler)handler {
    return [GBSession openActiveSessionWithPermissions:permissions
                                          allowLoginUI:allowLoginUI
                                    allowSystemAccount:NO
                                                isRead:NO
                                       defaultAudience:defaultAudience
                                     completionHandler:handler];
}

+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                           loginBehavior:(GBSessionLoginBehavior)loginBehavior
                                  isRead:(BOOL)isRead
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                       completionHandler:(GBSessionStateHandler)handler {
    return [GBSession openActiveSessionWithPermissions:permissions
                                          allowLoginUI:YES
                                         loginBehavior:loginBehavior
                                                isRead:isRead
                                       defaultAudience:defaultAudience
                                     completionHandler:handler];
}

+ (BOOL)openActiveSessionWithReadPermissions:(NSArray*)readPermissions
                                allowLoginUI:(BOOL)allowLoginUI
                           completionHandler:(GBSessionStateHandler)handler {
    return [GBSession openActiveSessionWithPermissions:readPermissions
                                          allowLoginUI:allowLoginUI
                                    allowSystemAccount:YES
                                                isRead:YES
                                       defaultAudience:GBSessionDefaultAudienceNone
                                     completionHandler:handler];
}

+ (BOOL)openActiveSessionWithPublishPermissions:(NSArray*)publishPermissions
                                defaultAudience:(GBSessionDefaultAudience)defaultAudience
                                   allowLoginUI:(BOOL)allowLoginUI
                              completionHandler:(GBSessionStateHandler)handler {
    return [GBSession openActiveSessionWithPermissions:publishPermissions
                                          allowLoginUI:allowLoginUI
                                    allowSystemAccount:YES
                                                isRead:NO
                                       defaultAudience:defaultAudience
                                     completionHandler:handler];
}

+ (GBSession*)activeSession {
    if (!g_activeSession) {
        GBSession *session = [[GBSession alloc] init];
        [GBSession setActiveSession:session];
        [session release];
    }
    return [[g_activeSession retain] autorelease];
}

+ (GBSession*)setActiveSession:(GBSession*)session {
    return [self setActiveSession:session userInfo:nil];
}

+ (GBSession*)setActiveSession:(GBSession*)session userInfo:(NSDictionary*)userInfo {

    if (session != g_activeSession) {
        // we will close this, but we want any resulting
        // handlers to see the new active session
        GBSession *toRelease = g_activeSession;

        // if we are being replaced, then we close you
        [toRelease close];

        // set the new session
        g_activeSession = [session retain];

        // some housekeeping needs to happen if we had a previous session
        if (toRelease) {
            // now the notification/release of the prior active
            [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidUnsetActiveSessionNotification
                                                                object:toRelease];
            [toRelease release];
        }

        // we don't notify nil sets
        if (session) {
            [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidSetActiveSessionNotification
                                                                object:session
                                                              userInfo:userInfo];

            if (session.isOpen) {
                [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidBecomeOpenActiveSessionNotification
                                                                    object:session
                                                                  userInfo:userInfo];
            }
        }
    }

    return session;
}

+ (void)setDefaultAppID:(NSString*)appID {
    [GBSettings setDefaultAppID:appID];
}

+ (NSString*)defaultAppID {
    return [GBSettings defaultAppID];
}

+ (void)setDefaultUrlSchemeSuffix:(NSString*)urlSchemeSuffix {
    [GBSettings setDefaultUrlSchemeSuffix:urlSchemeSuffix];
}

+ (NSString*)defaultUrlSchemeSuffix {
    return [GBSettings defaultUrlSchemeSuffix];
}

+ (void)renewSystemCredentials:(GBSessionRenewSystemCredentialsHandler) handler {
    [[GBSystemAccountStoreAdapter sharedInstance] renewSystemAuthorization:handler];
}

#pragma mark -
#pragma mark Private Members (core session members)

// private methods are broken into two categories: core session and helpers

// core member that owns all state transitions as well as property setting for status and isOpen
// `tokenData` will NOT be retained, it will be used to construct a
// new instance - the difference is for things that should not change
// if the session already had a token (e.g., loginType).
- (BOOL)transitionToState:(GBSessionState)state
      withAccessTokenData:(GBAccessTokenData *)tokenData
              shouldCache:(BOOL)shouldCache {

    // is this a valid transition?
    BOOL isValidTransition;
    GBSessionState statePrior;

    statePrior = self.state;
    switch (state) {
        default:
        case GBSessionStateCreated:
            isValidTransition = NO;
            break;
        case GBSessionStateOpen:
            isValidTransition = (
                                 statePrior == GBSessionStateCreatedTokenLoaded ||
                                 statePrior == GBSessionStateCreatedOpening
                                 );
            break;
        case GBSessionStateCreatedOpening:
        case GBSessionStateCreatedTokenLoaded:
            isValidTransition = statePrior == GBSessionStateCreated;
            break;
        case GBSessionStateClosedLoginFailed:
            isValidTransition = statePrior == GBSessionStateCreatedOpening;
            break;
        case GBSessionStateOpenTokenExtended:
            isValidTransition = (
                                 statePrior == GBSessionStateOpen ||
                                 statePrior == GBSessionStateOpenTokenExtended
                                 );
            break;
        case GBSessionStateClosed:
            isValidTransition = (
                                 statePrior == GBSessionStateOpen ||
                                 statePrior == GBSessionStateOpenTokenExtended
                                 );
            break;
    }

    // invalid transition short circuits
    if (!isValidTransition) {
        [GBLogger singleShotLogEntry:GBLoggingBehaviorSessionStateTransitions
                            logEntry:[NSString stringWithFormat:@"GBSession **INVALID** transition from %@ to %@",
                                      [GBSessionUtility sessionStateDescription:statePrior],
                                      [GBSessionUtility sessionStateDescription:state]]];
        return NO;
    }

    // if this is yes, someone called a method on GBSession from within a KVO will change handler
    if (_isInStateTransition) {
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBSession: An attempt to change an GBSession object was "
                                        @"made while a change was in flight; this is most likely due to "
                                        @"a KVO observer calling a method on GBSession while handling a "
                                        @"NSKeyValueObservingOptionPrior notification"
                               userInfo:nil]
         raise];
    }

    // valid transitions notify
    NSString *logString = [NSString stringWithFormat:@"GBSession transition from %@ to %@ ",
                           [GBSessionUtility sessionStateDescription:statePrior],
                           [GBSessionUtility sessionStateDescription:state]];
    [GBLogger singleShotLogEntry:GBLoggingBehaviorSessionStateTransitions logEntry:logString];

    [GBLogger singleShotLogEntry:GBLoggingBehaviorPerformanceCharacteristics
                    timestampTag:self
                    formatString:@"%@", logString];

    // Re-start session transition timer for the next time around.
    [GBLogger registerCurrentTime:GBLoggingBehaviorPerformanceCharacteristics
                          withTag:self];

    // identify whether we will update token and date, and what the values will be
    BOOL changingTokenAndDate = NO;
    if (tokenData.accessToken && tokenData.expirationDate) {
        changingTokenAndDate = YES;
    } else if (!GB_ISSESSIONOPENWITHSTATE(state) &&
               GB_ISSESSIONOPENWITHSTATE(statePrior)) {
        changingTokenAndDate = YES;
        tokenData = nil;
    }

    BOOL changingIsOpen = GB_ISSESSIONOPENWITHSTATE(state) != GB_ISSESSIONOPENWITHSTATE(statePrior);

    // should only ever be YES from here...
    _isInStateTransition = YES;

    // KVO property will change notifications, for state change
    [self willChangeValueForKey:GBstatusPropertyName];
    if (changingIsOpen) {
        [self willChangeValueForKey:GBisOpenPropertyName];
    }

    if (changingTokenAndDate) {
        GBSessionLoginType newLoginType = tokenData.loginType;
        // if we are just about to transition to open or token loaded, and the caller
        // wants to specify a login type other than none, then we set the login type
        GBSessionLoginType loginTypeUpdated = self.accessTokenData.loginType;
        if (isValidTransition &&
            (state == GBSessionStateOpen || state == GBSessionStateCreatedTokenLoaded) &&
            newLoginType != GBSessionLoginTypeNone) {
            loginTypeUpdated = newLoginType;
        }

        // KVO property will-change notifications for token and date
        [self willChangeValueForKey:GBaccessTokenPropertyName];
        [self willChangeValueForKey:GBaccessTokenDataPropertyName];
        [self willChangeValueForKey:GBexpirationDatePropertyName];

        // set the new access token as a copy of any existing token with the updated
        // token string and expiration date.
        // Note if we're opening for the first time, we always set permissions refresh date to distantPast
        // to force a permissions refresh piggyback with the next request.
        if (tokenData.accessToken) {
            GBAccessTokenData *gbAccessToken = [GBAccessTokenData createTokenFromString:tokenData.accessToken
                                                                            permissions:tokenData.permissions
                                                                         expirationDate:tokenData.expirationDate
                                                                              loginType:loginTypeUpdated
                                                                            refreshDate:tokenData.refreshDate
                                                                 permissionsRefreshDate:changingIsOpen ? [NSDate distantPast] : tokenData.permissionsRefreshDate];
            self.accessTokenData = gbAccessToken;
        } else {
            self.accessTokenData = nil;
        }
    }

    // change the actual state
    // note: we should not inject any callbacks between this and the token/date changes above
    self.state = state;

    // ... to here -- if YES
    _isInStateTransition = NO;

    if (changingTokenAndDate) {
        // update the cache
        if (shouldCache) {
            [self.tokenCachingStrategy cacheGBAccessTokenData:self.accessTokenData];
        }

        // KVO property change notifications token and date
        [self didChangeValueForKey:GBexpirationDatePropertyName];
        [self didChangeValueForKey:GBaccessTokenPropertyName];
        [self didChangeValueForKey:GBaccessTokenDataPropertyName];
    }

    // KVO property did change notifications, for state change
    if (changingIsOpen) {
        [self didChangeValueForKey:GBisOpenPropertyName];
    }
    [self didChangeValueForKey:GBstatusPropertyName];

    // if we are the active session, and we changed is-valid, notify
    if (changingIsOpen && g_activeSession == self) {
        if (GB_ISSESSIONOPENWITHSTATE(state)) {
            [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidBecomeOpenActiveSessionNotification
                                                                object:self];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidBecomeClosedActiveSessionNotification
                                                                object:self];
        }
    }

    // Note! It is important that no processing occur after the KVO notifications have been raised, in order to
    // assure the state is cohesive in common reintrant scenarios

    // the NO case short-circuits after the state switch/case
    return YES;
}

// private methods are broken into two categories: core session and helpers

// core member that owns all state transitions as well as property setting for status and isOpen
// `tokenData` will NOT be retained, it will be used to construct a
// new instance - the difference is for things that should not change
// if the session already had a token (e.g., loginType).
- (BOOL)transitionToState:(GBSessionState)state
      withCode:(NSString *)code {
    
    // is this a valid transition?
    BOOL isValidTransition;
    GBSessionState statePrior;
    
    statePrior = self.state;
    switch (state) {
        default:
        case GBSessionStateCreated:
            isValidTransition = NO;
            break;
        case GBSessionStateOpen:
            isValidTransition = (
                                 statePrior == GBSessionStateCreatedTokenLoaded ||
                                 statePrior == GBSessionStateCreatedOpening
                                 );
            break;
        case GBSessionStateCreatedOpening:
        case GBSessionStateCreatedTokenLoaded:
            isValidTransition = statePrior == GBSessionStateCreated;
            break;
        case GBSessionStateClosedLoginFailed:
            isValidTransition = statePrior == GBSessionStateCreatedOpening;
            break;
        case GBSessionStateOpenTokenExtended:
            isValidTransition = (
                                 statePrior == GBSessionStateOpen ||
                                 statePrior == GBSessionStateOpenTokenExtended
                                 );
            break;
        case GBSessionStateClosed:
            isValidTransition = (
                                 statePrior == GBSessionStateOpen ||
                                 statePrior == GBSessionStateOpenTokenExtended
                                 );
            break;
    }
    
    // invalid transition short circuits
    if (!isValidTransition) {
        [GBLogger singleShotLogEntry:GBLoggingBehaviorSessionStateTransitions
                            logEntry:[NSString stringWithFormat:@"GBSession **INVALID** transition from %@ to %@",
                                      [GBSessionUtility sessionStateDescription:statePrior],
                                      [GBSessionUtility sessionStateDescription:state]]];
        return NO;
    }
    
    // if this is yes, someone called a method on GBSession from within a KVO will change handler
    if (_isInStateTransition) {
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBSession: An attempt to change an GBSession object was "
          @"made while a change was in flight; this is most likely due to "
          @"a KVO observer calling a method on GBSession while handling a "
          @"NSKeyValueObservingOptionPrior notification"
                               userInfo:nil]
         raise];
    }
    
    // valid transitions notify
    NSString *logString = [NSString stringWithFormat:@"GBSession transition from %@ to %@ ",
                           [GBSessionUtility sessionStateDescription:statePrior],
                           [GBSessionUtility sessionStateDescription:state]];
    [GBLogger singleShotLogEntry:GBLoggingBehaviorSessionStateTransitions logEntry:logString];
    
    [GBLogger singleShotLogEntry:GBLoggingBehaviorPerformanceCharacteristics
                    timestampTag:self
                    formatString:@"%@", logString];
    
    // Re-start session transition timer for the next time around.
    [GBLogger registerCurrentTime:GBLoggingBehaviorPerformanceCharacteristics
                          withTag:self];
    

    
    BOOL changingIsOpen = GB_ISSESSIONOPENWITHSTATE(state) != GB_ISSESSIONOPENWITHSTATE(statePrior);
    
    // should only ever be YES from here...
    _isInStateTransition = YES;
    
    // KVO property will change notifications, for state change
    [self willChangeValueForKey:GBstatusPropertyName];
    if (changingIsOpen) {
        [self willChangeValueForKey:GBisOpenPropertyName];
    }
    
    
    // change the actual state
    // note: we should not inject any callbacks between this and the token/date changes above
    self.state = state;
    
    // ... to here -- if YES
    _isInStateTransition = NO;
    
    
    // KVO property did change notifications, for state change
    if (changingIsOpen) {
        [self didChangeValueForKey:GBisOpenPropertyName];
    }
    [self didChangeValueForKey:GBstatusPropertyName];
    
    // if we are the active session, and we changed is-valid, notify
    if (changingIsOpen && g_activeSession == self) {
        if (GB_ISSESSIONOPENWITHSTATE(state)) {
            [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidBecomeOpenActiveSessionNotification
                                                                object:self];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:GBSessionDidBecomeClosedActiveSessionNotification
                                                                object:self];
        }
    }
    
    // Note! It is important that no processing occur after the KVO notifications have been raised, in order to
    // assure the state is cohesive in common reintrant scenarios
    
    // the NO case short-circuits after the state switch/case
    return YES;
}

// core authorization UX flow
- (void)authorizeWithPermissions:(NSArray*)permissions
                        behavior:(GBSessionLoginBehavior)behavior
                 defaultAudience:(GBSessionDefaultAudience)audience
                   isReauthorize:(BOOL)isReauthorize {
    BOOL tryIntegratedAuth = behavior == GBSessionLoginBehaviorUseSystemAccountIfPresent;
    BOOL tryFacebookLogin = (behavior == GBSessionLoginBehaviorUseSystemAccountIfPresent) ||
    (behavior == GBSessionLoginBehaviorWithFallbackToWebView) ||
    (behavior == GBSessionLoginBehaviorWithNoFallbackToWebView);
    BOOL tryFallback =  (behavior == GBSessionLoginBehaviorWithFallbackToWebView) ||
    (behavior == GBSessionLoginBehaviorForcingWebView);

    [self authorizeWithPermissions:(NSArray*)permissions
                   defaultAudience:audience
                    integratedAuth:tryIntegratedAuth
                         GBAppAuth:tryFacebookLogin
                        safariAuth:tryFacebookLogin
                          fallback:tryFallback
                     isReauthorize:isReauthorize
               canFetchAppSettings:YES];
}

- (void)authorizeWithPermissions:(NSArray*)permissions
                 defaultAudience:(GBSessionDefaultAudience)defaultAudience
                  integratedAuth:(BOOL)tryIntegratedAuth
                       GBAppAuth:(BOOL)tryGBAppAuth
                      safariAuth:(BOOL)trySafariAuth
                        fallback:(BOOL)tryFallback
                   isReauthorize:(BOOL)isReauthorize
             canFetchAppSettings:(BOOL)canFetchAppSettings {
    self.authLogger = [[[GBSessionAuthLogger alloc] initWithSession:self] autorelease];
    [self.authLogger addExtrasForNextEvent:@{
     @"tryIntegratedAuth": [NSNumber numberWithBool:tryIntegratedAuth],
     @"tryGBAppAuth": [NSNumber numberWithBool:tryGBAppAuth],
     @"trySafariAuth": [NSNumber numberWithBool:trySafariAuth],
     @"tryFallback": [NSNumber numberWithBool:tryFallback],
     @"isReauthorize": [NSNumber numberWithBool:isReauthorize]
     }];

    [self.authLogger logStartAuth];

    [self retryableAuthorizeWithPermissions:permissions
                            defaultAudience:defaultAudience
                             integratedAuth:tryIntegratedAuth
                                  GBAppAuth:tryGBAppAuth
                                 safariAuth:trySafariAuth
                                   fallback:tryFallback
                              isReauthorize:isReauthorize
                        canFetchAppSettings:canFetchAppSettings];
}

// NOTE: This method should not be used as the "first" call in the auth-stack. It makes no assumptions about being
// the first either.
- (void)retryableAuthorizeWithPermissions:(NSArray*)permissions
                          defaultAudience:(GBSessionDefaultAudience)defaultAudience
                           integratedAuth:(BOOL)tryIntegratedAuth
                                GBAppAuth:(BOOL)tryGBAppAuth
                               safariAuth:(BOOL)trySafariAuth
                                 fallback:(BOOL)tryFallback
                            isReauthorize:(BOOL)isReauthorize
                      canFetchAppSettings:(BOOL)canFetchAppSettings {
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *redirectURI =nil;
    
    if(!_redirectUri) {
        redirectURI=[infoDict objectForKey:@"GbombRedirectUri"];
    }
    else {
        redirectURI=_redirectUri;
    }
    
    // setup parameters for either the safari or inline login
    //NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    //                               self.appID, GBLoginUXClientID,
    //                               GBLoginUXResponseTypeToken, GBLoginUXResponseType,
    //                               redirectURI, GBLoginUXRedirectURI,
    //                               GBLoginUXTouch, GBLoginUXDisplay,
    //                               GBLoginUXIOS, GBLoginUXSDK,
    //                               GBLoginUXReturnScopesYES, GBLoginUXReturnScopes,
    //                               nil];
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   self.appID, GBLoginUXClientID,
                                   GBLoginUXResponseTypeToken, GBLoginUXResponseType,
                                   redirectURI, GBLoginUXRedirectURI,
                                   GBLoginUXTouch, GBLoginUXDisplay,
                                   GBLoginUXIOS, GBLoginUXSDK,
                                   nil];
    
    if (permissions != nil) {
        params[@"scope"] = [permissions componentsJoinedByString:@","];
    }
    if (_urlSchemeSuffix) {
        params[@"local_client_id"] = _urlSchemeSuffix;
    }

    // To avoid surprises, delete any cookies we currently have.
    //[GBUtility deleteFacebookCookies];

    BOOL didRequestAuthorize = NO;
    NSString *authMethod = nil;

    GBSessionLoginStrategyParams *authorizeParams = [[[GBSessionLoginStrategyParams alloc] init] autorelease];
    authorizeParams.tryIntegratedAuth = tryIntegratedAuth;
    authorizeParams.tryGBAppAuth = tryGBAppAuth;
    authorizeParams.trySafariAuth = trySafariAuth;
    authorizeParams.tryFallback = tryFallback;
    authorizeParams.isReauthorize = isReauthorize;
    authorizeParams.defaultAudience = defaultAudience;
    authorizeParams.permissions = permissions;
    authorizeParams.canFetchAppSettings = canFetchAppSettings;
    authorizeParams.webParams = params;

    // Note ordering is significant here.
    NSArray *loginStrategies = @[ [[[GBSessionSystemLoginStategy alloc] init] autorelease],
                                  [[[GBSessionAppSwitchingLoginStategy alloc] init] autorelease],
                                  [[[GBSessionInlineWebViewLoginStategy alloc] init] autorelease]
                                  ];

    for (id<GBSessionLoginStrategy> loginStrategy in loginStrategies) {
        if ([loginStrategy tryPerformAuthorizeWithParams:authorizeParams session:self logger:self.authLogger]) {
            didRequestAuthorize = YES;
            authMethod = loginStrategy.methodName;
            break;
        }
    }

    if (didRequestAuthorize) {
        if (authMethod) { // This is a nested-if, because we might not have an authmethod yet if waiting on fetchedAppSettings
            // Some method of authentication was kicked off
            [self.authLogger logStartAuthMethod:authMethod];
        }
    } else {
        // Can't fallback and Facebook Login failed, so transition to an error state
        NSError *error = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonInlineNotCancelledValue
                                                errorCode:nil
                                               innerError:nil];

        // state transition, and call the handler if there is one
        [self transitionAndCallHandlerWithState:GBSessionStateClosedLoginFailed
                                          error:error
                                      tokenData:nil
                                    shouldCache:NO];
    }
}

- (void)setLoginTypeOfPendingOpenUrlCallback:(GBSessionLoginType)loginType {
    _loginTypeOfPendingOpenUrlCallback = loginType;
}

- (void)logIntegratedAuthAppEvent:(NSString *)dialogOutcome
                      permissions:(NSArray *)permissions {

    NSString *sortedPermissions;

    if (permissions.count == 0) {
        sortedPermissions = @"<NoPermissionsSpecified>";
    } else {
        sortedPermissions = [[permissions sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]
                             componentsJoinedByString:@","];
    }

    // We log Launch and Dismiss one after the other, because we can't determine a priori whether
    // this invocation will necessarily result in launching a dialog, and logging an event and then
    // retracting it conditionally is too problematic.

    [GBAppEvents logImplicitEvent:GBAppEventNamePermissionsUILaunch
                      valueToSum:nil
                      parameters:@{ @"ui_dialog_type" : @"iOS integrated auth",
                                    @"permissions_requested" : sortedPermissions }
                         session:self];

    [GBAppEvents logImplicitEvent:GBAppEventNamePermissionsUIDismiss
                      valueToSum:nil
                      parameters:@{ @"ui_dialog_type" : @"iOS integrated auth",
                                    GBAppEventParameterDialogOutcome : dialogOutcome,
                                    @"permissions_requested" : sortedPermissions }
                         session:self];
}

- (void)authorizeUsingSystemAccountStore:(NSArray*)permissions
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                           isReauthorize:(BOOL)isReauthorize {
    self.lastRequestedSystemAudience = defaultAudience;

    unsigned long timePriorToShowingUI = [GBUtility currentTimeInMilliseconds];

    GBSystemAccountStoreAdapter *systemAccountStoreAdapter = [self getSystemAccountStoreAdapter];

    [systemAccountStoreAdapter
        requestAccessToFacebookAccountStore:permissions
        defaultAudience:defaultAudience
        isReauthorize:isReauthorize
        appID:self.appID
        session:self
        handler:^(NSString *oauthToken, NSError *accountStoreError) {
            BOOL isUntosedDevice = (!oauthToken && accountStoreError.code == ACErrorAccountNotFound);

            unsigned long millisecondsSinceUIWasPotentiallyShown = [GBUtility currentTimeInMilliseconds] - timePriorToShowingUI;

            // There doesn't appear to be a reliable way to determine whether or not a UI was invoked
            // to get us here, or whether the cached token was sufficient.  So we use a timer heuristic
            // assuming that human response time couldn't complete a dialog in under the interval
            // given here, but the process will return here fast enough if the token is cached.  The threshold was
            // chosen empirically, so there may be some edge cases that are false negatives or false positives.
            BOOL dialogWasShown = millisecondsSinceUIWasPotentiallyShown > 350;

            [self.authLogger addExtrasForNextEvent:@{
             @"isUntosedDevice": [NSNumber numberWithBool:isUntosedDevice],
             @"dialogShown": [NSNumber numberWithBool:dialogWasShown]
             }];

            // initial auth case
            if (!isReauthorize) {
                if (oauthToken) {

                    if (dialogWasShown) {
                        [self logIntegratedAuthAppEvent:@"Authorization succeeded"
                                            permissions:permissions];
                    }

                    [self.authLogger logEndAuthMethodWithResult:GBSessionAuthLoggerResultSuccess error:nil];

                     // BUG: we need a means for fetching the expiration date of the token
                    GBAccessTokenData *tokenData = [GBAccessTokenData createTokenFromString:oauthToken
                                                                                permissions:permissions
                                                                             expirationDate:[NSDate distantFuture]
                                                                                  loginType:GBSessionLoginTypeSystemAccount
                                                                                refreshDate:[NSDate date]];
                    [self transitionAndCallHandlerWithState:GBSessionStateOpen
                                                      error:nil
                                                  tokenData:tokenData
                                                shouldCache:YES];

                } else if (isUntosedDevice) {

                    // Don't invoke logIntegratedAuthAppEvent, since this is not an 'integrated dialog' case.

                    [self.authLogger logEndAuthMethodWithResult:GBSessionAuthLoggerResultSkipped error:nil];

                    // even when OS integrated auth is possible we use native-app/safari
                    // login if the user has not signed on to Facebook via the OS
                    [self retryableAuthorizeWithPermissions:permissions
                                            defaultAudience:defaultAudience
                                             integratedAuth:NO
                                                  GBAppAuth:YES
                                                 safariAuth:YES
                                                   fallback:YES
                                              isReauthorize:NO
                                        canFetchAppSettings:YES];
                } else {

                    [self logIntegratedAuthAppEvent:@"Authorization cancelled"
                                        permissions:permissions];

                    NSError *err = nil;
                    NSString *authLoggerResult = GBSessionAuthLoggerResultError;
                    if ([accountStoreError.domain isEqualToString:FacebookSDKDomain]){
                        // If the requestAccess call results in a Facebook error, surface it as a top-level
                        // error. This implies it is not the typical user "disallows" case.
                        err = accountStoreError;
                    } else if ([accountStoreError.domain isEqualToString:@"com.apple.accounts"] && accountStoreError.code == 7) {
                        // code 7 is for user cancellations, see ACErrorCode, except that iOS can also
                        // re-use code 7 for other cases like a sandboxed app. In those other cases,
                        // they do provide a NSLocalizedDescriptionKey entry so we'll inspect for that.
                        if (!accountStoreError.userInfo[NSLocalizedDescriptionKey] ||
                            [accountStoreError.userInfo[NSLocalizedDescriptionKey] rangeOfString:@"Invalid application"
                                                                                         options:NSCaseInsensitiveSearch].location == NSNotFound) {
                                err = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonUserCancelledSystemValue
                                                             errorCode:nil
                                                            innerError:accountStoreError];
                                authLoggerResult = GBSessionAuthLoggerResultCancelled;
                            }
                    }

                    if (err == nil) {
                        // create an error object with additional info regarding failed login as a fallback.
                        err = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonSystemError
                                                     errorCode:nil
                                                    innerError:accountStoreError];
                    }

                    [self.authLogger logEndAuthMethodWithResult:authLoggerResult error:err];

                    // state transition, and call the handler if there is one
                    [self transitionAndCallHandlerWithState:GBSessionStateClosedLoginFailed
                                                      error:err
                                                  tokenData:nil
                                                shouldCache:NO];
                }
            } else { // reauth case
                if (oauthToken) {

                    if (dialogWasShown) {
                        [self logIntegratedAuthAppEvent:@"Reauthorization succeeded"
                                            permissions:permissions];
                    }

                    // union the requested permissions with the already granted permissions
                    NSMutableSet *set = [NSMutableSet setWithArray:self.accessTokenData.permissions];
                    [set addObjectsFromArray:permissions];

                    // complete the operation: success
                    [self completeReauthorizeWithAccessToken:oauthToken
                                                  expirationDate:[NSDate distantFuture]
                                                     permissions:[set allObjects]];
                } else {
                    self.isRepairing = NO;
                    if (dialogWasShown) {
                        [self logIntegratedAuthAppEvent:@"Reauthorization cancelled"
                                            permissions:permissions];
                    }

                    NSError *err;
                    NSString* authLoggerResult = GBSessionAuthLoggerResultSuccess;
                    if ([accountStoreError.domain isEqualToString:FacebookSDKDomain]){
                        // If the requestAccess call results in a Facebook error, surface it as a top-level
                        // error. This implies it is not the typical user "disallows" case.
                        err = accountStoreError;
                    } else if ([accountStoreError.domain isEqualToString:@"com.apple.accounts"]
                               && accountStoreError.code == 7
                               && ![accountStoreError userInfo][NSLocalizedDescriptionKey]) {
                        // code 7 is for user cancellations, see ACErrorCode
                        // for re-auth, there is a specical case where device will return a code 7 if the app
                        // has been untossed. In those cases, there is a localized message so we want to ignore
                        // those for purposes of classifying user cancellations.
                        err = [self errorLoginFailedWithReason:GBErrorReauthorizeFailedReasonUserCancelledSystem
                                                          errorCode:nil
                                                         innerError:accountStoreError];
                        authLoggerResult = GBSessionAuthLoggerResultCancelled;
                    } else {
                        // create an error object with additional info regarding failed login
                        err = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonSystemError
                                                     errorCode:nil
                                                    innerError:accountStoreError];
                    }

                    [self.authLogger logEndAuthMethodWithResult:authLoggerResult error:err];

                    // complete the operation: failed
                    [self callReauthorizeHandlerAndClearState:err];

                    // if we made it this far into the reauth case with an untosed device, then
                    // it is time to invalidate the session
                    if (isUntosedDevice) {
                        [self closeAndClearTokenInformation];
                    }
                }
            }
        }];
}

- (GBSystemAccountStoreAdapter *)getSystemAccountStoreAdapter {
    return [GBSystemAccountStoreAdapter sharedInstance];
}

- (GBAppCall *)authorizeUsingFacebookNativeLoginWithPermissions:(NSArray*)permissions
                                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                                             clientState:(NSDictionary *)clientState {
    GBLoginDialogParams *params = [[[GBLoginDialogParams alloc] init] autorelease];
    params.permissions = permissions;
    params.writePrivacy = defaultAudience;
    params.session = self;

    GBAppCall *call = [GBDialogs presentLoginDialogWithParams:params
                                                  clientState:clientState
                                                      handler:^(GBAppCall *call, NSDictionary *results, NSError *error) {
                                                          [self handleDidCompleteNativeLoginForAppCall:call];
                                                      }];
    if (call) {
        _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeFacebookApplication;
    }
    return call;
}

- (void)handleDidCompleteNativeLoginForAppCall:(GBAppCall *)call {
    if (call.error.code == GBErrorAppActivatedWhilePendingAppCall) {
        // We're here because the app was activated while a authorize request was pending
        // and without a response URL. This is the same flow as handleDidBecomeActive.
        [self authorizeRequestWasImplicitlyCancelled];
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (call.dialogData.results) {
        [params addEntriesFromDictionary:call.dialogData.results];
    }

    // The error from the native Facebook application will be wrapped by an SDK error later on.
    // NOTE: If the user cancelled the login, there won't be an error in the app call. However,
    // an error will be generated further downstream, once the access token is found to be missing.
    // So there is no more work to be done here.
    if (call.error) {
        params[GBInnerErrorObjectKey] = [GBSession sdkSurfacedErrorForNativeLoginError:call.error];
    }
    // log the time the control was returned to the app for profiling reasons
    [GBAppEvents logImplicitEvent:GBAppEventNameGBDialogsNativeLoginDialogEnd
                    valueToSum:nil
                    parameters:@{
                        GBAppEventsNativeLoginDialogEndTime : [NSNumber numberWithDouble:round(1000 * [[NSDate date] timeIntervalSince1970])],
                        @"action_id" : [call ID],
                        @"app_id" : [GBSettings defaultAppID]
                    }
                    session:nil];

    GBSessionLoginType loginType = _loginTypeOfPendingOpenUrlCallback;
    _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeNone;

    [self handleAuthorizationCallbacks:params[@"access_token"]
                                params:params
                             loginType:loginType];
}

- (BOOL)isURLSchemeRegistered {
    // If the url scheme is not registered, then the app we delegate to cannot call
    // back, and hence this is an invalid call.
    NSString *defaultUrlScheme = [NSString stringWithFormat:@"GB%@%@", self.appID, self.urlSchemeSuffix ?: @""];
    if (![GBUtility isRegisteredURLScheme:defaultUrlScheme]) {
        [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors
                            logEntry:[NSString stringWithFormat:@"Cannot use the Facebook app or Safari to authorize, %@ is not registered as a URL Scheme", defaultUrlScheme]];
        return NO;
    }
    return YES;
}

- (BOOL)authorizeUsingFacebookApplication:(NSMutableDictionary *)params {
    NSString *scheme = GBAuthURLScheme;
    if (_urlSchemeSuffix) {
        scheme = [scheme stringByAppendingString:@"2"];
    }
    // add a timestamp for tracking GDP e2e time
    [GBSessionUtility addWebLoginStartTimeToParams:params];

    NSString *urlPrefix = [NSString stringWithFormat:@"%@://%@", scheme, GBAuthURLPath];
    NSString *gbAppUrl = [GBRequest serializeURL:urlPrefix params:params];

    _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeFacebookApplication;
    return [self tryOpenURL:[NSURL URLWithString:gbAppUrl]];
}

- (BOOL)authorizeUsingSafari:(NSMutableDictionary *)params {
    // add a timestamp for tracking GDP e2e time
    [GBSessionUtility addWebLoginStartTimeToParams:params];

    NSString *loginDialogURL = [[GBUtility dialogBaseURL] stringByAppendingString:GBLoginDialogMethod];

    NSString *nextUrl = self.appBaseUrl;
    [params setValue:nextUrl forKey:@"redirect_uri"];

    NSString *gbAppUrl = [GBRequest serializeURL:loginDialogURL params:params];
    _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeFacebookViaSafari;

    return [self tryOpenURL:[NSURL URLWithString:gbAppUrl]];
}

- (BOOL)tryOpenURL:(NSURL *)url {
    return [[UIApplication sharedApplication] openURL:url];
}

- (void)authorizeUsingLoginDialog:(NSMutableDictionary *)params {
    // add a timestamp for tracking GDP e2e time
    //[GBSessionUtility addWebLoginStartTimeToParams:params];

    NSString *loginDialogURL = [[GBUtility dialogBaseURL] stringByAppendingString:GBLoginDialogMethod];

    // open an inline login dialog. This will require the user to enter his or her credentials.
    self.loginDialog = [[[GBLoginDialog alloc] initWithURL:loginDialogURL
                                               loginParams:params
                                                  delegate:self]
                        autorelease];
    _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeWebView;
    [self.loginDialog show];
}

- (BOOL)handleAuthorizationOpen:(NSDictionary*)parameters
                    accessToken:(NSString*)accessToken
                      loginType:(GBSessionLoginType)loginType {
    NSString *code = [parameters objectForKey:@"code"];
    if(parameters) self.parameters = [parameters copy];
    //NSString *sessionKey = [parameters objectForKey:@"session_key"];
    
    // if the URL doesn't contain the access token, an error has occurred.
    if (!accessToken && !code) {
        NSString *errorReason = [parameters objectForKey:@"error"];

        // the facebook app may return an error_code parameter in case it
        // encounters a UIWebViewDelegate error
        NSString *errorCode = [parameters objectForKey:@"error_code"];

        // create an error object with additional info regarding failed login
        // making sure the top level error reason is defined there.
        // If an inner error or another errorReason is present, pass it along
        // as an inner error for the top level error
        NSError *innerError = parameters[GBInnerErrorObjectKey];

        NSError *errorToSurface = nil;
        // If we either have an inner error (typically from another source like the native
        // Facebook application), or if we have an error_message, then this is not a
        // cancellation.
        if (innerError) {
            errorToSurface = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonOtherError
                                                    errorCode:errorCode
                                                   innerError:innerError];
        } else if (parameters[@"error_message"]) {
            // If there's no inner error, then we can check for error_message as a signal for
            // other (non-user cancelled) login failures.
            errorToSurface = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonOtherError
                                                    errorCode:errorCode
                                                   innerError:nil
                                         localizedDescription:parameters[@"error_message"]];
        }

        NSString *authLoggerResult = GBSessionAuthLoggerResultError;
        if (!errorToSurface) {
            // We must have a cancellation
            authLoggerResult = GBSessionAuthLoggerResultCancelled;
            if (errorReason) {
                // Legacy auth responses have 'error' (or here, errorReason) for cancellations.
                // Store that in an inner error so it isn't lost
                innerError = [self errorLoginFailedWithReason:errorReason errorCode:nil innerError:nil];
            }
            errorToSurface = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonUserCancelledValue
                                                    errorCode:errorCode
                                                   innerError:innerError];
        }

        [self.authLogger logEndAuthMethodWithResult:authLoggerResult error:errorToSurface];

        // if the error response indicates that we should try again using Safari, open
        // the authorization dialog in Safari.
        if (errorReason && [errorReason isEqualToString:@"service_disabled_use_browser"]) {
            [self retryableAuthorizeWithPermissions:self.initializedPermissions
                                    defaultAudience:_defaultDefaultAudience
                                     integratedAuth:NO
                                          GBAppAuth:NO
                                         safariAuth:YES
                                           fallback:NO
                                      isReauthorize:NO
                                canFetchAppSettings:YES];
            return YES;
        }

        // if the error response indicates that we should try the authorization flow
        // in an inline dialog, do that.
        if (errorReason && [errorReason isEqualToString:@"service_disabled"]) {
            [self retryableAuthorizeWithPermissions:self.initializedPermissions
                                    defaultAudience:_defaultDefaultAudience
                                     integratedAuth:NO
                                          GBAppAuth:NO
                                         safariAuth:NO
                                           fallback:NO
                                      isReauthorize:NO
                                canFetchAppSettings:YES];
            return YES;
        }

        // state transition, and call the handler if there is one
        [self transitionAndCallHandlerWithState:GBSessionStateClosedLoginFailed
                                          error:errorToSurface
                                      tokenData:nil
                                    shouldCache:NO];
    }   else if(code) {
        [self.authLogger logEndAuthMethodWithResult:GBSessionAuthLoggerResultSuccess error:nil];
        self.code=code;
        // set token and date, state transition, and call the handler if there is one
        [self transitionAndCallHandlerWithState:GBSessionStateOpen
                                          error:nil
                                      code:code];

    }   else {
        [self.authLogger logEndAuthMethodWithResult:GBSessionAuthLoggerResultSuccess error:nil];

        // we have an access token, so parse the expiration date.
        NSDate *expirationDate = [GBSessionUtility expirationDateFromResponseParams:parameters];

        NSArray* grantedPermissions;
        if ([parameters[GBLoginParamsPermissions] isKindOfClass:[NSArray class]]) {
            // native gdp sends back granted permissions as an array already.
            grantedPermissions = parameters[GBLoginParamsPermissions];
        } else {
            grantedPermissions = [parameters[GBLoginParamsGrantedscopes] componentsSeparatedByString:@","];
        }

        if (grantedPermissions.count == 0) {
            grantedPermissions = self.initializedPermissions;
        }

        // set token and date, state transition, and call the handler if there is one
        GBAccessTokenData *tokenData = [GBAccessTokenData createTokenFromString:accessToken
                                                                    permissions:grantedPermissions
                                                                 expirationDate:expirationDate
                                                                      loginType:loginType
                                                                    refreshDate:[NSDate date]];
        [self transitionAndCallHandlerWithState:GBSessionStateOpen
                                          error:nil
                                      tokenData:tokenData
                                    shouldCache:YES];
        
    }
    return YES;
}

- (BOOL)handleReauthorize:(NSDictionary*)parameters
              accessToken:(NSString*)accessToken {
    // if the URL doesn't contain the access token, an error has occurred.
    if (!accessToken) {
        // no token in this case implies that the user cancelled the permissions upgrade
        NSError *innerError = parameters[GBInnerErrorObjectKey];
        NSString *errorCode = parameters[@"error_code"];
        NSString *authLoggerResult = GBSessionAuthLoggerResultError;

        NSError *errorToSurface = nil;
        // If we either have an inner error (typically from another source like the native
        // Facebook application), or if we have an error_message, then this is not a
        // cancellation.
        if (innerError) {
            errorToSurface = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonOtherError
                                                    errorCode:errorCode
                                                   innerError:innerError];
        } else if (parameters[@"error_message"]) {
            // If there's no inner error, then we can check for error_message as a signal for
            // other (non-user cancelled) login failures.
            errorToSurface = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonOtherError
                                                    errorCode:errorCode
                                                   innerError:nil
                                         localizedDescription:parameters[@"error_message"]];
        }

        if (!errorToSurface) {
            // We must have a cancellation
            authLoggerResult = GBSessionAuthLoggerResultCancelled;
            errorToSurface = [self errorLoginFailedWithReason:GBErrorReauthorizeFailedReasonUserCancelled
                                                errorCode:nil
                                               innerError:innerError];
        }
        // in the reauth failure flow, we turn off the repairing flag immediately
        // so that the handler can process the state correctly (i.e., so that
        // the retryManager can close the session).
        self.isRepairing = NO;
        [self.authLogger logEndAuthMethodWithResult:authLoggerResult error:errorToSurface];

        [self callReauthorizeHandlerAndClearState:errorToSurface];
    } else {

        // we have an access token, so parse the expiration date.
        NSDate *expirationDate = [GBSessionUtility expirationDateFromResponseParams:parameters];

        [self validateReauthorizedAccessToken:accessToken expirationDate:expirationDate];
    }

    return YES;
}

- (void)validateReauthorizedAccessToken:(NSString *)accessToken expirationDate:(NSDate *)expirationDate {
    // If we're coming back from a repair scenario, we skip validation
    if (self.isRepairing) {
        self.isRepairing = NO;
        // Assume permissions are unchanged at this point.
        [self completeReauthorizeWithAccessToken:accessToken
                                  expirationDate:expirationDate
                                     permissions:self.permissions];
        return;
    }

    // now we are going to kick-off a batch request, where we confirm that the new token
    // refers to the same gbid as the old, and if so we will succeed the reauthorize call
    GBRequest *requestSessionMe = [GBRequest requestForGraphPath:@"me"];
    [requestSessionMe setSession:self];
    GBRequest *requestNewTokenMe = [[[GBRequest alloc] initWithSession:nil
                                                             graphPath:@"me"
                                                            parameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                        accessToken, @"access_token",
                                                                        nil]
                                                            HTTPMethod:nil]
                                    autorelease];

    GBRequest *requestPermissions = [GBRequest requestForGraphPath:@"me/permissions"];
    [requestPermissions setSession:self];

    // we create a block here with related state -- which will be the main handler block for all
    // three requests -- wrapped by smaller blocks to provide context

    // we will use these to compare gbid's
    __block id gbid = nil;
    __block id gbid2 = nil;
    __block id permissionsRefreshed = nil;
    // and this to assure we notice when we have been called three times
    __block int callsPending = 3;

    void (^handleBatch)(id<GBGraphUser>,id) = [[^(id<GBGraphUser> user,
                                                 id permissions) {

        // here we accumulate state from the various callbacks
        if (user && !gbid) {
            gbid = [[user objectForKey:@"id"] retain];
        } else if (user && !gbid2) {
            gbid2 = [[user objectForKey:@"id"] retain];
        } else if (permissions) {
            permissionsRefreshed = [permissions retain];
        }

        // if this was our last call, then complete the operation
        if (!--callsPending) {
            if ([gbid isEqual:gbid2]) {
                id newPermissions = [[permissionsRefreshed objectAtIndex:0] allKeys];
                if (![newPermissions isKindOfClass:[NSArray class]]) {
                    newPermissions = nil;
                }

                [self completeReauthorizeWithAccessToken:accessToken
                                          expirationDate:expirationDate
                                             permissions:newPermissions];
            } else {
                // no we don't have matching GBIDs, then we fail on these grounds
                NSError *error = [self errorLoginFailedWithReason:GBErrorReauthorizeFailedReasonWrongUser
                                                        errorCode:nil
                                                       innerError:nil];

                [self.authLogger logEndAuthMethodWithResult:GBSessionAuthLoggerResultError error:error];

                [self callReauthorizeHandlerAndClearState:error];
            }

            // because these are __block, we manually handle their lifetime
            [gbid release];
            [gbid2 release];
            [permissionsRefreshed release];
        }
    } copy] autorelease];

    GBRequestConnection *connection = [[[GBRequestConnection alloc] init] autorelease];
    [connection addRequest:requestSessionMe
         completionHandler:^(GBRequestConnection *connection, id<GBGraphUser> user, NSError *error) {
             handleBatch(user, nil);
         }];

    [connection addRequest:requestNewTokenMe
         completionHandler:^(GBRequestConnection *connection, id<GBGraphUser> user, NSError *error) {
             handleBatch(user, nil);
         }];

    [connection addRequest:requestPermissions
         completionHandler:^(GBRequestConnection *connection, id result, NSError *error) {
             handleBatch(nil, [result objectForKey:@"data"]);
         }];

    [connection start];
}

- (void)reauthorizeWithPermissions:(NSArray*)permissions
                            isRead:(BOOL)isRead
                          behavior:(GBSessionLoginBehavior)behavior
                   defaultAudience:(GBSessionDefaultAudience)audience
                 completionHandler:(GBSessionRequestPermissionResultHandler)handler {

    if (!self.isOpen) {
        // session must be open in order to reauthorize
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBSession: an attempt was made reauthorize permissions on an unopened session"
                               userInfo:nil]
         raise];
    }

    if (self.reauthorizeHandler) {
        // block must be cleared (meaning it has been called back) before a reauthorize can happen again
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBSession: It is not valid to reauthorize while a previous "
          @"reauthorize call has not yet completed."
                               userInfo:nil]
         raise];
    }

    // is everything in good order argument-wise?
    [GBSessionUtility validateRequestForPermissions:permissions
                             defaultAudience:audience
                          allowSystemAccount:behavior == GBSessionLoginBehaviorUseSystemAccountIfPresent
                                      isRead:isRead];

    // setup handler and permissions and perform the actual reauthorize
    self.reauthorizeHandler = handler;
    [self authorizeWithPermissions:permissions
                          behavior:behavior
                   defaultAudience:audience
                     isReauthorize:YES];
}

// Internal method for "repairing" a session that has an invalid access token
// by issuing a reauthorize call. If this gets exposed or invoked from more places,
// seriously consider more validation (such as state checking).
// This method will no-op if we're already repairing.
- (void)repairWithHandler:(GBSessionRequestPermissionResultHandler) handler {
    @synchronized (self) {
        if (!self.isRepairing) {
            self.isRepairing = YES;
            GBSessionLoginBehavior loginBehavior;
            switch (self.accessTokenData.loginType) {
                case GBSessionLoginTypeSystemAccount: loginBehavior = GBSessionLoginBehaviorUseSystemAccountIfPresent; break;
                case GBSessionLoginTypeFacebookApplication:
                case GBSessionLoginTypeFacebookViaSafari: loginBehavior = GBSessionLoginBehaviorWithFallbackToWebView; break;
                case GBSessionLoginTypeWebView: loginBehavior = GBSessionLoginBehaviorForcingWebView; break;
                default: loginBehavior = GBSessionLoginBehaviorUseSystemAccountIfPresent;
            }

            if (self.reauthorizeHandler) {
                [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors
                                    logEntry:@"Warning: a session is being reconnected while there might have been an existing reauthorization in progress. The pre-existing reauthorization will be ignored."];
            }
            self.reauthorizeHandler = handler;

            [self authorizeWithPermissions:nil
                                  behavior:loginBehavior
                           defaultAudience:GBSessionDefaultAudienceNone
                             isReauthorize:YES];
        } else {
            // We're already repairing so further attempts at repairs
            // (by other GBRequestConnection instances) should simply
            // be treated as errors (i.e., we do not support queueing
            // until the repair is resolved).
            if (handler) {
                handler(self, [NSError errorWithDomain:FacebookSDKDomain code:GBErrorSessionReconnectInProgess userInfo:nil]);
            }
        }
    }
}

- (void)completeReauthorizeWithAccessToken:(NSString*)accessToken
                            expirationDate:(NSDate*)expirationDate
                               permissions:(NSArray*)permissions {
    [self.authLogger logEndAuthMethodWithResult:GBSessionAuthLoggerResultSuccess error:nil];

    // set token and date, state transition, and call the handler if there is one
    NSDate *now = [NSDate date];
    GBAccessTokenData *tokenData = [GBAccessTokenData createTokenFromString:accessToken
                                                                permissions:permissions
                                                             expirationDate:expirationDate
                                                                  loginType:GBSessionLoginTypeNone
                                                                refreshDate:now
                                                     permissionsRefreshDate:now];
    [self transitionAndCallHandlerWithState:GBSessionStateOpenTokenExtended
                                      error:nil
                                  tokenData:tokenData
                                shouldCache:YES];

    // no error, ack a completed permission upgrade
    [self callReauthorizeHandlerAndClearState:nil];
}

-(void)authorizeRequestWasImplicitlyCancelled {

    const GBSessionState state = self.state;

    if (state == GBSessionStateCreated ||
        state == GBSessionStateClosed ||
        state == GBSessionStateClosedLoginFailed){
        return;
    }

    //we also skip GBSessionLoginTypeWebView because the GBDialogDelegate will handle
    // the flow on its own. Otherwise, the dismissal of the webview will incorrectly
    // trigger this block.
    if (_loginTypeOfPendingOpenUrlCallback != GBSessionLoginTypeNone
        && _loginTypeOfPendingOpenUrlCallback != GBSessionLoginTypeWebView){

        if (state == GBSessionStateCreatedOpening){
            //if we're here, user had declined a fast app switch login.
            [self close];
        } else {
            //this means the user declined a 'reauthorization' so we need
            // to clean out the in-flight request.
            NSError *error = [self errorLoginFailedWithReason:GBErrorReauthorizeFailedReasonUserCancelled
                                                    errorCode:nil
                                                   innerError:nil];
            [self callReauthorizeHandlerAndClearState:error];
        }
        _loginTypeOfPendingOpenUrlCallback = GBSessionLoginTypeNone;
    }
}

- (void)refreshAccessToken:(NSString*)token
            expirationDate:(NSDate*)expireDate {
    // refresh token and date, state transition, and call the handler if there is one
    GBAccessTokenData *tokenData = [GBAccessTokenData createTokenFromString:token ?: self.accessTokenData.accessToken
                                                                permissions:self.accessTokenData.permissions
                                                             expirationDate:expireDate
                                                                  loginType:GBSessionLoginTypeNone
                                                                refreshDate:[NSDate date]
                                                     permissionsRefreshDate:self.accessTokenData.permissionsRefreshDate];
    [self transitionAndCallHandlerWithState:GBSessionStateOpenTokenExtended
                                      error:nil
                                  tokenData:tokenData
                                shouldCache:YES];
}

- (BOOL)shouldExtendAccessToken {
    BOOL result = NO;
    NSDate *now = [NSDate date];
    BOOL isFacebookLogin = self.accessTokenData.loginType == GBSessionLoginTypeFacebookApplication
                            || self.accessTokenData.loginType == GBSessionLoginTypeFacebookViaSafari
                            || self.accessTokenData.loginType == GBSessionLoginTypeSystemAccount;

    if (self.isOpen &&
        isFacebookLogin &&
        [now timeIntervalSinceDate:self.attemptedRefreshDate] > GBTokenRetryExtendSeconds &&
        [now timeIntervalSinceDate:self.accessTokenData.refreshDate] > GBTokenExtendThresholdSeconds) {
        result = YES;
        self.attemptedRefreshDate = now;
    }
    return result;
}

// For simplicity, checking `shouldRefreshPermission` will toggle the flag
// such that future calls within the next hour (as defined by the threshold constant)
// will return NO. Therefore, you should only call this method if you are also
// prepared to actually `refreshPermissions`.
- (BOOL)shouldRefreshPermissions {
    @synchronized(self.attemptedPermissionsRefreshDate) {
        NSDate *now = [NSDate date];

        if (self.isOpen &&
            // Share the same thresholds as the access token string for convenience, we may change in the future.
            [now timeIntervalSinceDate:self.attemptedPermissionsRefreshDate] > GBTokenRetryExtendSeconds &&
            [now timeIntervalSinceDate:self.accessTokenData.permissionsRefreshDate] > GBTokenExtendThresholdSeconds) {
            self.attemptedPermissionsRefreshDate = now;
            return YES;
        }
    }
    return NO;
}

- (void)refreshPermissions:(NSArray *)permissions {
    NSDate *now = [NSDate date];
    GBAccessTokenData *tokenData = [GBAccessTokenData createTokenFromString:self.accessTokenData.accessToken
                                                                permissions:permissions
                                                             expirationDate:self.accessTokenData.expirationDate
                                                                  loginType:self.accessTokenData.loginType
                                                                refreshDate:self.accessTokenData.refreshDate
                                                     permissionsRefreshDate:now];
    self.attemptedPermissionsRefreshDate = now;
    // Note we intentionally do not notify KVO that `accessTokenData `is changing since
    // the implied contract is for that to only occur during state transitions.
    self.accessTokenData = tokenData;
    [self.tokenCachingStrategy cacheGBAccessTokenData:self.accessTokenData];
}

// Internally accessed, so we can bind the affinitized thread later.
- (void)clearAffinitizedThread {
    self.affinitizedThread = nil;
}

- (void)checkThreadAffinity {

    // Validate affinity, or, if not established, establish it.
    if (self.affinitizedThread) {
        NSAssert(self.affinitizedThread == [NSThread currentThread],
                 @"GBSession: should only be used from a single thread");
    } else {
        self.affinitizedThread = [NSThread currentThread];
    }
}


// core handler for inline UX flow
- (void)gbDialogLogin:(NSString *)accessToken expirationDate:(NSDate *)expirationDate params:(NSDictionary *)params {
    // no reason to keep this object
    self.loginDialog = nil;

    if (!params[GBLoginParamsExpiresIn]) {
        NSTimeInterval expirationTimeInterval = [expirationDate timeIntervalSinceNow];
        NSMutableDictionary *paramsToPass = [[[NSMutableDictionary alloc] initWithDictionary:params] autorelease];
        paramsToPass[GBLoginParamsExpiresIn] = @(expirationTimeInterval);
        [self handleAuthorizationCallbacks:accessToken params:paramsToPass loginType:GBSessionLoginTypeWebView];
    } else {
        [self handleAuthorizationCallbacks:accessToken params:params loginType:GBSessionLoginTypeWebView];
    }
}

// core handler for inline UX flow
- (void)gbDialogNotLogin:(BOOL)cancelled {
    // done with this
    self.loginDialog = nil;

    NSString *reason =
        cancelled ? GBErrorLoginFailedReasonInlineCancelledValue : GBErrorLoginFailedReasonInlineNotCancelledValue;
    NSDictionary* params = [[NSMutableDictionary alloc] initWithObjectsAndKeys:reason, @"error", nil];

    [self handleAuthorizationCallbacks:nil
                                params:params
                             loginType:GBSessionLoginTypeWebView];
    [params release];
}

// core handler for inline UX flow
- (void)gbDialogLoginError:(NSError*)error {
    // done with this
    self.loginDialog = nil;
    
    NSString *reason = [error localizedFailureReason];
    NSDictionary* params = [[NSMutableDictionary alloc] initWithObjectsAndKeys:reason, @"error", nil];
    
    [self handleAuthorizationCallbacks:nil
                                params:params
                             loginType:GBSessionLoginTypeWebView];
    [params release];
}

#pragma mark - Private Members (private helpers)

// helper to wrap-up handler callback and state-change
- (void)transitionAndCallHandlerWithState:(GBSessionState)status
                                    error:(NSError*)error
                                tokenData:(GBAccessTokenData *)tokenData
                              shouldCache:(BOOL)shouldCache {


    // lets get the state transition out of the way
    BOOL didTransition = [self transitionToState:status
                             withAccessTokenData:tokenData
                                     shouldCache:shouldCache];

    NSString *authLoggerResult = GBSessionAuthLoggerResultError;
    if (!error) {
        authLoggerResult = ((status == GBSessionStateClosedLoginFailed) ?
                            GBSessionAuthLoggerResultCancelled :
                            GBSessionAuthLoggerResultSuccess);
    } else if ([error.userInfo[GBErrorLoginFailedReason] isEqualToString:GBErrorLoginFailedReasonUserCancelledValue]) {
        authLoggerResult = GBSessionAuthLoggerResultCancelled;
    }

    [self.authLogger logEndAuthWithResult:authLoggerResult error:error];
    self.authLogger = nil; // Nil out the logger so there aren't any rogue events logged.

    // if we are given a handler, we promise to call it once per transition from open to close

    // note the retain message works the same as a copy because loginHandler was already declared
    // as a copy property.
    GBSessionStateHandler handler = [self.loginHandler retain];

    @try {
        // the moment we transition to a terminal state, we release our handlers, and possibly fail-call reauthorize
        if (didTransition && GB_ISSESSIONSTATETERMINAL(self.state)) {
            self.loginHandler = nil;

            NSError *error = [self errorLoginFailedWithReason:GBErrorReauthorizeFailedReasonSessionClosed
                                                    errorCode:nil
                                                   innerError:nil];
            [self callReauthorizeHandlerAndClearState:error];
        }

        // if we have a handler, call it and release our
        // final retain on the handler
        if (handler) {

            // unsuccessful transitions don't change state and don't propagate the error object
            handler(self,
                    self.state,
                    didTransition ? error : nil);

        }
    }
    @finally {
        // now release our stack reference
        [handler release];
    }
}

// helper to wrap-up handler callback and state-change
- (void)transitionAndCallHandlerWithState:(GBSessionState)status
                                    error:(NSError*)error
                                code:(NSString *)code {
    
    
    // lets get the state transition out of the way
    BOOL didTransition = [self transitionToState:status
                             withCode:code];
    
    NSString *authLoggerResult = GBSessionAuthLoggerResultError;
    if (!error) {
        authLoggerResult = ((status == GBSessionStateClosedLoginFailed) ?
                            GBSessionAuthLoggerResultCancelled :
                            GBSessionAuthLoggerResultSuccess);
    } else if ([error.userInfo[GBErrorLoginFailedReason] isEqualToString:GBErrorLoginFailedReasonUserCancelledValue]) {
        authLoggerResult = GBSessionAuthLoggerResultCancelled;
    }
    
    [self.authLogger logEndAuthWithResult:authLoggerResult error:error];
    self.authLogger = nil; // Nil out the logger so there aren't any rogue events logged.
    
    // if we are given a handler, we promise to call it once per transition from open to close
    
    // note the retain message works the same as a copy because loginHandler was already declared
    // as a copy property.
    GBSessionStateHandler handler = [self.loginHandler retain];
    
    @try {
        // the moment we transition to a terminal state, we release our handlers, and possibly fail-call reauthorize
        if (didTransition && GB_ISSESSIONSTATETERMINAL(self.state)) {
            self.loginHandler = nil;
            
            NSError *error = [self errorLoginFailedWithReason:GBErrorReauthorizeFailedReasonSessionClosed
                                                    errorCode:nil
                                                   innerError:nil];
            [self callReauthorizeHandlerAndClearState:error];
        }
        
        // if we have a handler, call it and release our
        // final retain on the handler
        if (handler) {
            
            // unsuccessful transitions don't change state and don't propagate the error object
            handler(self,
                    self.state,
                    didTransition ? error : nil);
            
        }
    }
    @finally {
        // now release our stack reference
        [handler release];
    }
}

- (void)callReauthorizeHandlerAndClearState:(NSError*)error {
    NSString *authLoggerResult = GBSessionAuthLoggerResultSuccess;
    if (error) {
        authLoggerResult = ([error.userInfo[GBErrorLoginFailedReason] isEqualToString:GBErrorReauthorizeFailedReasonUserCancelled] ?
                            GBSessionAuthLoggerResultCancelled :
                            GBSessionAuthLoggerResultError);
    }

    [self.authLogger logEndAuthWithResult:authLoggerResult error:error];
    self.authLogger = nil; // Nil out the logger so there aren't any rogue events logged.

    // clear state and call handler
    GBSessionRequestPermissionResultHandler reauthorizeHandler = [self.reauthorizeHandler retain];
    @try {
        self.reauthorizeHandler = nil;

        if (reauthorizeHandler) {
            reauthorizeHandler(self, error);
        }
    }
    @finally {
        [reauthorizeHandler release];
    }

    self.isRepairing = NO;
}

- (NSString *)appBaseUrl {
    return [GBUtility stringAppBaseUrlFromAppId:self.appID urlSchemeSuffix:self.urlSchemeSuffix];
}

- (NSError*)errorLoginFailedWithReason:(NSString*)errorReason
                             errorCode:(NSString*)errorCode
                            innerError:(NSError*)innerError {
    return [self errorLoginFailedWithReason:errorReason errorCode:errorCode innerError:innerError localizedDescription:nil];
}

- (NSError*)errorLoginFailedWithReason:(NSString*)errorReason
                             errorCode:(NSString*)errorCode
                            innerError:(NSError*)innerError
                  localizedDescription:(NSString*)localizedDescription {
    // capture reason and nested code as user info
    NSMutableDictionary* userinfo = [[NSMutableDictionary alloc] init];
    if (errorReason) {
        userinfo[GBErrorLoginFailedReason] = errorReason;
    }
    if (errorCode) {
        userinfo[GBErrorLoginFailedOriginalErrorCode] = errorCode;
    }
    if (innerError) {
        userinfo[GBErrorInnerErrorKey] = innerError;
    }
    if (localizedDescription) {
        userinfo[NSLocalizedDescriptionKey] = localizedDescription;
    }
    userinfo[GBErrorSessionKey] = self;

    // create error object
    NSError *err = [NSError errorWithDomain:FacebookSDKDomain
                                       code:GBErrorLoginFailedOrCancelled
                                   userInfo:userinfo];
    [userinfo release];
    return err;
}

- (NSString *)jsonClientStateWithDictionary:(NSDictionary *)dictionary{
    NSMutableDictionary *clientState = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], GBLoginUXClientStateIsClientState,
                                 [NSNumber numberWithBool:YES], GBLoginUXClientStateIsOpenSession,
                                 [NSNumber numberWithBool:(self == g_activeSession)], GBLoginUXClientStateIsActiveSession,
                                 nil];
    [clientState addEntriesFromDictionary:dictionary];
    NSString *clientStateString = [GBUtility simpleJSONEncode:clientState];

    return clientStateString ?: @"{}";
}


+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    // these properties must manually notify for KVO
    if ([key isEqualToString:GBisOpenPropertyName] ||
        [key isEqualToString:GBaccessTokenPropertyName] ||
        [key isEqualToString:GBaccessTokenDataPropertyName] ||
        [key isEqualToString:GBexpirationDatePropertyName] ||
        [key isEqualToString:GBstatusPropertyName]) {
        return NO;
    } else {
        return [super automaticallyNotifiesObserversForKey:key];
    }
}

#pragma mark -
#pragma mark Internal members

- (BOOL)openFromAccessTokenData:(GBAccessTokenData *)accessTokenData
              completionHandler:(GBSessionStateHandler) handler
   raiseExceptionIfInvalidState:(BOOL)raiseException {
    if (accessTokenData == nil) {
        return NO;
    }

    // TODO : Need to support more states (possibly as simple as !isOpen) in the case that this is g_activeSession,
    // and ONLY in that case.
    if (!(self.state == GBSessionStateCreated)) {
        if (raiseException) {
            [[NSException exceptionWithName:GBInvalidOperationException
                                     reason:@"GBSession: cannot open a session from token data from its current state"
                                   userInfo:nil]
             raise];
        } else {
            return NO;
        }
    }

    BOOL result = NO;
    if ([self initializeFromCachedToken:accessTokenData withPermissions:nil]) {
        [self openWithBehavior:GBSessionLoginBehaviorWithNoFallbackToWebView completionHandler:handler];
        result = self.isOpen;

        [self.tokenCachingStrategy cacheGBAccessTokenData:accessTokenData];
    }
    return result;
}

+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                            allowLoginUI:(BOOL)allowLoginUI
                      allowSystemAccount:(BOOL)allowSystemAccount
                                  isRead:(BOOL)isRead
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                       completionHandler:(GBSessionStateHandler)handler {
    return [GBSession openActiveSessionWithPermissions:permissions
                                          allowLoginUI:allowLoginUI
                                         loginBehavior:allowSystemAccount ? GBSessionLoginBehaviorUseSystemAccountIfPresent : GBSessionLoginBehaviorWithFallbackToWebView
                                                isRead:isRead
                                       defaultAudience:defaultAudience
                                     completionHandler:handler];
}

+ (BOOL)openActiveSessionWithPermissions:(NSArray*)permissions
                            allowLoginUI:(BOOL)allowLoginUI
                           loginBehavior:(GBSessionLoginBehavior)loginBehavior
                                  isRead:(BOOL)isRead
                         defaultAudience:(GBSessionDefaultAudience)defaultAudience
                       completionHandler:(GBSessionStateHandler)handler {
    // is everything in good order?
    BOOL allowSystemAccount = GBSessionLoginBehaviorUseSystemAccountIfPresent == loginBehavior;
    [GBSessionUtility validateRequestForPermissions:permissions
                                    defaultAudience:defaultAudience
                                 allowSystemAccount:allowSystemAccount
                                             isRead:isRead];
    BOOL result = NO;
    GBSession *session = [[[GBSession alloc] initWithAppID:nil
                                               permissions:permissions
                                           defaultAudience:defaultAudience
                                           urlSchemeSuffix:nil
                                        tokenCacheStrategy:nil]
                          autorelease];
    if (allowLoginUI || session.state == GBSessionStateCreatedTokenLoaded) {
        [GBSession setActiveSession:session userInfo:@{GBSessionDidSetActiveSessionNotificationUserInfoIsOpening: @YES}];
        // we open after the fact, in order to avoid overlapping close
        // and open handler calls for blocks
        [session openWithBehavior:loginBehavior
                completionHandler:handler];
        result = session.isOpen;
    }
    return result;
}

+ (GBSession*)activeSessionIfExists {
    return g_activeSession;
}

+ (GBSession*)activeSessionIfOpen {
    if (g_activeSession.isOpen) {
        return GBSession.activeSession;
    }
    return nil;
}

// This method is used to support early versions of native login that were using the
// platform module's error domain to pass through server errors. The goal is to put those
// errors in a separate domain to avoid collisions.
+ (NSError *)sdkSurfacedErrorForNativeLoginError:(NSError *)nativeLoginError {
    NSError *error = nativeLoginError;
    if ([nativeLoginError.domain isEqualToString:GbombNativeApplicationDomain]) {
        error = [NSError errorWithDomain:GbombNativeApplicationLoginDomain
                                    code:nativeLoginError.code
                                userInfo:nativeLoginError.userInfo];
    }

    return error;
}

- (void)closeAndClearTokenInformation:(NSError*) error {
    [self checkThreadAffinity];

    [[GBDataDiskCache sharedCache] removeDataForSession:self];
    [self.tokenCachingStrategy clearToken];
    
    [GBUtility deleteGbombCookies];
    
    // If we are not already in a terminal state, go to Closed.
    if (!GB_ISSESSIONSTATETERMINAL(self.state)) {
        [self transitionAndCallHandlerWithState:GBSessionStateClosed
                                          error:error
                                      tokenData:nil
                                    shouldCache:NO];
    }
}

#pragma mark -
#pragma mark Debugging helpers

- (NSString*)description {
    NSString *stateDescription = [GBSessionUtility sessionStateDescription:self.state];
    return [NSString stringWithFormat:@"<%@: %p, state: %@, loginHandler: %p, appID: %@, urlSchemeSuffix: %@, tokenCachingStrategy:%@, expirationDate: %@, refreshDate: %@, attemptedRefreshDate: %@, permissions:%@>",
            NSStringFromClass([self class]),
            self,
            stateDescription,
            self.loginHandler,
            self.appID,
            self.urlSchemeSuffix,
            [self.tokenCachingStrategy description],
            self.accessTokenData.expirationDate,
            self.accessTokenData.refreshDate,
            self.attemptedRefreshDate,
            [self.accessTokenData.permissions description]];
}

#pragma mark -

@end
