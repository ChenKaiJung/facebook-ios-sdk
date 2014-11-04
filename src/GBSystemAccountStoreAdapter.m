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

#import "GBSystemAccountStoreAdapter.h"

#import "GBAccessTokenData.h"
#import "GBDynamicFrameworkLoader.h"
#import "GBError.h"
#import "GBErrorUtility+Internal.h"
#import "GBLogger.h"
#import "GBSettings.h"
#import "GBUtility.h"

@interface GBSystemAccountStoreAdapter() {
    BOOL _forceBlockingRenew;
}

@property (retain, nonatomic, readonly) ACAccountStore *accountStore;
@property (retain, nonatomic, readonly) ACAccountType *accountTypeGB;

@end

static NSString *const GBForceBlockingRenewKey = @"com.facebook.sdk:ForceBlockingRenewKey";
static GBSystemAccountStoreAdapter* _singletonInstance = nil;

@implementation GBSystemAccountStoreAdapter

@synthesize accountStore = _accountStore;
@synthesize accountTypeGB = _accountTypeGB;

- (id)init {
    self = [super init];
    if (self) {
        _forceBlockingRenew = [[NSUserDefaults standardUserDefaults] boolForKey:GBForceBlockingRenewKey];
        _accountStore = [[[GBDynamicFrameworkLoader loadClass:@"ACAccountStore" withFramework:@"Accounts"] alloc] init];
        _accountTypeGB = [[_accountStore accountTypeWithAccountTypeIdentifier:@"com.apple.facebook"] retain];
    }
    return self;
}

- (void) dealloc {
    [_accountStore release];
    [_accountTypeGB release];
    [super dealloc];
}

#pragma mark - Properties
- (BOOL) forceBlockingRenew {
    return _forceBlockingRenew;
}

- (void) setForceBlockingRenew:(BOOL)forceBlockingRenew{
    if (_forceBlockingRenew!= forceBlockingRenew){
        _forceBlockingRenew = forceBlockingRenew;
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:forceBlockingRenew forKey:GBForceBlockingRenewKey];
        [userDefaults synchronize];
    }
}

+ (GBSystemAccountStoreAdapter*) sharedInstance {
    if (_singletonInstance == nil) {
        static dispatch_once_t onceToken;

        dispatch_once(&onceToken, ^{
            _singletonInstance = [[GBSystemAccountStoreAdapter alloc] init];
        });
    }

    return _singletonInstance;
}

+ (void) setSharedInstance:(GBSystemAccountStoreAdapter *) instance {
    if (instance != _singletonInstance){
        [_singletonInstance release];
         _singletonInstance = [instance retain];
    }
}

- (BOOL) canRequestAccessWithoutUI {
    if (self.accountTypeGB && self.accountTypeGB.accessGranted) {
        NSArray *fbAccounts = [self.accountStore accountsWithAccountType:self.accountTypeGB];
        if (fbAccounts.count > 0) {
            id account = [fbAccounts objectAtIndex:0];
            id credential = [account credential];

            return [credential oauthToken].length > 0;
        }
    }
    return NO;
}

#pragma  mark - Public properties and methods

- (GBTask *)requestAccessToFacebookAccountStoreAsTask:(GBSession *)session {
    GBTaskCompletionSource* tcs = [GBTaskCompletionSource taskCompletionSource];
    [self requestAccessToFacebookAccountStore:session handler:^(NSString *oauthToken, NSError *accountStoreError) {
        if (accountStoreError) {
            [tcs setError:accountStoreError];
        } else {
            [tcs setResult:oauthToken];
        }
    }];
    return tcs.task;
}


- (void)requestAccessToFacebookAccountStore:(GBSession *)session
                                    handler:(GBRequestAccessToAccountsHandler)handler {
    return [self requestAccessToFacebookAccountStore:session.accessTokenData.permissions
                                     defaultAudience:session.lastRequestedSystemAudience
                                       isReauthorize:NO
                                               appID:session.appID
                                             session:session
                                             handler:handler];
}

