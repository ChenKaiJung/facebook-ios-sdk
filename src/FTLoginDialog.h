//
//  FTLoginDialog.h
//  DemoApp
//
//  Created by kaijung on 11/9/27.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//
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

- (void)ftDialogNotLogin:(BOOL)cancelled;

@end
