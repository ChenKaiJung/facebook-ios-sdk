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

#import "GBNativeDialogs.h"

#import <Social/Social.h>

#import "GBAccessTokenData+Internal.h"
#import "GBAccessTokenData.h"
#import "GBAppBridge.h"
#import "GBAppCall+Internal.h"
#import "GBAppEvents+Internal.h"
#import "GBAppLinkData+Internal.h"
#import "GBDialogs+Internal.h"
#import "GBDialogsData+Internal.h"
#import "GBDialogsParams+Internal.h"
#import "GBError.h"
#import "GBLoginDialogParams.h"
#import "GBOpenGraphActionShareDialogParams.h"
#import "GBSession.h"
#import "GBShareDialogParams.h"
#import "GBUtility.h"

@implementation GBNativeDialogs

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
+ (GBOSIntegratedShareDialogHandler)handlerFromHandler:(GBShareDialogHandler)handler {
    if (handler) {
        GBOSIntegratedShareDialogHandler fancy = ^(GBOSIntegratedShareDialogResult result, NSError *error) {
            handler(result, error);
        };
        return [[fancy copy] autorelease];
    }
    return nil;
}
#pragma GCC diagnostic pop

+ (BOOL)presentShareDialogModallyFrom:(UIViewController*)viewController
                          initialText:(NSString*)initialText
                                image:(UIImage*)image
                                  url:(NSURL*)url
                              handler:(GBShareDialogHandler)handler {
    return [GBDialogs presentOSIntegratedShareDialogModallyFrom:viewController
                                                    initialText:initialText
                                                          image:image
                                                            url:url
                                                        handler:[GBNativeDialogs handlerFromHandler:handler]];
}

+ (BOOL)presentShareDialogModallyFrom:(UIViewController*)viewController
                          initialText:(NSString*)initialText
                               images:(NSArray*)images
                                 urls:(NSArray*)urls
                              handler:(GBShareDialogHandler)handler {
    return [GBDialogs presentOSIntegratedShareDialogModallyFrom:viewController
                                                    initialText:initialText
                                                         images:images
                                                           urls:urls
                                                        handler:[GBNativeDialogs handlerFromHandler:handler]];
}

+ (BOOL)presentShareDialogModallyFrom:(UIViewController*)viewController
                              session:(GBSession*)session
                          initialText:(NSString*)initialText
                               images:(NSArray*)images
                                 urls:(NSArray*)urls
                              handler:(GBShareDialogHandler)handler {
    return [GBDialogs presentOSIntegratedShareDialogModallyFrom:viewController
                                                        session:session
                                                    initialText:initialText
                                                         images:images
                                                           urls:urls
                                                        handler:[GBNativeDialogs handlerFromHandler:handler]];
}

+ (BOOL)canPresentShareDialogWithSession:(GBSession*)session {
    return [GBDialogs canPresentOSIntegratedShareDialogWithSession:session];
}

@end
