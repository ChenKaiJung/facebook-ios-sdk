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

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

#import "GBAppCall.h"
#import "GBOpenGraphActionShareDialogParams.h"
#import "GBShareDialogParams.h"

@class GBSession;
@protocol GBOpenGraphAction;

// note that the following class and types are deprecated in favor of GBDialogs and its methods

/*!
 @typedef GBNativeDialogResult enum

 @abstract
 Please note that this enum and its related methods have been deprecated, please migrate your
 code to use `GBOSIntegratedShareDialogResult` and its related methods.
 */
typedef enum {
    /*! Indicates that the dialog action completed successfully. */
    GBNativeDialogResultSucceeded,
    /*! Indicates that the dialog action was cancelled (either by the user or the system). */
    GBNativeDialogResultCancelled,
    /*! Indicates that the dialog could not be shown (because not on ios6 or ios6 auth was not used). */
    GBNativeDialogResultError
} GBNativeDialogResult
__attribute__((deprecated));

/*!
 @typedef

 @abstract
 Please note that `GBShareDialogHandler` and its related methods have been deprecated, please migrate your
 code to use `GBOSIntegratedShareDialogHandler` and its related methods.
 */
typedef void (^GBShareDialogHandler)(GBNativeDialogResult result, NSError *error)
__attribute__((deprecated));

/*!
 @class GBNativeDialogs

 @abstract
 Please note that `GBNativeDialogs` has been deprecated, please migrate your
 code to use `GBDialogs`.
 */
@interface GBNativeDialogs : NSObject

/*!
 @abstract
 Please note that this method has been deprecated, please migrate your
 code to use `GBDialogs` and the related method `presentOSIntegratedShareDialogModallyFrom`.
 */
+ (BOOL)presentShareDialogModallyFrom:(UIViewController*)viewController
                          initialText:(NSString*)initialText
                                image:(UIImage*)image
                                  url:(NSURL*)url
                              handler:(GBShareDialogHandler)handler
__attribute__((deprecated));

/*!
 @abstract
 Please note that this method has been deprecated, please migrate your
 code to use `GBDialogs` and the related method `presentOSIntegratedShareDialogModallyFrom`.
 */
+ (BOOL)presentShareDialogModallyFrom:(UIViewController*)viewController
                          initialText:(NSString*)initialText
                               images:(NSArray*)images
                                 urls:(NSArray*)urls
                              handler:(GBShareDialogHandler)handler
__attribute__((deprecated));

/*!
 @abstract
 Please note that this method has been deprecated, please migrate your
 code to use `GBDialogs` and the related method `presentOSIntegratedShareDialogModallyFrom`.
 */
+ (BOOL)presentShareDialogModallyFrom:(UIViewController*)viewController
                              session:(GBSession*)session
                          initialText:(NSString*)initialText
                               images:(NSArray*)images
                                 urls:(NSArray*)urls
                              handler:(GBShareDialogHandler)handler
__attribute__((deprecated));

/*!
 @abstract
 Please note that this method has been deprecated, please migrate your
 code to use `GBDialogs` and the related method `canPresentOSIntegratedShareDialogWithSession`.
 */
+ (BOOL)canPresentShareDialogWithSession:(GBSession*)session __attribute__((deprecated));

@end
