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

#import "GBDialogs+Internal.h"
#import "GBDialogsData+Internal.h"
#import "GBDialogsParams+Internal.h"

#import <Social/Social.h>

#import "GBAccessTokenData+Internal.h"
#import "GBAccessTokenData.h"
#import "GBAppBridge.h"
#import "GBAppCall+Internal.h"
#import "GBAppEvents+Internal.h"
#import "GBAppLinkData+Internal.h"
#import "GBDynamicFrameworkLoader.h"
#import "GBError.h"
#import "GBLoginDialogParams.h"
#import "GBOpenGraphActionShareDialogParams.h"
#import "GBSession.h"
#import "GBSettings.h"
#import "GBShareDialogParams.h"
#import "GBUtility.h"

@interface GBDialogs ()

+ (NSError*)createError:(NSString*)reason
                session:(GBSession *)session;

@end

@implementation GBDialogs

+ (BOOL)presentOSIntegratedShareDialogModallyFrom:(UIViewController*)viewController
                                      initialText:(NSString*)initialText
                                            image:(UIImage*)image
                                              url:(NSURL*)url
                                          handler:(GBOSIntegratedShareDialogHandler)handler {
    NSArray *images = image ? [NSArray arrayWithObject:image] : nil;
    NSArray *urls = url ? [NSArray arrayWithObject:url] : nil;

    return [self presentOSIntegratedShareDialogModallyFrom:viewController
                                                   session:nil
                                               initialText:initialText
                                                    images:images
                                                      urls:urls
                                                   handler:handler];
}

+ (BOOL)presentOSIntegratedShareDialogModallyFrom:(UIViewController*)viewController
                                      initialText:(NSString*)initialText
                                           images:(NSArray*)images
                                             urls:(NSArray*)urls
                                          handler:(GBOSIntegratedShareDialogHandler)handler {
    return [self presentOSIntegratedShareDialogModallyFrom:viewController
                                                   session:nil
                                               initialText:initialText
                                                    images:images
                                                      urls:urls
                                                   handler:handler];
}

+ (BOOL)presentOSIntegratedShareDialogModallyFrom:(UIViewController*)viewController
                                          session:(GBSession*)session
                                      initialText:(NSString*)initialText
                                           images:(NSArray*)images
                                             urls:(NSArray*)urls
                                          handler:(GBOSIntegratedShareDialogHandler)handler {
    SLComposeViewController *composeViewController = [GBDialogs composeViewControllerWithSession:session
                                                                                         handler:handler];
    if (!composeViewController) {
        return NO;
    }

    if (initialText) {
        [composeViewController setInitialText:initialText];
    }
    if (images && images.count > 0) {
        for (UIImage *image in images) {
            [composeViewController addImage:image];
        }
    }
    if (urls && urls.count > 0) {
        for (NSURL *url in urls) {
            [composeViewController addURL:url];
        }
    }

    [composeViewController setCompletionHandler:^(SLComposeViewControllerResult result) {
        BOOL cancelled = (result == SLComposeViewControllerResultCancelled);

        [GBAppEvents logImplicitEvent:GBAppEventNameShareSheetDismiss
                          valueToSum:nil
                          parameters:@{ @"render_type" : @"Native",
                                        GBAppEventParameterDialogOutcome : (cancelled
                                         ? GBAppEventsDialogOutcomeValue_Cancelled
                                         : GBAppEventsDialogOutcomeValue_Completed) }
                             session:session];

        if (handler) {
            handler(cancelled ?  GBOSIntegratedShareDialogResultCancelled :  GBOSIntegratedShareDialogResultSucceeded, nil);
        }
    }];

    [GBAppEvents logImplicitEvent:GBAppEventNameShareSheetLaunch
                      valueToSum:nil
                      parameters:@{ @"render_type" : @"Native" }
                         session:session];
    [viewController presentViewController:composeViewController animated:YES completion:nil];

    return YES;
}

+ (BOOL)canPresentOSIntegratedShareDialogWithSession:(GBSession*)session {
    return [GBDialogs composeViewControllerWithSession:session
                                               handler:nil] != nil;
}

+ (BOOL)canPresentLoginDialogWithParams:(GBLoginDialogParams *)params {
    NSString *version = [params appBridgeVersion];
    // Ensure version support and that GBAppCall can be constructed correctly (i.e., in case of urlSchemeSuffix overrides).
    return (version != nil && [[[GBAppCall alloc] initWithID:nil enforceScheme:YES appID:params.session.appID urlSchemeSuffix:params.session.urlSchemeSuffix] autorelease]);
}

