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

/*!
 The NSError domain of all errors returned by the Facebook SDK.
*/
extern NSString *const GbombSDKDomain;

/*!
 The NSError domain of all errors surfaced by the Facebook SDK that
 were returned by the Facebook Application
 */
extern NSString *const GbombNativeApplicationDomain;

/*!
 The key in the userInfo NSDictionary of NSError where you can find
 the inner NSError (if any).
*/
extern NSString *const GBErrorInnerErrorKey;

/*!
 The key in the userInfo NSDictionary of NSError for the parsed JSON response
 from the server. In case of a batch, includes the JSON for a single GBRequest.
*/
extern NSString *const GBErrorParsedJSONResponseKey;

/*!
 The key in the userInfo NSDictionary of NSError indicating
 the HTTP status code of the response (if any).
*/
extern NSString *const GBErrorHTTPStatusCodeKey;

/*!
 @abstract Error codes returned by the Facebook SDK in NSError.

 @discussion
 These are valid only in the scope of FacebookSDKDomain.
 */
typedef enum GBErrorCode {
    /*!
     Like nil for GBErrorCode values, represents an error code that
     has not been initialized yet.
     */
    GBErrorInvalid = 0,

    /// The operation failed because it was cancelled.
    GBErrorOperationCancelled,

    /// A login attempt failed
    GBErrorLoginFailedOrCancelled,

    /// The graph API returned an error for this operation.
    GBErrorRequestConnectionApi,

    /*!
     The operation failed because the server returned an unexpected
     response.  You can get this error if you are not using the most
     recent SDK, or if you set your application's migration settings
     incorrectly for the version of the SDK you are using.

     If this occurs on the current SDK with proper app migration
     settings, you may need to try changing to one request per batch.
     */
    GBErrorProtocolMismatch,

    /// Non-success HTTP status code was returned from the operation.
    GBErrorHTTPError,

    /// An endpoint that returns a binary response was used with GBRequestConnection;
    /// endpoints that return image/jpg, etc. should be accessed using NSURLRequest
    GBErrorNonTextMimeTypeReturned,

    /// An error occurred while trying to display a native dialog
    GBErrorDialog,

    /// An error occurred using the GBAppEvents class
    GBErrorAppEvents,

    /// An error occurred related to an iOS API call
    GBErrorSystemAPI,

    /// An error occurred while trying to fetch publish install response data
    GBErrorPublishInstallResponse,

    /*!
     The application had its applicationDidBecomeActive: method called while waiting
     on a response from the native Facebook app for a pending GBAppCall.
     */
    GBErrorAppActivatedWhilePendingAppCall,

    /*!
     The application had its openURL: method called from a source that was not a
     Facebook app and with a URL that was intended for the AppBridge
     */
    GBErrorUntrustedURL,

    /*!
     The URL passed to GBAppCall, was not able to be parsed
     */
    GBErrorMalformedURL,

    /*!
     The operation failed because the session is currently busy reconnecting.
    */
    GBErrorSessionReconnectInProgess,
} GBErrorCode;

/*!
 @abstract Error codes returned by the Facebook SDK in NSError.

 @discussion
 These are valid only in the scope of FacebookNativeApplicationDomain.
 */
typedef enum GBNativeApplicationErrorCode {
    // A general error in processing an GBAppCall, without a known cause. Unhandled exceptions are a good example
    GBAppCallErrorUnknown = 1,

    // The GBAppCall cannot be processed for some reason
    GBAppCallErrorUnsupported = 2,

    // The GBAppCall is for a method that does not exist (or is turned off)
    GBAppCallErrorUnknownMethod = 3,

    // The GBAppCall cannot be processed at the moment, but can be retried at a later time.
    GBAppCallErrorServiceBusy = 4,

    // Share was called in the native Facebook app with incomplete or incorrect arguments
    GBShareErrorInvalidParam = 100,

    // A server error occurred while calling Share in the native Facebook app.
    GBShareErrorServer = 102,

    // An unknown error occurred while calling Share in the native Facebook app.
    GBShareErrorUnknown = 103,

    // Disallowed from calling Share in the native Facebook app.
    GBShareErrorDenied = 104,

} GBNativeApplicationErrorCode;

