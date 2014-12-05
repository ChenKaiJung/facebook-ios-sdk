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
#import "GBSessionTokenCachingStrategy.h"
#import "FBSessionTokenCachingStrategy.h"

static NSString *const GDialogMethod = @"index.php";
static NSString *const CallServiceMethod = @"cc.php";
static NSString* GB_API_SERVICE_URL   = @"http://api.gbombgames.com/";
static const NSTimeInterval TIMEOUT = 180.0;
static NSString* USER_AGENT = @"GBomb";
static NSURLConnection *_connection=nil;
static NSMutableData *_gbResponseData;
static NSURLResponse *_gbResponse;


@interface GBClient () <NSURLConnectionDelegate,GDialogDelegate> {
    id<GBClientDelegate> _delegate;
    GBSession* _gbsession;
    FTSession* _ftsession;
    FBSession* _fbsession;
    GDialog * _gdialog;
    
}
@end

@implementation GBClient {

}

@synthesize delegate = _delegate,
            gbsession= _gbsession,
            ftsession=_ftsession,
            fbsession=_fbsession,
            gdialog=_gdialog;

- (id)initWithGameId : (NSString*) gameId {
    
    self = [super init];
    
    NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *gclient = [infoDict objectForKey:@"GbombClientID"];

    if (gclient == nil) {
        gclient = @"1234567890";
    }
    NSString *fclient = [infoDict objectForKey:@"FacebookAppID"];
    if (fclient == nil) {
        fclient = @"1234567890";
    }
    
    NSArray *permissions =[NSArray arrayWithObjects:@"email", nil];
    
    NSString *urlSchemeSuffix = [GBSettings defaultUrlSchemeSuffix];
    GBSessionTokenCachingStrategy *gbtokenCaching= [GBSessionTokenCachingStrategy defaultInstance];
    
    _gbsession=[[GBSession alloc] initWithAppID:gclient
                                    permissions:permissions
                                urlSchemeSuffix:urlSchemeSuffix
                             tokenCacheStrategy:gbtokenCaching];
    
    
    urlSchemeSuffix = [FBSettings defaultUrlSchemeSuffix];
    FBSessionTokenCachingStrategy *fbtokenCaching= [FBSessionTokenCachingStrategy defaultInstance];
    
    _fbsession=[[FBSession alloc] initWithAppID:fclient
                                    permissions:permissions
                                urlSchemeSuffix:urlSchemeSuffix
                             tokenCacheStrategy:fbtokenCaching];
    
    _ftsession=[[FTSession alloc] init];
    
    //_delegate = delegate;
    
    return self;
}

- (void)dealloc {
    
    [_ftsession release];
    [_fbsession release];
    [_gbsession release];

    [super dealloc];
}

- (void)login {
    NSString *gDialogURL = [[GBUtility sdkBaseURL] stringByAppendingString:GDialogMethod];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    // open an inline login dialog. This will require the user to enter his or her credentials.
    _gdialog = [[[GDialog alloc]
                             initWithURL:gDialogURL params:params isViewInvisible:NO delegate:self]
                            autorelease];
    [_gdialog show];
}

- (void)callService  : (NSString*)characterProfile {
    NSString *gDialogURL = [[GBUtility sdkBaseURL] stringByAppendingString:CallServiceMethod];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSArray *urlComponents = [characterProfile componentsSeparatedByString:@"&"];

    for (NSString *keyValuePair in urlComponents)
    {
        NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
        NSString *key = [pairComponents objectAtIndex:0];
        NSString *value = [pairComponents objectAtIndex:1];
        
        [params setObject:value forKey:key];
    }
    
    // open an inline login dialog. This will require the user to enter his or her credentials.
    _gdialog = [[[GDialog alloc]
                 initWithURL:gDialogURL params:params isViewInvisible:NO delegate:self]
                autorelease];
    [_gdialog show];
}

- (void)getProductList : (NSString*)characterProfile {
    
}

- (void)purchase : (NSString*) cid serverId :(NSString*) server
        itemId : (NSString*) item onSalesId : (NSString*) onsalesId
     providerId : (NSString*) providerId characterProfile : (NSString*)characterProfile
          token : (NSString*) token {
    
}

