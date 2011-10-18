/*
 * Copyright 2010 Facebook
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

#import "FTLoginDialog.h"
#import "FTRequest.h"

@protocol FTSessionDelegate;

/**
 * Main Facebook interface for interacting with the Facebook developer API.
 * Provides methods to log in and log out a user, make requests using the REST
 * and Graph APIs, and start user interface interactions (such as
 * pop-ups promoting for credentials, permissions, stream posts, etc.)
 */
@interface Funtown : NSObject<FTLoginDialogDelegate>{
  NSString* _accessToken;
  NSDate* _expirationDate;
  id<FTSessionDelegate> _sessionDelegate;
  FTRequest* _request;
  FTDialog* _loginDialog;
  FTDialog* _ftDialog;
  NSString* _appId;
  NSString* _localAppId;
  NSArray* _permissions;
  NSString* _code; 
  NSError* _error;
}

@property(nonatomic, copy) NSString* accessToken;
@property(nonatomic, copy) NSDate* expirationDate;
@property(nonatomic, assign) id<FTSessionDelegate> sessionDelegate;
@property(nonatomic, copy) NSString* localAppId;
@property(nonatomic, copy) NSString* code;
@property(nonatomic, copy) NSError* error;

- (id)initWithAppId:(NSString *)appId
        andDelegate:(id<FTSessionDelegate>)delegate;

- (void)authorize:(NSArray *)permissions;

- (void)authorize:(NSArray *)permissions
       localAppId:(NSString *)localAppId;

- (BOOL)handleOpenURL:(NSURL *)url;

- (void)logout:(id<FTSessionDelegate>)delegate;

- (FTRequest*)requestWithParams:(NSMutableDictionary *)params
                    andDelegate:(id <FTRequestDelegate>)delegate;

- (FTRequest*)requestWithMethodName:(NSString *)methodName
                          andParams:(NSMutableDictionary *)params
                      andHttpMethod:(NSString *)httpMethod
                        andDelegate:(id <FTRequestDelegate>)delegate;

- (FTRequest*)requestWithMidPath:(NSString *)midPath
                       andDelegate:(id <FTRequestDelegate>)delegate;

- (FTRequest*)requestWithMidPath:(NSString *)midPath
                         andParams:(NSMutableDictionary *)params
                       andDelegate:(id <FTRequestDelegate>)delegate;

- (FTRequest*)requestWithMidPath:(NSString *)midPath
                         andParams:(NSMutableDictionary *)params
                     andHttpMethod:(NSString *)httpMethod
                       andDelegate:(id <FTRequestDelegate>)delegate;

- (void)dialog:(NSString *)action
   andDelegate:(id<FTDialogDelegate>)delegate;

- (void)dialog:(NSString *)action
     andParams:(NSMutableDictionary *)params
   andDelegate:(id <FTDialogDelegate>)delegate;

- (BOOL)isSessionValid;

@end

////////////////////////////////////////////////////////////////////////////////

/**
 * Your application should implement this delegate to receive session callbacks.
 */
@protocol FTSessionDelegate <NSObject>

@optional

/**
 * Called when the user successfully logged in.
 */
- (void)ftDidLogin;

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)ftDidNotLogin:(BOOL)cancelled;

/**
 * Called when the user logged error.
 */
- (void)ftDidLoginError:(NSError *)error;

/**
 * Called when the user logged out.
 */
- (void)ftDidLogout;

@end
