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


#import "GBRequestHandlerFactory.h"

#import <UIKit/UIKit.h>

#import "GBAccessTokenData.h"
#import "GBError.h"
#import "GBErrorUtility+Internal.h"
#import "GBRequest+Internal.h"
#import "GBRequestConnection+Internal.h"
#import "GBRequestConnectionRetryManager.h"
#import "GBRequestMetadata.h"
#import "GBSession+Internal.h"
#import "GBSystemAccountStoreAdapter.h"

@implementation GBRequestHandlerFactory

// These handlers should generally conform to the following pattern:
// 1. Save any original errors/results to the metadata.
// 2. Check the retryManager.state to determine if retry behavior should be aborted.
// 3. Invoking the original handler if the retry condition is not met.
// We (ab)use the retryManager to maintain any necessary state between handlers
//  (such as an optional user facing alert message).
+(GBRequestHandler) handlerThatRetries:(GBRequestHandler )handler forRequest:(GBRequest* )request {
    return [[^(GBRequestConnection *connection,
               id result,
               NSError *error){
        GBRequestMetadata *metadata = [connection getRequestMetadata:request];
        metadata.originalError = metadata.originalError ?: error;
        metadata.originalResult = metadata.originalResult ?: result;

        if (connection.retryManager.state != GBRequestConnectionRetryManagerStateAbortRetries
            && error
            && [GBErrorUtility errorCategoryForError:error] == GBErrorCategoryRetry) {

            if (metadata.retryCount < GBREQUEST_DEFAULT_MAX_RETRY_LIMIT) {
                metadata.retryCount++;
                [connection.retryManager addRequestMetadata:metadata];
                return;
            }
        }

        // Otherwise, invoke the supplied handler
        if (handler){
            handler(connection, result, error);
        }
    } copy] autorelease];
}

+(GBRequestHandler) handlerThatAlertsUser:(GBRequestHandler )handler forRequest:(GBRequest* )request {
    return [[^(GBRequestConnection *connection,
               id result,
               NSError *error){
        GBRequestMetadata *metadata = [connection getRequestMetadata:request];
        metadata.originalError = metadata.originalError ?: error;
        metadata.originalResult = metadata.originalResult ?: result;
        NSString *message = [GBErrorUtility userMessageForError:error];
        if (connection.retryManager.state != GBRequestConnectionRetryManagerStateAbortRetries
            && message.length > 0) {

            connection.retryManager.alertMessage = message;
        }

        // In this case, always invoke the handler.
        if (handler) {
            handler(connection, result, error);
        }

    } copy] autorelease];
}

+(GBRequestHandler) handlerThatReconnects:(GBRequestHandler )handler forRequest:(GBRequest* )request {
    // Defer closing of sessions for these kinds of requests.
    request.canCloseSessionOnError = NO;
    return [[^(GBRequestConnection *connection,
               id result,
               NSError *error){
        GBRequestMetadata *metadata = [connection getRequestMetadata:request];
        metadata.originalError = metadata.originalError ?: error;
        metadata.originalResult = metadata.originalResult ?: result;

        GBErrorCategory errorCategory = error ? [GBErrorUtility errorCategoryForError:error] : GBErrorCategoryInvalid;
        if (connection.retryManager.state != GBRequestConnectionRetryManagerStateAbortRetries
            && error
            && errorCategory  == GBErrorCategoryAuthenticationReopenSession){
            int code, subcode;
            [GBErrorUtility fberrorGetCodeValueForError:error
                                                  index:0
                                                   code:&code
                                                subcode:&subcode];

            // If the session has already been closed, we cannot repair.
            BOOL canRepair = request.session.isOpen;
            switch (subcode) {
                case GBAuthSubcodeAppNotInstalled :
                case GBAuthSubcodeUnconfirmedUser : canRepair = NO; break;
            }

            if (canRepair) {
                if (connection.retryManager.sessionToReconnect == nil) {
                    connection.retryManager.sessionToReconnect = request.session;
                }

                if (request.session.accessTokenData.loginType == GBSessionLoginTypeSystemAccount) {
                    // For iOS 6, we also cannot reconnect disabled app sliders.
                    // This has the side effect of not repairing sessions on a device
                    // that has since removed the Facebook device account since we cannot distinguish
                    // between a disabled slider versus no account set up (in the former, we do not
                    // want to attempt GB App/Safari SSO).
                    canRepair = [GBSystemAccountStoreAdapter sharedInstance].canRequestAccessWithoutUI;
                }

                if (canRepair) {
                    if (connection.retryManager.sessionToReconnect == nil) {
                        connection.retryManager.sessionToReconnect = request.session;
                    }

                    // Only support reconnecting one session instance for a give request connection.
                    if (connection.retryManager.sessionToReconnect == request.session) {

                        connection.retryManager.sessionToReconnect = request.session;
                        [connection.retryManager addRequestMetadata:metadata];

                        connection.retryManager.state = GBRequestConnectionRetryManagerStateRepairSession;
                        return;
                    }
                }
            }
        }

        // Otherwise, invoke the supplied handler
        if (handler){
            // Since GBRequestConnection typically closes invalid sessions before invoking the supplied handler,
            // we have to manually mimic that behavior here.
            request.canCloseSessionOnError = YES;
            if (errorCategory == GBErrorCategoryAuthenticationReopenSession){
                [request.session closeAndClearTokenInformation:error];
            }

            handler(connection, result, error);
        }

    } copy] autorelease];
}

@end