/*!
 @typedef GBErrorCategory enum

 @abstract Indicates the Facebook SDK classification for the error

 @discussion
 */
typedef enum {
    /*! Indicates that the error category is invalid and likely represents an error that
     is unrelated to Facebook or the Facebook SDK */
    GBErrorCategoryInvalid                      = 0,
    /*! Indicates that the error may be authentication related but the application should retry the operation.
     This case may involve user action that must be taken, and so the application should also test
     the GBerrorShouldNotifyUser property and if YES display GBerrorUserMessage to the user before retrying.*/
    GBErrorCategoryRetry          = 1,
    /*! Indicates that the error is authentication related and the application should reopen the session*/
    GBErrorCategoryAuthenticationReopenSession  = 2,
    /*! Indicates that the error is permission related */
    GBErrorCategoryPermissions                  = 3,
    /*! Indicates that the error implies that the server had an unexpected failure or may be temporarily down */
    GBErrorCategoryServer                       = 4,
    /*! Indicates that the error results from the server throttling the client */
    GBErrorCategoryThrottling                   = 5,
    /*! Indicates the user cancelled the operation */
    GBErrorCategoryUserCancelled                = 6,
    /*! Indicates that the error is Facebook-related but is uncategorizable, and likely newer than the
     current version of the SDK */
    GBErrorCategoryFacebookOther                = -1,
    /*! Indicates that the error is an application error resulting in a bad or malformed request to the server. */
    GBErrorCategoryBadRequest                   = -2,
} GBErrorCategory;

/*!
 The key in the userInfo NSDictionary of NSError where you can find
 the inner NSError (if any).
 */
extern NSString *const GBErrorInnerErrorKey;

/*!
 The key in the userInfo NSDictionary of NSError where you can find
 the session associated with the error (if any).
*/
extern NSString *const GBErrorSessionKey;

/*!
 The key in the userInfo NSDictionary of NSError that points to the URL
 that caused an error, in its processing by GBAppCall.
 */
extern NSString *const GBErrorUnprocessedURLKey;

/*!
 The key in the userInfo NSDictionary of NSError for unsuccessful
 logins (error.code equals GBErrorLoginFailedOrCancelled). If present,
 the value will be one of the constants prefixed by GBErrorLoginFailedReason*.
*/
extern NSString *const GBErrorLoginFailedReason;

/*!
 The key in the userInfo NSDictionary of NSError for unsuccessful
 logins (error.code equals GBErrorLoginFailedOrCancelled). If present,
 the value indicates an original login error code wrapped by this error.
 This is only used in the web dialog login flow.
 */
extern NSString *const GBErrorLoginFailedOriginalErrorCode;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates the user
 cancelled a web dialog auth.
*/
extern NSString *const GBErrorLoginFailedReasonInlineCancelledValue;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates the user
 did not cancel a web dialog auth.
 */
extern NSString *const GBErrorLoginFailedReasonInlineNotCancelledValue;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates the user
 cancelled a non-iOS 6 SSO (either Safari or Facebook App) login.
 */
extern NSString *const GBErrorLoginFailedReasonUserCancelledValue;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates the user
 cancelled an iOS system login.
 */
extern NSString *const GBErrorLoginFailedReasonUserCancelledSystemValue;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates an error
 condition. You may inspect the rest of userInfo for other data.
 */
extern NSString *const GBErrorLoginFailedReasonOtherError;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates the app's
 slider in iOS 6 (device Settings -> Privacy -> Facebook {app} ) has
 been disabled.
 */
