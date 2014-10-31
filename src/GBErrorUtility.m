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

#import "GBErrorUtility+Internal.h"

#import "GBAccessTokenData+Internal.h"
#import "GBError.h"
#import "GBSession.h"
#import "GBUtility.h"

const int GBOAuthError = 190;
static const int GBAPISessionError = 102;
static const int GBAPIServiceError = 2;
static const int GBAPIUnknownError = 1;
static const int GBAPITooManyCallsError = 4;
static const int GBAPIUserTooManyCallsError = 17;
static const int GBAPIPermissionDeniedError = 10;
static const int GBAPIPermissionsStartError = 200;
static const int GBAPIPermissionsEndError = 299;
static const int GBSDKRetryErrorSubcode = 65000;
static const int GBSDKSystemPasswordErrorSubcode = 65001;

@implementation GBErrorUtility

+(GBErrorCategory) errorCategoryForError:(NSError *)error {
    int code = 0, subcode = 0;

    [GBErrorUtility gberrorGetCodeValueForError:error
                                          index:0
                                           code:&code
                                        subcode:&subcode];

    return [GBErrorUtility gberrorCategoryFromError:error
                                               code:code
                                            subcode:subcode
                               returningUserMessage:nil
                                andShouldNotifyUser:nil];
}

+(BOOL) shouldNotifyUserForError:(NSError *)error {
    BOOL shouldNotifyUser = NO;
    int code = 0, subcode = 0;

    [GBErrorUtility gberrorGetCodeValueForError:error
                                          index:0
                                           code:&code
                                        subcode:&subcode];

    [GBErrorUtility gberrorCategoryFromError:error
                                        code:code
                                     subcode:subcode
                        returningUserMessage:nil
                         andShouldNotifyUser:&shouldNotifyUser];
    return shouldNotifyUser;
}

+(NSString *) userMessageForError:(NSError *)error {
    NSString *message = nil;
    int code = 0, subcode = 0;
    [GBErrorUtility gberrorGetCodeValueForError:error
                                          index:0
                                           code:&code
                                        subcode:&subcode];

    [GBErrorUtility gberrorCategoryFromError:error
                                        code:code
                                     subcode:subcode
                        returningUserMessage:&message
                         andShouldNotifyUser:nil];
    return message;
}

