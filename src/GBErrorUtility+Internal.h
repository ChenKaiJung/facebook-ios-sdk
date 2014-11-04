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
#import "GBErrorUtility.h"

typedef enum {
    GBAuthSubcodeNone = 0,
    GBAuthSubcodeAppNotInstalled = 458,
    GBAuthSubcodeUserCheckpointed = 459,
    GBAuthSubcodePasswordChanged = 460,
    GBAuthSubcodeExpired = 463,
    GBAuthSubcodeUnconfirmedUser = 464,
} GBAuthSubcode;

extern const int GBOAuthError;

// Internal class collecting error related methods.

@interface GBErrorUtility(Internal)

+ (GBErrorCategory)gberrorCategoryFromError:(NSError *)error
                                       code:(int)code
                                   subcode:(int)subcode
                      returningUserMessage:(NSString **)puserMessage
                       andShouldNotifyUser:(BOOL *)pshouldNotifyUser;

+ (void)gberrorGetCodeValueForError:(NSError *)error
                              index:(NSUInteger)index
                               code:(int *)pcode
                            subcode:(int *)psubcode;

+ (NSError *)gberrorForSystemPasswordChange:(NSError *)innerError;

+ (NSError *)gberrorForRetry:(NSError *)innerError;

@end