extern NSString *const GBErrorLoginFailedReasonSystemDisallowedWithoutErrorValue;

/*!
 A value that may appear in an NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key for login failures. Indicates an error
 has occurred when requesting Facebook account acccess in iOS 6 that was
 not `GBErrorLoginFailedReasonSystemDisallowedWithoutErrorValue` nor
 a user cancellation.
 */
extern NSString *const GBErrorLoginFailedReasonSystemError;
extern NSString *const GBErrorLoginFailedReasonUnitTestResponseUnrecognized;

/*!
 A value that may appear in the NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key when requesting new permissions fails. Indicates
 the request for new permissions has failed because the session was closed.
 */
extern NSString *const GBErrorReauthorizeFailedReasonSessionClosed;

/*!
 A value that may appear in the NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key when requesting new permissions fails. Indicates
 the request for new permissions has failed because the user cancelled.
 */
extern NSString *const GBErrorReauthorizeFailedReasonUserCancelled;

/*!
 A value that may appear in the NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key when requesting new permissions fails on
 iOS 6 with the Facebook account. Indicates the request for new permissions has
 failed because the user cancelled.
 */
extern NSString *const GBErrorReauthorizeFailedReasonUserCancelledSystem;

/*!
 A value that may appear in the NSError userInfo dictionary under the
 `GBErrorLoginFailedReason` key when requesting new permissions fails. Indicates
 the request for new permissions has failed because the request was
 for a different user than the original permission set.
 */
extern NSString *const GBErrorReauthorizeFailedReasonWrongUser;

/*!
 The key in the userInfo NSDictionary of NSError for errors
 encountered with `GBDialogs` operations. (error.code equals GBErrorDialog).
 If present, the value will be one of the constants prefixed by GBErrorDialog*.
*/
extern NSString *const GBErrorDialogReasonKey;

/*!
 A value that may appear in the NSError userInfo dictionary under the
`GBErrorDialogReasonKey` key. Indicates that a native dialog is not supported
 in the current OS.
*/
extern NSString *const GBErrorDialogNotSupported;

/*!
 A value that may appear in the NSError userInfo dictionary under the
 `GBErrorDialogReasonKey` key. Indicates that a native dialog cannot be
 displayed because it is not appropriate for the current session.
*/
extern NSString *const GBErrorDialogInvalidForSession;

/*!
 A value that may appear in the NSError userInfo dictionary under the
 `GBErrorDialogReasonKey` key. Indicates that a native dialog cannot be
 displayed for some other reason.
 */
extern NSString *const GBErrorDialogCantBeDisplayed;

/*!
 A value that may appear in the NSError userInfo ditionary under the
 `GBErrorDialogReasonKey` key. Indicates that a native dialog cannot be
 displayed because an Open Graph object that was passed was not configured
 correctly. The object must either (a) exist by having an 'id' or 'url' value;
 or, (b) configured for creation (by setting the 'type' value and
 provisionedForPost property)
*/
extern NSString *const GBErrorDialogInvalidOpenGraphObject;

/*!
 A value that may appear in the NSError userInfo ditionary under the
 `GBErrorDialogReasonKey` key. Indicates that a native dialog cannot be
 displayed because the parameters for sharing an Open Graph action were
 not configured. The parameters must include an 'action', 'actionType', and
 'previewPropertyName'.
 */
extern NSString *const GBErrorDialogInvalidOpenGraphActionParameters;

/*!
 The key in the userInfo NSDictionary of NSError for errors
 encountered with `GBAppEvents` operations (error.code equals GBErrorAppEvents).
*/
extern NSString *const GBErrorAppEventsReasonKey;

// Exception strings raised by the Facebook SDK

/*!
 This exception is raised by methods in the Facebook SDK to indicate
 that an attempted operation is invalid
 */
extern NSString *const GBInvalidOperationException;

// Facebook SDK also raises exceptions the following common exceptions:
//  NSInvalidArgumentException

