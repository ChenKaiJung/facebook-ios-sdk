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

#import "GBDialogs.h"
#import "GBLoginDialogParams.h"

@interface GBDialogs (Internal)

/*!
 @abstract
 Determines whether the corresponding presentGBLoginDialogWithParams:clientState:handler:
 is supported by the installed version of the Facebook app for iOS.
 */
+ (BOOL)canPresentLoginDialogWithParams:(GBLoginDialogParams *)params;

/*!
 @abstract
 Switches to the native Facebook App and shows the login dialog for the requested login params

 @param params Params for the native Login dialog

 @param clientState An NSDictionary that's passed through when the completion handler
 is called. This is useful for the app to maintain state. May be nil.

 @param handler A completion handler that may be called when the login is
 complete. May be nil. If non-nil, the handler will always be called asynchronously.

 @return An GBAppCall object that will also be passed into the provided
 GBAppCallCompletionHandler.

 @discussion A non-nil GBAppCall object is only returned if the corresponding
 canPresentGBLoginDialogWithParams method is also returning YES for the same params.
*/
+ (GBAppCall *)presentLoginDialogWithParams:(GBLoginDialogParams *)params
                                    clientState:(NSDictionary *)clientState
                                        handler:(GBDialogAppCallCompletionHandler)handler;

@end