- (void)requestAccessToFacebookAccountStore:(NSArray *)permissions
                            defaultAudience:(GBSessionDefaultAudience)defaultAudience
                              isReauthorize:(BOOL)isReauthorize
                                      appID:(NSString *)appID
                                    session:(GBSession *)session
                                    handler:(GBRequestAccessToAccountsHandler)handler {
    if (appID == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                                         reason:@"appID cannot be nil"
                                                       userInfo:nil];
    }

    // app may be asking for nothing, but we will always have an array here
    NSArray *permissionsToUse = permissions ? permissions : [NSArray array];
    if ([GBUtility areAllPermissionsReadPermissions:permissions]) {
        // If we have only read permissions being requested, ensure that basic info
        //  is among the permissions requested.
        permissionsToUse = [GBUtility addBasicInfoPermission:permissionsToUse];
    }

    NSString *audience;
    switch (defaultAudience) {
        case GBSessionDefaultAudienceOnlyMe:
            audience = [GBDynamicFrameworkLoader loadStringConstant:@"ACFacebookAudienceOnlyMe" withFramework:@"Accounts"];
            break;
        case GBSessionDefaultAudienceFriends:
            audience = [GBDynamicFrameworkLoader loadStringConstant:@"ACFacebookAudienceFriends" withFramework:@"Accounts"];
            break;
        case GBSessionDefaultAudienceEveryone:
            audience = [GBDynamicFrameworkLoader loadStringConstant:@"ACFacebookAudienceEveryone" withFramework:@"Accounts"];
            break;
        default:
            audience = nil;
    }

    // no publish_* permissions are permitted with a nil audience
    if (!audience && isReauthorize) {
        for (NSString *p in permissions) {
            if ([p hasPrefix:@"publish"]) {
                [[NSException exceptionWithName:GBInvalidOperationException
                                         reason:@"GBSession: One or more publish permission was requested "
                  @"without specifying an audience; use GBSessionDefaultAudienceJustMe, "
                  @"GBSessionDefaultAudienceFriends, or GBSessionDefaultAudienceEveryone"
                                       userInfo:nil]
                 raise];
            }
        }
    }

    // construct access options
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             appID, [GBDynamicFrameworkLoader loadStringConstant:@"ACFacebookAppIdKey" withFramework:@"Accounts"],
                             permissionsToUse, [GBDynamicFrameworkLoader loadStringConstant:@"ACFacebookPermissionsKey" withFramework:@"Accounts"],
                             audience, [GBDynamicFrameworkLoader loadStringConstant:@"ACFacebookAudienceKey" withFramework:@"Accounts"], // must end on this key/value due to audience possibly being nil
                             nil];

    //wrap the request call into a separate block to help with possibly block chaining below.
    void(^requestAccessBlock)(void) = ^{
        if (!self.accountTypeGB) {
            if (handler) {
                handler(nil, [session errorLoginFailedWithReason:GBErrorLoginFailedReasonSystemError
                                                       errorCode:nil
                                                      innerError:nil]);
            }
            return;
        }
        // we will attempt an iOS integrated facebook login
        [self.accountStore
         requestAccessToAccountsWithType:self.accountTypeGB
         options:options
         completion:^(BOOL granted, NSError *error) {
             if (!(granted ||
                   error.code != ACErrorPermissionDenied ||
                   [error.description rangeOfString:@"remote_app_id does not match stored id"].location == NSNotFound)) {

                 [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors formatString:
                              @"System authorization failed:'%@'. This may be caused by a mismatch between"
                              @" the bundle identifier and your app configuration on the server"
                              @" at developers.facebook.com/apps.",
                  error.localizedDescription];
             }

             // requestAccessToAccountsWithType:options:completion: completes on an
             // arbitrary thread; let's process this back on our main thread
             dispatch_async( dispatch_get_main_queue(), ^{
                 NSError* accountStoreError = error;
                 NSString *oauthToken = nil;
                 if (granted) {
                     NSArray *fbAccounts = [self.accountStore accountsWithAccountType:self.accountTypeGB];
                     id account = [fbAccounts objectAtIndex:0];
                     id credential = [account credential];

                     oauthToken = [credential oauthToken];
                 }

                 if (!accountStoreError && !oauthToken){
                     // This means iOS did not give an error nor granted. In order to
                     // surface this to users, stuff in our own error that can be inspected.
                     accountStoreError = [session errorLoginFailedWithReason:GBErrorLoginFailedReasonSystemDisallowedWithoutErrorValue
                                                                   errorCode:nil
                                                                  innerError:nil];
                 }
                 handler(oauthToken, accountStoreError);
             });
         }];
    };

    if (self.forceBlockingRenew
        && [self.accountStore accountsWithAccountType:self.accountTypeGB].count > 0) {
        // If the force renew flag is set and an iOS GB account is still set,
        // chain the requestAccessBlock to a successful renew result
        [self renewSystemAuthorization:^(ACAccountCredentialRenewResult result, NSError *error) {
            if (result == ACAccountCredentialRenewResultRenewed) {
                self.forceBlockingRenew = NO;
                requestAccessBlock();
            } else if (handler) {
                // Otherwise, invoke the caller's handler back on the main thread with an
                // error that will trigger the password change user message.
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(nil, [GBErrorUtility fberrorForSystemPasswordChange:error]);
                });
            }
        }];
    } else {
        // Otherwise go ahead and invoke normal request.
        requestAccessBlock();
    }
}