- (void)subPush : (NSString*) regid {
    
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

- (void)unsubPush : (NSString*) regid {
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

//- (void)didFailWithError:(NSError *)error {
    
//}

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


- (void)gbClientDidComplete:(NSInteger) code result:(NSString *)json {
    // retain self for the life of this method, in case we are released by a client
    
    @try {
        
        [_delegate didComplete:code result:json];

    } @catch (NSException *exception) {
        NSLog(@"Exception:%@",exception);
    } @finally {
        id me = [self retain];
        [me release];
    }
}

- (void)gbClientDidNotComplete:(NSInteger) code result:(NSString *)json {
    // retain self for the life of this method, in case we are released by a client
    
    @try {
        // call into client code
        //if ([_delegate respondsToSelector:@selector(didNotComplete:)]) {
            [_delegate didNotComplete:code result:json];
        //}
    } @catch (NSException *exception) {
        NSLog(@"Exception:%@",exception);
    } @finally {
        id me = [self retain];
        [me release];
    }
}

- (void)gbClientDidFailWithError:(NSError *)error {
    // retain self for the life of this method, in case we are released by a client
    id me = [self retain];
    
    @try {
        // call into client code
        //if ([_delegate respondsToSelector:@selector(didFailWithError:)]) {
            [_delegate didFailWithError:error];
        //}
        
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
    [self gbClientDidComplete:100 result:rstr];
    [rstr release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSString* rstr= [NSString alloc];
    
    [rstr stringByAppendingFormat: @"{ \"code\": %d ,  \"status\": %d }",
     error.code,
     (NSInteger)[(NSHTTPURLResponse *)_gbResponse statusCode]];

    [self gbClientDidNotComplete:115 result:rstr];
    [rstr release];
}

- (void)getUserProfile:(NSString *) provider_id result:(NSString *)token {
    
    NSString* api = @"/v1/profile.php";
    NSString* uri=[[[[[GB_API_SERVICE_URL
                    stringByAppendingString:api]
                    stringByAppendingString:@"?provider_id=" ]
                    stringByAppendingString:provider_id]
                    stringByAppendingString:@"&access_token="]
                    stringByAppendingString:token];
    
    NSMutableURLRequest* request =
    [NSMutableURLRequest requestWithURL:[NSURL URLWithString:uri]
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:TIMEOUT];
    
    
    [request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    
    [request setHTTPMethod:@"GET"];
    
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
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
    if ([url.path isEqualToString:@"/trial.html"]) {
        [_ftsession openWithCompletionHandler:^(FTSession *session, FTSessionState status, NSError *error) {
            NSString* rstr;
            switch (status) {
                case FTSessionStateOpen:
                    
                    
                    
                    // call the legacy session delegate
                    rstr=[[NSString alloc] initWithFormat: @"{ \"provider_id\": \"%s\" ,  \"token\": \"%s\", \"uuid\": \"%s\" }","trial",[_ftsession.token UTF8String],[_ftsession.uid UTF8String]];
                    
                    
                    [self gbClientDidComplete:100 result:rstr];
                    break;
                case FTSessionStateClosedLoginFailed:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"code\": %d }", error.code];
                    [self gbClientDidComplete:104 result:rstr];
                   break;
                default:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"code\": 115 }"];
                    [self gbClientDidComplete:115 result:rstr];                    
                    break; // so we do nothing in response to those state transitions
            }
            [rstr release];
        }];
    }
    else if([url.path isEqualToString:@"/facebook.html"]) {
        [_fbsession openWithCompletionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
            NSString* rstr;
            switch (status) {
                case FBSessionStateOpen:
                    // call the legacy session delegate
                    rstr=[[NSString alloc] initWithFormat: @"{ \"provider_id\": \"%s\" ,  \"token\": \"%s\", \"uuid\": \"%s\" }","facebook",[_fbsession.accessTokenData.accessToken UTF8String],[_fbsession.parameters[@"uid"] UTF8String]];
                    [self gbClientDidComplete:100 result:rstr];
                    break;
                case FBSessionStateClosedLoginFailed:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"code\": %d }", error.code];
                    [self gbClientDidComplete:104 result:rstr];
                    break;
                default:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"code\": 115 }"];
                    [self gbClientDidComplete:115 result:rstr];
                    break; // so we do nothing in response to those state transitions
            }
            [rstr release];
        }];
    }
    else if([url.path isEqualToString:@"/gbombgames.html"]) {
        [_gbsession openWithCompletionHandler:^(GBSession *session, GBSessionState status, NSError *error) {
            NSString* rstr;
            switch (status) {
                case GBSessionStateOpen:
                    // call the legacy session delegate
                    rstr=[[NSString alloc] initWithFormat: @"{ \"provider_id\": \"%s\" ,  \"token\": \"%s\", \"uuid\": \"%s\" }","gbombgames",[_gbsession.accessTokenData.accessToken UTF8String],[_gbsession.parameters[@"uid"] UTF8String]];
                    [self gbClientDidComplete:100 result:rstr];
                    break;
                case GBSessionStateClosedLoginFailed:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"code\": %d }", error.code];
                    [self gbClientDidComplete:104 result:rstr];
                    break;
                default:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"code\": 115 }"];
                    [self gbClientDidComplete:115 result:rstr];
                    break; // so we do nothing in response to those state transitions
            }
            [rstr release];            
        }];
    }
    else {
        
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
    NSString* rstr= [NSString alloc];
    [rstr stringByAppendingFormat: @"{ \"code\": %d }", error.code];
    [self gbClientDidComplete:115 result:rstr];
    [rstr release];
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