+ (GBAppCall *)presentLoginDialogWithParams:(GBLoginDialogParams *)params
                                  clientState:(NSDictionary *)clientState
                                      handler:(GBDialogAppCallCompletionHandler)handler {
    GBAppCall *call = [[[GBAppCall alloc] initWithID:nil enforceScheme:YES appID:params.session.appID urlSchemeSuffix:params.session.urlSchemeSuffix] autorelease];
    NSString *version = [params appBridgeVersion];
    if (version && call) {
        GBDialogsData *dialogData = [[[GBDialogsData alloc] initWithMethod:@"auth3"
                                                                 arguments:[params dictionaryMethodArgs]]
                                     autorelease];
        dialogData.clientState = clientState;

        call.dialogData = dialogData;

        // log the timestamp for starting the switch to the Facebook application
        [GBAppEvents logImplicitEvent:GBAppEventNameGBDialogsNativeLoginDialogStart
                          valueToSum:nil
                          parameters:@{
                            GBAppEventsNativeLoginDialogStartTime : [NSNumber numberWithDouble:round(1000 * [[NSDate date] timeIntervalSince1970])],
                            @"action_id" : [call ID],
                            @"app_id" : [GBSettings defaultAppID]
                          }
                          session:nil];
        [[GBAppBridge sharedInstance] dispatchDialogAppCall:call
                                                    version:version
                                                    session:params.session
                                          completionHandler:^(GBAppCall *call) {
                                              if (handler) {
                                                  handler(call, call.dialogData.results, call.error);
                                              }
                                          }];
        return call;
    }

    return nil;
}

+ (BOOL)canPresentShareDialogWithParams:(GBShareDialogParams *)params {
    return [params appBridgeVersion] != nil;
}

+ (GBAppCall *)presentShareDialogWithParams:(GBShareDialogParams *)params
                                clientState:(NSDictionary *)clientState
                                    handler:(GBDialogAppCallCompletionHandler)handler {
    GBAppCall *call = nil;
    NSString *version = [params appBridgeVersion];
    if (version) {
        GBDialogsData *dialogData = [[[GBDialogsData alloc] initWithMethod:@"share"
                                                                 arguments:[params dictionaryMethodArgs]]
                                     autorelease];
        dialogData.clientState = clientState;

        call = [[[GBAppCall alloc] init] autorelease];
        call.dialogData = dialogData;

        [[GBAppBridge sharedInstance] dispatchDialogAppCall:call
                                                    version:version
                                                    session:nil
                                          completionHandler:^(GBAppCall *call) {
                                              if (handler) {
                                                  handler(call, call.dialogData.results, call.error);
                                              }
                                          }];
    }
    [GBAppEvents logImplicitEvent:GBAppEventNameGBDialogsPresentShareDialog
                       valueToSum:nil
                       parameters:@{ GBAppEventParameterDialogOutcome : call ?
                                                                        GBAppEventsDialogOutcomeValue_Completed :
                                                                        GBAppEventsDialogOutcomeValue_Failed }
                          session:nil];

    return call;
}

+ (GBAppCall *)presentShareDialogWithLink:(NSURL *)link
                                  handler:(GBDialogAppCallCompletionHandler)handler {
    return [GBDialogs presentShareDialogWithLink:link
                                            name:nil
                                         caption:nil
                                     description:nil
                                         picture:nil
                                     clientState:nil
                                         handler:handler];
}

+ (GBAppCall *)presentShareDialogWithLink:(NSURL *)link
                                     name:(NSString *)name
                                  handler:(GBDialogAppCallCompletionHandler)handler {
    return [GBDialogs presentShareDialogWithLink:link
                                            name:name
                                         caption:nil
                                     description:nil
                                         picture:nil
                                     clientState:nil
                                         handler:handler];
}


+ (GBAppCall *)presentShareDialogWithLink:(NSURL *)link
                                     name:(NSString *)name
                                  caption:(NSString *)caption
                              description:(NSString *)description
                                  picture:(NSURL *)picture
                              clientState:(NSDictionary *)clientState
                                  handler:(GBDialogAppCallCompletionHandler)handler {
    GBShareDialogParams *params = [[[GBShareDialogParams alloc] init] autorelease];
    params.link = link;
    params.name = name;
    params.caption = caption;
    params.description = description;
    params.picture = picture;

    return [self presentShareDialogWithParams:params
                                  clientState:clientState
                                      handler:handler];
}

+ (BOOL)canPresentShareDialogWithOpenGraphActionParams:(GBOpenGraphActionShareDialogParams *)params {
    return [params appBridgeVersion] != nil;
}