- (void)renewSystemAuthorization:(void( ^ )(ACAccountCredentialRenewResult, NSError* )) handler {
    // if the slider has been set to off, renew calls to iOS simply hang, so we must
    // preemptively check for that condition.
    if (self.accountStore && self.accountTypeGB && self.accountTypeGB.accessGranted) {
        NSArray *fbAccounts = [self.accountStore accountsWithAccountType:self.accountTypeGB];
        id account;
        if (fbAccounts && [fbAccounts count] > 0 &&
            (account = [fbAccounts objectAtIndex:0])){

            [self.accountStore renewCredentialsForAccount:account completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
                if (error){
                    [GBLogger singleShotLogEntry:GBLoggingBehaviorAccessTokens
                                        logEntry:[NSString stringWithFormat:@"renewCredentialsForAccount result:%ld, error: %@",
                                                  (long)renewResult,
                                                  error]];
                }
                if (handler) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(renewResult, error);
                    });
                }
            }];
            return;
        }
    }

    if (handler) {
        // If there is a handler and we didn't return earlier (i.e, no renew call), determine an appropriate error to surface.
        NSError *error;
        if (self.accountTypeGB && !self.accountTypeGB.accessGranted) {
            error = [[NSError errorWithDomain:GbombSDKDomain
                                                 code:GBErrorSystemAPI
                                             userInfo:@{ NSLocalizedDescriptionKey : @"Access has not been granted to the Facebook account. Verify device settings."}]
                     retain];

        } else {
            error = [[NSError errorWithDomain:GbombSDKDomain
                                        code:GBErrorSystemAPI
                                    userInfo:@{ NSLocalizedDescriptionKey : @"The Facebook account has not been configured on the device."}]
                     retain];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            handler(ACAccountCredentialRenewResultRejected, error);
            [error release];
        });
    }
}

- (GBTask *)renewSystemAuthorizationAsTask {
    GBTaskCompletionSource* tcs = [GBTaskCompletionSource taskCompletionSource];
    [self renewSystemAuthorization:^(ACAccountCredentialRenewResult result, NSError *error) {
        if (error) {
            [tcs setError:error];
        } else {
            [tcs setResult:result];
        }
    }];
    return tcs.task;
}
@end
