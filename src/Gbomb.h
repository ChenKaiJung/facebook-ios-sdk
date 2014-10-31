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

#import "GBFrictionlessRequestSettings.h"
#import "GBLoginDialog.h"
#import "GBRequest.h"
#import "GBSessionManualTokenCachingStrategy.h"
#import "GbombSDK.h"

////////////////////////////////////////////////////////////////////////////////
// deprecated API
//
// Summary
// The classes, protocols, etc. in this header are provided for backward
// compatibility and migration; for new code, use FacebookSDK.h, and/or the
// public headers that it imports; for existing code under active development,
// Facebook.h imports FacebookSDK.h, and updates should favor the new interfaces
// whenever possible

// up-front decl's
@class GBFrictionlessRequestSettings;
@protocol GBRequestDelegate;
@protocol GBSessionDelegate;

/**
 * Main Facebook interface for interacting with the Facebook developer API.
 * Provides methods to log in and log out a user, make requests using the REST
 * and Graph APIs, and start user interface interactions (such as
 * pop-ups promoting for credentials, permissions, stream posts, etc.)
 */
@interface Facebook : NSObject<GBLoginDialogDelegate>{
    id<GBSessionDelegate> _sessionDelegate;
    NSMutableSet* _requests;
    GBSession* _session;
    GBSessionManualTokenCachingStrategy *_tokenCaching;
    GBDialog* _gbDialog;
    NSString* _appId;
    NSString* _urlSchemeSuffix;
    BOOL _isExtendingAccessToken;
    GBRequest *_requestExtendingAccessToken;
    NSDate* _lastAccessTokenUpdate;
    GBFrictionlessRequestSettings* _frictionlessRequestSettings;
    NSString* _code;
    NSError* _error;
    NSString* _sessionKey;
}

@property (nonatomic, copy) NSString* accessToken;
@property (nonatomic, copy) NSDate* expirationDate;
@property (nonatomic, assign) id<GBSessionDelegate> sessionDelegate;
@property (nonatomic, copy) NSString* urlSchemeSuffix;
@property (nonatomic, readonly) BOOL isFrictionlessRequestsEnabled;
@property (nonatomic, readonly, retain) GBSession *session;
@property(nonatomic, copy) NSString* code;
@property(nonatomic, copy) NSError* error;
@property(nonatomic, copy) NSString* sessionKey;

- (id)initWithAppId:(NSString *)appId
        andDelegate:(id<GBSessionDelegate>)delegate;

- (id)initWithAppId:(NSString *)appId
    urlSchemeSuffix:(NSString *)urlSchemeSuffix
        andDelegate:(id<GBSessionDelegate>)delegate;

- (void)authorize:(NSArray *)permissions;

- (void)extendAccessToken;

- (void)extendAccessTokenIfNeeded;

- (BOOL)shouldExtendAccessToken;

- (BOOL)handleOpenURL:(NSURL *)url;

- (void)logout;

- (void)logout:(id<GBSessionDelegate>)delegate;

- (GBRequest*)requestWithParams:(NSMutableDictionary *)params
                    andDelegate:(id <GBRequestDelegate>)delegate;

- (GBRequest*)requestWithMethodName:(NSString *)methodName
                          andParams:(NSMutableDictionary *)params
                      andHttpMethod:(NSString *)httpMethod
                        andDelegate:(id <GBRequestDelegate>)delegate;

- (GBRequest*)requestWithGraphPath:(NSString *)graphPath
                       andDelegate:(id <GBRequestDelegate>)delegate;

- (GBRequest*)requestWithGraphPath:(NSString *)graphPath
                         andParams:(NSMutableDictionary *)params
                       andDelegate:(id <GBRequestDelegate>)delegate;

- (GBRequest*)requestWithGraphPath:(NSString *)graphPath
                         andParams:(NSMutableDictionary *)params
                     andHttpMethod:(NSString *)httpMethod
                       andDelegate:(id <GBRequestDelegate>)delegate;

- (void)dialog:(NSString *)action
   andDelegate:(id<GBDialogDelegate>)delegate;

- (void)dialog:(NSString *)action
     andParams:(NSMutableDictionary *)params
   andDelegate:(id <GBDialogDelegate>)delegate;

- (BOOL)isSessionValid;

