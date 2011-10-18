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
        if ([_loginDelegate respondsToSelector:@selector(ftDialogLogin:)]) {
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
    if ([_loginDelegate respondsToSelector:@selector(ftDialogNotLogin:)]) {
        [_loginDelegate ftDialogNotLogin:YES];
    }
}


- (void)dismissWithError:(NSError*)error animated:(BOOL)animated {
    if ([_loginDelegate respondsToSelector:@selector(ftDialogLoginError:)]) {
         [_loginDelegate ftDialogLoginError:error];
    }
    
    [super dismissWithError:error animated:animated];
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (!(([error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -999) ||
          ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102))) {
        [super webView:webView didFailLoadWithError:error];
        if ([_loginDelegate respondsToSelector:@selector(ftDialogNotLogin:)]) {
            [_loginDelegate ftDialogNotLogin:NO];
        }
    }
}

/*
 * Compatible functions for legacy funtown login, will be removed in the near future
 */
- (void)dialogwillPost:(NSString *)body {
    if ([_loginDelegate respondsToSelector:@selector(ftDialogWillPost:)]) {
        [_loginDelegate ftDialogWillPost:body];        
    }      
}
@end
