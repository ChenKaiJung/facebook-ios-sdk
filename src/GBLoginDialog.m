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

#import "GBLoginDialog.h"

#import "GBDialog.h"
#import "GBUtility.h"

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation GBLoginDialog

///////////////////////////////////////////////////////////////////////////////////////////////////
// public

/*
 * initialize the GBLoginDialog with url and parameters
 */
- (id)initWithURL:(NSString*) loginURL
      loginParams:(NSMutableDictionary*) params
         delegate:(id <GBLoginDialogDelegate>) delegate{

    self = [super init];
    _serverURL = [loginURL retain];
    _params = [params retain];
    _loginDelegate = delegate;
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// GBDialog

/**
 * Override GBDialog : to call when the webView Dialog did succeed
 */
- (void) dialogDidSucceed:(NSURL*)url {

  NSString *q = [url absoluteString];
  NSString *token = [self getStringFromUrl:q needle:@"access_token="];
  NSString *expTime = [self getStringFromUrl:q needle:@"expires_in="];
  NSDate *expirationDate =nil;
    
  NSString * access_token = [self getStringFromUrl:[url absoluteString] needle:@"access_token="];
  //NSString * session_key = [self getStringFromUrl:[url absoluteString] needle:@"session_key="];
  NSString *code = [self getStringFromUrl:q needle:@"code="];
    
#ifdef DEBUG
  //NSLog(@"dialogDidSucceed : sessionkey = %@, accessToken = %@",session_key, access_token);
#endif
    
  if (expTime != nil) {
    int expVal = [expTime intValue];
    if (expVal == 0) {
      expirationDate = [NSDate distantFuture];
    } else {
      expirationDate = [NSDate dateWithTimeIntervalSinceNow:expVal];
    } 
  } 
  
  if ((token == (NSString *) [NSNull null]) || (token.length == 0)) {
    [self dialogDidCancel:url];
    [self dismissWithSuccess:NO animated:YES];
  } else {
      if ([_loginDelegate respondsToSelector:@selector(fbDialogLogin:expirationDate:params:)]) {
      //[_loginDelegate fbDialogLogin:token expirationDate:expirationDate];
        NSDictionary *params = [GBUtility queryParamsDictionaryFromGBURL:url];
        if ( code != (NSString *) [NSNull null] && code.length != 0) {
            [_loginDelegate fbDialogLogin:access_token expirationDate:expirationDate params:params];
        }
//        else if (session_key == (NSString *) [NSNull null]){
//            [_loginDelegate fbDialogLogin:access_token expirationDate:expirationDate params:params];
//        }
        else {
            [_loginDelegate fbDialogLogin:access_token expirationDate:expirationDate params:params];
        }
        [self dismissWithSuccess:YES animated:YES];
    }
  }

}

/**
 * Override GBDialog : to call with the login dialog get canceled
 */
- (void)dialogDidCancel:(NSURL *)url {
    [self dismissWithSuccess:NO animated:YES];
    if ([_loginDelegate respondsToSelector:@selector(fbDialogNotLogin:)]) {
        [_loginDelegate fbDialogNotLogin:YES];
    }
}


- (void)dismissWithError:(NSError*)error animated:(BOOL)animated {
    if ([_loginDelegate respondsToSelector:@selector(fbDialogNotLogin:)]) {
        [_loginDelegate fbDialogLoginError:error];
    }
    
    [super dismissWithError:error animated:animated];
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (!(([error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -999) ||
          ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102))) {
        [super webView:webView didFailLoadWithError:error];
        if ([_loginDelegate respondsToSelector:@selector(fbDialogNotLogin:)]) {
            [_loginDelegate fbDialogNotLogin:NO];
        }
    }
}

@end