// This method is responsible for error categorization and response policy for
// the SDK; for example, the rules in this method dictate when an auth error is
// categorized as *Retry vs *ReopenSession, which in turn impacts whether
// GBRequestConnection auto-closes a session for a given error; additionally,
// this method generates categories, and user messages for the public NSError
// category
+ (GBErrorCategory)gberrorCategoryFromError:(NSError *)error
                                       code:(int)errorCode
                                   subcode:(int)subcode
                      returningUserMessage:(NSString **)puserMessage
                       andShouldNotifyUser:(BOOL *)pshouldNotifyUser {

    NSString *userMessageKey = nil;
    NSString *userMessageDefault = nil;

    BOOL shouldNotifyUser = NO;

    // defaulting to a non-facebook category
    GBErrorCategory category = GBErrorCategoryInvalid;

    // determine if we have a facebook error category here
    if ([[error domain] isEqualToString:FacebookSDKDomain]) {
        // now defaulting to an unknown (future) facebook category
        category = GBErrorCategoryFacebookOther;
        if ([error code] == GBErrorLoginFailedOrCancelled) {
            NSString *errorLoginFailedReason = [error userInfo][GBErrorLoginFailedReason];
            if (errorLoginFailedReason == GBErrorLoginFailedReasonInlineCancelledValue ||
                errorLoginFailedReason == GBErrorLoginFailedReasonUserCancelledSystemValue ||
                errorLoginFailedReason == GBErrorLoginFailedReasonUserCancelledValue ||
                errorLoginFailedReason == GBErrorReauthorizeFailedReasonUserCancelled ||
                errorLoginFailedReason == GBErrorReauthorizeFailedReasonUserCancelledSystem) {
                category = GBErrorCategoryUserCancelled;
            } else {
                // for now, we use "Retry" as a sentinal indicating any auth error
                category = GBErrorCategoryRetry;
            }
        } else if ([error code] == GBErrorHTTPError) {
            if ((errorCode == GBOAuthError || errorCode == GBAPISessionError)) {
                category = GBErrorCategoryAuthenticationReopenSession;
            } else if (errorCode == GBAPIServiceError || errorCode == GBAPIUnknownError) {
                category = GBErrorCategoryServer;
            } else if (errorCode == GBAPITooManyCallsError || errorCode == GBAPIUserTooManyCallsError) {
                category = GBErrorCategoryThrottling;
            } else if (errorCode == GBAPIPermissionDeniedError ||
                       (errorCode >= GBAPIPermissionsStartError && errorCode <= GBAPIPermissionsEndError)) {
                category = GBErrorCategoryPermissions;
            }
        }
    }

    // determine details about category, user notification, and message
    switch (category) {
        case GBErrorCategoryAuthenticationReopenSession:
            switch (subcode) {
                case GBSDKRetryErrorSubcode:
                    category = GBErrorCategoryRetry;
                    break;
                case GBAuthSubcodeExpired:
                    if (![GBErrorUtility GBerrorIsErrorFromSystemSession:error]) {
                        userMessageKey = @"GBE:ReconnectApplication";
                        userMessageDefault = @"Please log into this app again to reconnect your Facebook account.";
                    }
                    break;
                case GBSDKSystemPasswordErrorSubcode:
                case GBAuthSubcodePasswordChanged:
                    if (subcode == GBSDKSystemPasswordErrorSubcode
                        || [GBErrorUtility gberrorIsErrorFromSystemSession:error]) {
                        userMessageKey = @"GBE:PasswordChangedDevice";
                        userMessageDefault = @"Your Facebook password has changed. To confirm your password, open Settings > Facebook and tap your name.";
                        shouldNotifyUser = YES;
                    } else {
                        userMessageKey = @"GBE:PasswordChanged";
                        userMessageDefault = @"Your Facebook password has changed. Please log into this app again to reconnect your Facebook account.";
                    }
                    break;
                case GBAuthSubcodeUserCheckpointed:
                    userMessageKey = @"GBE:WebLogIn";
                    userMessageDefault = @"Your Facebook account is locked. Please log into www.facebook.com to continue.";
                    shouldNotifyUser = YES;
                    category = GBErrorCategoryRetry;
                    break;
                case GBAuthSubcodeUnconfirmedUser:
                    userMessageKey = @"GBE:Unconfirmed";
                    userMessageDefault = @"Your Facebook account is locked. Please log into www.facebook.com to continue.";
                    shouldNotifyUser = YES;
                    break;
                case GBAuthSubcodeAppNotInstalled:
                    userMessageKey = @"GBE:AppNotInstalled";
                    userMessageDefault = @"Please log into this app again to reconnect your Facebook account.";
                    break;
                default:
                    if ([GBErrorUtility gberrorIsErrorFromSystemSession:error] && errorCode == FBOAuthError) {
                        // This would include the case where the user has toggled the app slider in iOS 6 (and the session
                        //  had already been open).
                        userMessageKey = @"FBE:OAuthDevice";
                        userMessageDefault = @"To use your Facebook account with this app, open Settings > Facebook and make sure this app is turned on.";
                        shouldNotifyUser = YES;
                    }
                    break;
            }
            break;
        case GBErrorCategoryPermissions:
            userMessageKey = @"GBE:GrantPermission";
            userMessageDefault = @"This app doesn't have permission to do this. To change permissions, try logging into the app again.";
            break;
        case GBErrorCategoryRetry:
            if ([error code] == GBErrorLoginFailedOrCancelled) {
                if ([[error userInfo][GBErrorLoginFailedReason] isEqualToString:GBErrorLoginFailedReasonSystemDisallowedWithoutErrorValue]) {
                    // This maps to the iOS 6 slider disabled case.
                    userMessageKey = @"GBE:OAuthDevice";
                    userMessageDefault = @"To use your Facebook account with this app, open Settings > Facebook and make sure this app is turned on.";
                    shouldNotifyUser = YES;
                    category = GBErrorCategoryServer;
                } else if ([[error userInfo][GBErrorLoginFailedReason] isEqualToString:GBErrorLoginFailedReasonSystemError]) {
                    // For other system auth errors, we assume it is not retriable and will surface
                    // an underlying message is possible (e.g., when there is no connectivity,
                    // Apple will report "The Internet connection appears to be offline." )
                    userMessageKey = @"GBE:DeviceError";
                    userMessageDefault = [[error userInfo][GBErrorInnerErrorKey] userInfo][NSLocalizedDescriptionKey] ? :
                        @"Something went wrong. Please make sure you're connected to the internet and try again.";
                    shouldNotifyUser = YES;
                    category = GBErrorCategoryServer;
                }
            }
            break;
        case GBErrorCategoryInvalid:
        case GBErrorCategoryServer:
        case GBErrorCategoryThrottling:
        case GBErrorCategoryBadRequest:
        case GBErrorCategoryFacebookOther:
        default:
            userMessageKey = nil;
            userMessageDefault = nil;
            break;
    }

    if (pshouldNotifyUser) {
        *pshouldNotifyUser = shouldNotifyUser;
    }

    if (puserMessage) {
        if (userMessageKey) {
            *puserMessage = [GBUtility localizedStringForKey:userMessageKey
                                                 withDefault:userMessageDefault];
        } else {
            *puserMessage = nil;
        }
    }
    return category;
}

