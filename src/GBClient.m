//
//  GBClient.m
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/11.
//
//
#import "GDialog.h"
#import "GBSettings.h"
#import "FBSettings.h"
#import "GBSession.h"
#import "GBUtility.h"
#import "FBSession.h"
#import "FTSession.h"
#import <Foundation/Foundation.h>
#import "GBClient.h"
#import "FBAccessTokenData.h"
#import "GBAccessTokenData.h"

static NSString *const GDialogMethod = @"index.php";
static NSString* GB_API_SERVICE_URL   = @"http://api.gbombgames.com/";
static const NSTimeInterval TIMEOUT = 180.0;
static NSString* USER_AGENT = @"GBomb";
static NSURLConnection *_connection=nil;
static NSMutableData *_gbResponseData;
static NSURLResponse *_gbResponse;

@implementation GBClient {

}

@synthesize delegate = _delegate;

- (id)initWithGameId : (NSString*) gameId {
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *gclient = [infoDict objectForKey:@"GbombClientId"];
    
    NSArray *permissions =[NSArray arrayWithObjects:@"email", nil];
    
    NSString *urlSchemeSuffix = [GBSettings defaultUrlSchemeSuffix];
    GBSessionTokenCachingStrategy *gbtokenCaching= [GBSessionTokenCachingStrategy defaultInstance];
    
    _gbsession=[[GBSession alloc] initWithAppID:gclient
                                    permissions:permissions
                                urlSchemeSuffix:urlSchemeSuffix
                             tokenCacheStrategy:gbtokenCaching];
    
    
    urlSchemeSuffix = [FBSettings defaultUrlSchemeSuffix];
    FBSessionTokenCachingStrategy *fbtokenCaching= [FBSessionTokenCachingStrategy defaultInstance];
    
    _fbsession=[[FBSession alloc] initWithAppID:gclient
                                    permissions:permissions
                                urlSchemeSuffix:urlSchemeSuffix
                             tokenCacheStrategy:fbtokenCaching];
    
    _ftsession=[FTSession init];
    
}

- (id)login {
    NSString *gDialogURL = [[GBUtility sdkBaseURL] stringByAppendingString:GDialogMethod];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    // open an inline login dialog. This will require the user to enter his or her credentials.
    _gdialog = [[[GDialog alloc]
                             initWithURL:gDialogURL params:params isViewInvisible:NO delegate:self]
                            autorelease];
    [_gdialog show];
}

- (id)callService {
    
}

- (id)getProductList {
    
}

- (id)purchase : (NSString*) cid serverId :(NSString*) server
        itemId : (NSString*) item onSalesId : (NSString*) onsalesId
     providerId : (NSString*) providerId characterProfile : (NSString*)characterProfile
          token : (NSString*) token {
    
}

