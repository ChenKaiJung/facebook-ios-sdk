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

#import "GBError.h"

NSString *const GbombSDKDomain = @"com.gbombgames.sdk";
NSString *const FacebookNativeApplicationDomain = @"com.gbombgames.Gbomb.platform";

NSString *const GBErrorInnerErrorKey = @"com.gbombgames.sdk:ErrorInnerErrorKey";
NSString *const GBErrorParsedJSONResponseKey = @"com.gbombgames.sdk:ParsedJSONResponseKey";
NSString *const GBErrorHTTPStatusCodeKey = @"com.gbombgames.sdk:HTTPStatusCode";
NSString *const GBErrorSessionKey = @"com.gbombgames.sdk:ErrorSessionKey";
NSString *const GBErrorUnprocessedURLKey = @"com.gbombgames.sdk:UnprocessedURLKey";

NSString *const GBErrorLoginFailedReason = @"com.gbombgames.sdk:ErrorLoginFailedReason";
NSString *const GBErrorLoginFailedOriginalErrorCode = @"com.gbombgames.sdk:ErrorLoginFailedOriginalErrorCode";

NSString *const GBErrorLoginFailedReasonInlineCancelledValue = @"com.gbombgames.sdk:InlineLoginCancelled";
NSString *const GBErrorLoginFailedReasonInlineNotCancelledValue = @"com.gbombgames.sdk:ErrorLoginNotCancelled";
NSString *const GBErrorLoginFailedReasonUserCancelledValue = @"com.gbombgames.sdk:UserLoginCancelled";
NSString *const GBErrorLoginFailedReasonUserCancelledSystemValue = @"com.gbombgames.sdk:SystemLoginCancelled";
NSString *const GBErrorLoginFailedReasonOtherError = @"com.gbombgames.sdk:UserLoginOtherError";
NSString *const GBErrorLoginFailedReasonSystemDisallowedWithoutErrorValue = @"com.gbombgames.sdk:SystemLoginDisallowedWithoutError";
NSString *const GBErrorLoginFailedReasonSystemError = @"com.gbombgames.sdk:SystemLoginError";

NSString *const GBErrorReauthorizeFailedReasonSessionClosed = @"com.gbombgames.sdk:ErrorReauthorizeFailedReasonSessionClosed";
NSString *const GBErrorReauthorizeFailedReasonUserCancelled = @"com.gbombgames.sdk:ErrorReauthorizeFailedReasonUserCancelled";
NSString *const GBErrorReauthorizeFailedReasonUserCancelledSystem = @"com.gbombgames.sdk:ErrorReauthorizeFailedReasonUserCancelledSystem";
NSString *const GBErrorReauthorizeFailedReasonWrongUser = @"com.gbombgames.sdk:ErrorReauthorizeFailedReasonWrongUser";

NSString *const GBInvalidOperationException = @"com.gbombgames.sdk:InvalidOperationException";

NSString *const GBErrorDialogReasonKey = @"com.gbombgames.sdk:DialogReasonKey";
NSString *const GBErrorDialogNotSupported = @"com.gbombgames.sdk:DialogNotSupported";
NSString *const GBErrorDialogInvalidForSession = @"DialogInvalidForSession";
NSString *const GBErrorDialogCantBeDisplayed = @"DialogCantBeDisplayed";
NSString *const GBErrorDialogInvalidOpenGraphObject = @"DialogInvalidOpenGraphObject";
NSString *const GBErrorDialogInvalidOpenGraphActionParameters = @"DialogInvalidOpenGraphActionParameters";

NSString *const GBErrorAppEventsReasonKey = @"com.gbombgames.sdk:AppEventsReasonKey";