+ (BOOL)gberrorIsErrorFromSystemSession:(NSError *)error {
    // Categorize the error as system error if we have session state, or the error is wrapping an error from Apple.
    return ((GBSession*)error.userInfo[GBErrorSessionKey]).accessTokenData.loginType == GBSessionLoginTypeSystemAccount
     || [((NSError *)error.userInfo[GBErrorInnerErrorKey]).domain isEqualToString:@"com.apple.accounts"];
}

+ (void)gberrorGetCodeValueForError:(NSError *)error
                              index:(NSUInteger)index
                               code:(int *)pcode
                            subcode:(int *)psubcode {

    // does this error have a response? that is an array?
    id response = [error.userInfo objectForKey:GBErrorParsedJSONResponseKey];
    if (response) {
        id item = nil;
        if ([response isKindOfClass:[NSArray class]]) {
            item = [((NSArray*) response) objectAtIndex:index];
        } else {
            item = response;
        }
        // spelunking a JSON array & nested objects (eg. response[index].body.error.code)
        id  body, error, code;
        if ((body = [item objectForKey:@"body"]) &&         // response[index].body
            [body isKindOfClass:[NSDictionary class]] &&
            (error = [body objectForKey:@"error"]) &&       // response[index].body.error
            [error isKindOfClass:[NSDictionary class]]) {
            if (pcode &&
                (code = [error objectForKey:@"code"]) &&        // response[index].body.error.code
                [code isKindOfClass:[NSNumber class]]) {
                *pcode = [code intValue];
            }
            if (psubcode &&
                (code = [error objectForKey:@"error_subcode"]) &&        // response[index].body.error.error_subcode
                [code isKindOfClass:[NSNumber class]]) {
                *psubcode = [code intValue];
            }
        }
    }
}

+ (NSError *) gberrorForRetry:(NSError *)innerError {
    NSMutableDictionary *userInfoDictionary = [NSMutableDictionary dictionaryWithDictionary:
                                               @{
                                                   GBErrorParsedJSONResponseKey : @{
                                                       @"body" : @{
                                                           @"error" : @{
                                                               @"code": [NSNumber numberWithInt:GBOAuthError],
                                                               @"error_subcode" : [NSNumber numberWithInt:GBSDKRetryErrorSubcode]
                                                           }
                                                       }
                                                   }
                                               }];
    if (innerError) {
        [userInfoDictionary setObject:innerError forKey:GBErrorInnerErrorKey];
    }
    return [NSError errorWithDomain:GbombSDKDomain
                               code:GBErrorHTTPError
                           userInfo:userInfoDictionary];
}

+ (NSError *) gberrorForSystemPasswordChange:(NSError *)innerError {
    NSMutableDictionary *userInfoDictionary = [NSMutableDictionary dictionaryWithDictionary:
                                               @{
                                                   GBErrorParsedJSONResponseKey : @{
                                                        @"body" : @{
                                                            @"error" : @{
                                                               @"code": [NSNumber numberWithInt:GBOAuthError],
                                                               @"error_subcode" : [NSNumber numberWithInt:GBSDKSystemPasswordErrorSubcode]
                                                            }
                                                        }
                                                   }
                                               }];
    if (innerError) {
        [userInfoDictionary setObject:innerError forKey:GBErrorInnerErrorKey];
    }
    return [NSError errorWithDomain:FacebookSDKDomain
                               code:GBErrorHTTPError
                           userInfo:userInfoDictionary];
}
@end
