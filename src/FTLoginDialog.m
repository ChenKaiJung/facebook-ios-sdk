//
//  FTLoginDialog.m
//  DemoApp
//
//  Created by kaijung on 11/9/27.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "FTDialog.h"
#import "FTLoginDialog.h"

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation FTLoginDialog

///////////////////////////////////////////////////////////////////////////////////////////////////
// public 

/*
 * initialize the FBLoginDialog with url and parameters
 */
- (id)initWithURL:(NSString*) loginURL 
      loginParams:(NSMutableDictionary*) params 
         delegate:(id <FTLoginDialogDelegate>) delegate{
    
    self = [super init];
    _serverURL = [loginURL retain];
    _params = [params retain];
    _loginDelegate = delegate;
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// FBDialog

/**
 * Override FBDialog : to call when the webView Dialog did succeed
 */
- (void) dialogDidSucceed:(NSURL*)url {
    NSString *q = [url absoluteString];
    NSString *code = [self getStringFromUrl:q needle:@"code="];

    
    
    if ((code == (NSString *) [NSNull null]) || (code.length == 0)) {
        [self dialogDidCancel:url];
        [self dismissWithSuccess:NO animated:YES];
    } else {    
        if ([_loginDelegate respondsToSelector:@selector(ftDialogLogin:expirationDate:)]) {
            [_loginDelegate ftDialogLogin:code];
        }
        [self dismissWithSuccess:YES animated:YES];
    }
    
}

/**
 * Override FBDialog : to call with the login dialog get canceled 
 */
- (void)dialogDidCancel:(NSURL *)url {
    [self dismissWithSuccess:NO animated:YES];
    if ([_loginDelegate respondsToSelector:@selector(fbDialogNotLogin:)]) {
        [_loginDelegate ftDialogNotLogin:YES];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (!(([error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -999) ||
          ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102))) {
        [super webView:webView didFailLoadWithError:error];
        if ([_loginDelegate respondsToSelector:@selector(fbDialogNotLogin:)]) {
            [_loginDelegate ftDialogNotLogin:NO];
        }
    }
}

@end
