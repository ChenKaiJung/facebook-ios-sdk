/*
 * Copyright 2010 Facebook
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
#import "FTDialog.h"
@protocol FTLoginDialogDelegate;

/**
 * Do not use this interface directly, instead, use authorize in Facebook.h
 *
 * Facebook Login Dialog interface for start the facebook webView login dialog.
 * It start pop-ups prompting for credentials and permissions.
 */

@interface FTLoginDialog : FTDialog {
    id<FTLoginDialogDelegate> _loginDelegate;
}

-(id) initWithURL:(NSString *) loginURL
      loginParams:(NSMutableDictionary *) params
         delegate:(id <FTLoginDialogDelegate>) delegate;
@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@protocol FTLoginDialogDelegate <NSObject>

- (void)ftDialogLogin:(NSString*)token expirationDate:(NSDate*)expirationDate;

- (void)ftDialogLogin:(NSString*)code;

- (void)ftDialogLogin:(NSString*)token sessionKey:(NSString*)sessionKey;

- (void)ftDialogNotLogin:(BOOL)cancelled;

- (void)ftDialogLoginError:(NSError*)error;

/*
 * Compatible functions for legacy funtown login, will be removed in the near future
 */
- (void)ftDialogWillPost:(NSString *)body;
@end