- (void)enableFrictionlessRequests;

- (void)reloadFrictionlessRecipientCache;

- (BOOL)isFrictionlessEnabledForRecipient:(id)gbid;

- (BOOL)isFrictionlessEnabledForRecipients:(NSArray*)gbids;

@end

////////////////////////////////////////////////////////////////////////////////

/**
 * Your application should implement this delegate to receive session callbacks.
 */
@protocol GBSessionDelegate <NSObject>

/**
 * Called when the user successfully logged in.
 */
- (void)gbDidLogin;

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)gbDidNotLogin:(BOOL)cancelled;

/**
 * Called when the user logged error.
 */

- (void)gbDidLoginError:(NSError *)error;

/**
 * Called after the access token was extended. If your application has any
 * references to the previous access token (for example, if your application
 * stores the previous access token in persistent storage), your application
 * should overwrite the old access token with the new one in this method.
 * See extendAccessToken for more details.
 */
- (void)gbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt;

/**
 * Called when the user logged out.
 */
- (void)gbDidLogout;

/**
 * Called when the current session has expired. This might happen when:
 *  - the access token expired
 *  - the app has been disabled
 *  - the user revoked the app's permissions
 *  - the user changed his or her password
 */
- (void)gbSessionInvalidated;

@end

@protocol GBRequestDelegate;

enum {
    kGBRequestStateReady,
    kGBRequestStateLoading,
    kGBRequestStateComplete,
    kGBRequestStateError
};

// GBRequest(Deprecated)
//
// Summary
// The deprecated category is used to maintain back compat and ease migration
// to the revised SDK for iOS

/**
 * Do not use this interface directly, instead, use method in Facebook.h
 */
@interface GBRequest(Deprecated)

@property (nonatomic, assign) id<GBRequestDelegate> delegate;

/**
 * The URL which will be contacted to execute the request.
 */
@property (nonatomic, copy) NSString* url;

/**
 * The API method which will be called.
 */
@property (nonatomic, copy) NSString* httpMethod;

/**
 * The dictionary of parameters to pass to the method.
 *
 * These values in the dictionary will be converted to strings using the
 * standard Objective-C object-to-string conversion facilities.
 */
@property (nonatomic, retain) NSMutableDictionary* params;
@property (nonatomic, retain) NSURLConnection*  connection;
@property (nonatomic, retain) NSMutableData* responseText;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic) GBRequestState state;
#pragma GCC diagnostic pop
@property (nonatomic) BOOL sessionDidExpire;

/**
 * Error returned by the server in case of request's failure (or nil otherwise).
 */
@property (nonatomic, retain) NSError* error;

- (BOOL) loading;

+ (NSString *)serializeURL:(NSString *)baseUrl
                    params:(NSDictionary *)params;

+ (NSString*)serializeURL:(NSString *)baseUrl
                   params:(NSDictionary *)params
               httpMethod:(NSString *)httpMethod;

@end

////////////////////////////////////////////////////////////////////////////////

/*
 *Your application should implement this delegate
 */
@protocol GBRequestDelegate <NSObject>

@optional

/**
 * Called just before the request is sent to the server.
 */
- (void)requestLoading:(GBRequest *)request;

/**
 * Called when the Facebook API request has returned a response.
 *
 * This callback gives you access to the raw response. It's called before
 * (void)request:(GBRequest *)request didLoad:(id)result,
 * which is passed the parsed response object.
 */
- (void)request:(GBRequest *)request didReceiveResponse:(NSURLResponse *)response;

/**
 * Called when an error prevents the request from completing successfully.
 */
- (void)request:(GBRequest *)request didFailWithError:(NSError *)error;

/**
 * Called when a request returns and its response has been parsed into
 * an object.
 *
 * The resulting object may be a dictionary, an array or a string, depending
 * on the format of the API response. If you need access to the raw response,
 * use:
 *
 * (void)request:(GBRequest *)request
 *      didReceiveResponse:(NSURLResponse *)response
 */
- (void)request:(GBRequest *)request didLoad:(id)result;

/**
 * Called when a request returns a response.
 *
 * The result object is the raw response from the server of type NSData
 */
- (void)request:(GBRequest *)request didLoadRawResponse:(NSData *)data;

@end