- (id)subPush : (NSString*) regid {
    
    NSString* api = @"sub.php";
    NSString* uri=[GB_API_SERVICE_URL
                   stringByAppendingString:api];
    
    NSMutableURLRequest* request =
    [NSMutableURLRequest requestWithURL:[NSURL URLWithString:uri]
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:TIMEOUT];
    
    
    [request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    
    [request setHTTPMethod:@"GET"];
    
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (id)unsubPush : (NSString*) regid {
    NSString* api = @"unsub.php";
    NSString* uri=[GB_API_SERVICE_URL
                   stringByAppendingString:api];
    
    NSMutableURLRequest* request =
    [NSMutableURLRequest requestWithURL:[NSURL URLWithString:uri]
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:TIMEOUT];
    
    
    [request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    
    [request setHTTPMethod:@"GET"];
    
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

/**
 * Find a specific parameter from the url
 */
- (NSString *) getStringFromUrl: (NSString*) url needle:(NSString *) needle {
    NSString * str = nil;
    NSRange start = [url rangeOfString:needle];
    if (start.location != NSNotFound) {
        // confirm that the parameter is not a partial name match
        unichar c = '?';
        if (start.location != 0) {
            c = [url characterAtIndex:start.location - 1];
        }
        if (c == '?' || c == '&' || c == '#') {
            NSRange end = [[url substringFromIndex:start.location+start.length] rangeOfString:@"&"];
            NSUInteger offset = start.location+start.length;
            str = end.location == NSNotFound ?
            [url substringFromIndex:offset] :
            [url substringWithRange:NSMakeRange(offset, end.location)];
            str = [str stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
    return str;
}


- (void)GBClientDidComplete:(NSInteger) code result:(NSString *)json {
    // retain self for the life of this method, in case we are released by a client
    id me = [self retain];
    
    @try {
        // call into client code
        if ([_delegate respondsToSelector:@selector(didComplete:)]) {
            [_delegate didComplete:code result:json];
        }
        
    } @finally {
        [me release];
    }
}

- (void)GBClientDidNotComplete:(NSInteger) code result:(NSString *)json {
    // retain self for the life of this method, in case we are released by a client
    id me = [self retain];
    
    @try {
        // call into client code
        if ([_delegate respondsToSelector:@selector(didNotComplete:)]) {
            [_delegate didNotComplete:code result:json];
        }
        
    } @finally {
        [me release];
    }
}



- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _gbResponse=response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_gbResponseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    NSString* rstr= [[NSString alloc] initWithData:_gbResponseData   encoding:NSUTF8StringEncoding];
    [self GBClientDidComplete:100 result:rstr];
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSString* rstr= [NSString alloc];
    
    [rstr stringByAppendingFormat: @"{ \"code\": %d ,  \"status\": %d }",
     error.code,
     (NSInteger)[(NSHTTPURLResponse *)_gbResponse statusCode]];

    [self GBClientDidNotComplete:115 result:rstr];
}

/**
 * Called when the dialog succeeds and is about to be dismissed.
 */
- (void)dialogDidComplete:(GDialog *)dialog {
    
}

/**
 * Called when the dialog succeeds with a returning url.
 */
- (void)dialogCompleteWithUrl:(NSURL *)url {
    
    NSString * method = [self getStringFromUrl:[url absoluteString] needle:@"method="];
    if ([method isEqualToString:@"trial"]) {
        [_ftsession openWithCompletionHandler:^(FTSession *session, FTSessionState status, NSError *error) {
            NSString* rstr= [NSString alloc];
            [rstr stringByAppendingFormat: @"{ \"provider_id\": %s ,  \"token\": %s }","trial",[_ftsession.token UTF8String]];
        }];
    }
    else if([method isEqualToString:@"facebook"]) {
        [_fbsession openWithCompletionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
            NSString* rstr= [NSString alloc];
            [rstr stringByAppendingFormat: @"{ \"provider_id\": %s ,  \"token\": %s }","facebook",[_fbsession.accessTokenData.accessToken UTF8String]];
        }];
    }
    else if([method isEqualToString:@"gbombgames"]) {
        [_gbsession openWithCompletionHandler:^(GBSession *session, GBSessionState status, NSError *error) {
            NSString* rstr= [NSString alloc];
            [rstr stringByAppendingFormat: @"{ \"provider_id\": %s ,  \"token\": %s }","gbombgames",[_gbsession.accessTokenData.accessToken UTF8String]];
        }];
    }
}

/**
 * Called when the dialog get canceled by the user.
 */
- (void)dialogDidNotCompleteWithUrl:(NSURL *)url {
    
}

/**
 * Called when the dialog is cancelled and is about to be dismissed.
 */
- (void)dialogDidNotComplete:(GDialog *)dialog {
    
}

/**
 * Called when dialog failed to load due to an error.
 */
- (void)dialog:(GDialog*)dialog didFailWithError:(NSError *)error {
    
}

/**
 * Asks if a link touched by a user should be opened in an external browser.
 *
 * If a user touches a link, the default behavior is to open the link in the Safari browser,
 * which will cause your app to quit.  You may want to prevent this from happening, open the link
 * in your own internal browser, or perhaps warn the user that they are about to leave your app.
 * If so, implement this method on your delegate and return NO.  If you warn the user, you
 * should hold onto the URL and once you have received their acknowledgement open the URL yourself
 * using [[UIApplication sharedApplication] openURL:].
 */
- (BOOL)dialog:(GDialog*)dialog shouldOpenURLInExternalBrowser:(NSURL *)url {
    
}


@end