+ (GBAppCall *)presentShareDialogWithOpenGraphActionParams:(GBOpenGraphActionShareDialogParams *)params
                                               clientState:(NSDictionary *)clientState
                                                   handler:(GBDialogAppCallCompletionHandler)handler {
    GBAppCall *call = nil;
    NSString *version = [params appBridgeVersion];
    if (version) {
        call = [[[GBAppCall alloc] init] autorelease];

        NSError *validationError = [params validate];
        if (validationError) {
            if (handler) {
                handler(call, nil, validationError);
            }
        } else {
            GBDialogsData *dialogData = [[[GBDialogsData alloc] initWithMethod:@"ogshare"
                                                                      arguments:[params dictionaryMethodArgs]]
                                         autorelease];
            dialogData.clientState = clientState;

            call.dialogData = dialogData;

            [[GBAppBridge sharedInstance] dispatchDialogAppCall:call
                                                        version:version
                                                        session:nil
                                              completionHandler:^(GBAppCall *call) {
                                                  if (handler) {
                                                      handler(call, call.dialogData.results, call.error);
                                                  }
                                              }];
        }
    }
    [GBAppEvents logImplicitEvent:GBAppEventNameGBDialogsPresentShareDialogOG
                       valueToSum:nil
                       parameters:@{ GBAppEventParameterDialogOutcome : call ?
                                                                        GBAppEventsDialogOutcomeValue_Completed :
                                                                        GBAppEventsDialogOutcomeValue_Failed }
                          session:nil];

    return call;
}

+ (GBAppCall *)presentShareDialogWithOpenGraphAction:(id<GBOpenGraphAction>)action
                                          actionType:(NSString *)actionType
                                 previewPropertyName:(NSString *)previewPropertyName
                                             handler:(GBDialogAppCallCompletionHandler) handler {
    return [GBDialogs presentShareDialogWithOpenGraphAction:action
                                                 actionType:actionType
                                        previewPropertyName:previewPropertyName
                                                clientState:nil
                                                    handler:handler];
}

+ (GBAppCall *)presentShareDialogWithOpenGraphAction:(id<GBOpenGraphAction>)action
                                          actionType:(NSString *)actionType
                                 previewPropertyName:(NSString*)previewPropertyName
                                         clientState:(NSDictionary *)clientState
                                             handler:(GBDialogAppCallCompletionHandler) handler {
    GBOpenGraphActionShareDialogParams *params = [[[GBOpenGraphActionShareDialogParams alloc] init] autorelease];

    // If we have OG objects, we want to pass just their URL or id to the share dialog.
    params.action = action;
    params.actionType = actionType;
    params.previewPropertyName = previewPropertyName;

    return [self presentShareDialogWithOpenGraphActionParams:params
                                                 clientState:clientState
                                                     handler:handler];
}

+ (SLComposeViewController*)composeViewControllerWithSession:(GBSession*)session
                                                     handler:(GBOSIntegratedShareDialogHandler)handler {
    // Can we even call the iOS API?
    Class composeViewControllerClass = [[GBDynamicFrameworkLoader loadClass:@"SLComposeViewController" withFramework:@"Social"] class];
    if (composeViewControllerClass == nil ||
        [composeViewControllerClass isAvailableForServiceType:[GBDynamicFrameworkLoader loadStringConstant:@"SLServiceTypeFacebook" withFramework:@"Social"]] == NO) {
        if (handler) {
            handler( GBOSIntegratedShareDialogResultError, [self createError:GBErrorDialogNotSupported
                                                                     session:session]);
        }
        return nil;
    }

    if (session == nil) {
        // No session provided -- do we have an activeSession? We must either have a session that
        // was authenticated with native auth, or no session at all (in which case the app is
        // running unTOSed and we will rely on the OS to authenticate/TOS the user).
        session = [GBSession activeSession];
    }
    if (session != nil) {
        // If we have an open session and it's not native auth, fail. If the session is
        // not open, attempting to put up the dialog will prompt the user to configure
        // their account.
        if (session.isOpen && session.accessTokenData.loginType != GBSessionLoginTypeSystemAccount) {
            if (handler) {
                handler( GBOSIntegratedShareDialogResultError, [self createError:GBErrorDialogInvalidForSession
                                                                         session:session]);
            }
            return nil;
        }
    }

    SLComposeViewController *composeViewController = [composeViewControllerClass composeViewControllerForServiceType:[GBDynamicFrameworkLoader loadStringConstant:@"SLServiceTypeFacebook" withFramework:@"Social"]];
    if (composeViewController == nil) {
        if (handler) {
            handler( GBOSIntegratedShareDialogResultError, [self createError:GBErrorDialogCantBeDisplayed
                                                                     session:session]);
        }
        return nil;
    }
    return composeViewController;
}

+ (NSError *)createError:(NSString *)reason
                 session:(GBSession *)session {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[GBErrorDialogReasonKey] = reason;
    if (session) {
        userInfo[GBErrorSessionKey] = session;
    }
    NSError *error = [NSError errorWithDomain:GbombSDKDomain
                                         code:GBErrorDialog
                                     userInfo:userInfo];
    return error;
}

@end

