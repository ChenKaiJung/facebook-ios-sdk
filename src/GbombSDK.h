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

// core
#import "GBAccessTokenData.h"
#import "GBAppCall.h"
#import "GBAppEvents.h"
#import "GBCacheDescriptor.h"
#import "GBDialogs.h"
#import "GBError.h"
#import "GBErrorUtility.h"
#import "GBFrictionlessRecipientCache.h"
#import "GBFriendPickerViewController.h"
#import "GBGraphLocation.h"
#import "GBGraphObject.h"           // + design summary for graph component-group
#import "GBGraphPlace.h"
#import "GBGraphUser.h"
#import "GBInsights.h"
#import "GBLoginView.h"
#import "GBNativeDialogs.h"         // deprecated, use GBDialogs.h
#import "GBOpenGraphAction.h"
#import "GBOpenGraphActionShareDialogParams.h"
#import "GBOpenGraphObject.h"
#import "GBPlacePickerViewController.h"
#import "GBProfilePictureView.h"
#import "GBRequest.h"
#import "GBSession.h"
#import "GBSessionTokenCachingStrategy.h"
#import "GBSettings.h"
#import "GBShareDialogParams.h"
#import "GBUserSettingsViewController.h"
#import "GBWebDialogs.h"
#import "NSError+GBError.h"

/*!
 @header
 
 @abstract  Library header, import this to import all of the public types
 in the Facebook SDK
 
 @discussion
 
 ////////////////////////////////////////////////////////////////////////////////
 
 
 Summary: this header summarizes the structure and goals of the Facebook SDK for iOS.
 Goals:
 * Leverage and work well with modern features of iOS (e.g. blocks, ARC, etc.)
 * Patterned after best of breed iOS frameworks (e.g. naming, pattern-use, etc.)
 * Common integration experience is simple & easy to describe
 * Factored to enable a growing list of scenarios over time
 
 Notes on approaches:
 1. We use a key scenario to drive prioritization of work for a given update
 2. We are building-atop and refactoring, rather than replacing, existing iOS SDK releases
 3. We use take an incremental approach where we can choose to maintain as little or as much compatibility with the existing SDK needed
 a) and so we will be developing to this approach
 b) and then at push-time for a release we will decide when/what to break
 on a feature by feature basis
 4. Some light but critical infrastructure is needed to support both the goals
 and the execution of this change (e.g. a build/package/deploy process)
 
 Design points:
 We will move to a more object-oriented approach, in order to facilitate the
 addition of a different class of objects, such as controls and visual helpers
 (e.g. GBLikeView, GBPersonView), as well as sub-frameworks to enable scenarios
 such (e.g. GBOpenGraphEntity, GBLocalEntityCache, etc.)
 
 As we add features, it will no longer be appropriate to host all functionality
 in the Facebook class, though it will be maintained for some time for migration
 purposes. Instead functionality lives in related collections of classes.
 
 <pre>
 @textblock
 
 *------------* *----------*  *----------------* *---*
 Scenario --> |GBPersonView| |GBLikeView|  | GBPlacePicker  | | F |
 *------------* *----------*  *----------------* | a |
 *-------------------*  *----------*  *--------* | c |
 Component --> |   GBGraphObject   |  | GBDialog |  | GBView | | e |
 *-------------------*  *----------*  *--------* | b |
 *---------* *---------* *---------------------* | o |
 Core --> |GBSession| |GBRequest| |Utilities (e.g. JSON)| | o |
 *---------* *---------* *---------------------* * k *
 
 @/textblock
 </pre>
 
 The figure above describes three layers of functionality, with the existing
 Facebook on the side as a helper proxy to a subset of the overall SDK. The
 layers loosely organize the SDK into *Core Objects* necessary to interface
 with Facebook, higher-level *Framework Components* that feel like natural
 extensions to existing frameworks such as UIKit and Foundation, but which
 surface behavior broadly applicable to Facebook, and finally the
 *Scenario Objects*, which provide deeper turn-key capibilities for useful
 mobile scenarios.
 
 Use example (low barrier use case):
 
 <pre>
 @textblock
 
 // log on to Facebook
 [GBSession sessionOpenWithPermissions:nil
 completionHandler:^(GBSession *session,
 GBSessionState status,
 NSError *error) {
 if (session.isOpen) {
 // request basic information for the user
 [GBRequestConnection startWithGraphPath:@"me"
 completionHandler:^void(GBRequestConnection *request,
 id result,
 NSError *error) {
 if (!error) {
 // get json from result
 }
 }];
 }
 }];
 @/textblock
 </pre>
 
 */

#define GB_IOS_SDK_VERSION_STRING @"3.10.0"

