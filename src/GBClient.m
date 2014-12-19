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
#import "GBDeviceId.h"

static NSString *const GDialogMethod = @"index.php";
static NSString *const CallServiceMethod = @"call_service.php";
static NSString* GB_API_SERVICE_URL   = @"http://api.gbombgames.com/";
static const NSTimeInterval TIMEOUT = 180.0;
static NSString* USER_AGENT = @"GBomb";



@interface GBClient () <NSURLConnectionDelegate,GDialogDelegate,GBDeviceIdDelegate> {
    id<GBClientDelegate> _delegate;
    GBSession* _gbsession;
    FTSession* _ftsession;
    FBSession* _fbsession;
    GDialog * _gdialog;
    NSURLConnection *_connection;
    NSMutableData *_responseData;
    NSURLResponse *_response;
}
@end

@implementation GBClient {

}

@synthesize delegate = _delegate,
            gbsession= _gbsession,
            ftsession=_ftsession,
            fbsession=_fbsession,
            gdialog=_gdialog,
            connection=_connection,
            responseData=_responseData,
            response=_response,
            statusCode=_statusCode;

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
    [self trackingInstalled];
    
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
    
    GBDeviceId *gdid=[GBDeviceId getInstance:self];
    NSString *gdidstr=[gdid getDeviceId];
    NSString *systemVer=[GBUtility getSystemVersion];
    NSString *systemName=[GBUtility getSystemName];
    NSString *systemModel=[GBUtility getSystemModel];
    //[params setObject:@"FreeTrial" forKey:@"provider_id"];
    [params setObject:gdidstr forKey:@"device_id"];
    [params setObject:systemVer forKey:@"os_version"];
    [params setObject:systemName forKey:@"os"];
    [params setObject:systemModel forKey:@"device_model"];
    [params setObject:@"mobile" forKey:@"view"];
    
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
    _response=response;
    _statusCode=(NSInteger)[(NSHTTPURLResponse *)_response statusCode];
    [_responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString* path=[[[connection originalRequest] URL] path];

    if( _statusCode != 200) {
        NSString* rstr= [[NSString alloc] stringByAppendingFormat: @"{ \"status\": \"error\", \"data\": { \"status_code\": %d } }",[(NSHTTPURLResponse *)_response statusCode]];
        [self gbClientDidComplete:115 result:rstr];
        [rstr release];
    }
    
    if([path isEqualToString:@"/v1/profile.php"] ) {
        
        NSString* jstr= [[NSString alloc] initWithData:_responseData   encoding:NSUTF8StringEncoding];
        NSDictionary *dict = [GBUtility simpleJSONDecode:jstr];
        [jstr release];
        
        NSString* rstr;
        if (![dict isKindOfClass:[NSDictionary class]]) {
            rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"status_code\": %d } }"
                  ,[(NSHTTPURLResponse *)_response statusCode]];
            [self gbClientDidComplete:115 result:rstr];
            [rstr release];
            [connection release];
            return;
        }
        if([(NSString *)[dict objectForKey:@"provider_id"] isEqualToString: @"FreeTrial"]) {
            NSString* uid=[dict objectForKey:@"uid"];
            NSString* token=self.ftsession.token;
            NSString* provider_id=[dict objectForKey:@"provider_id"];
            
            rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"success\", \"data\": { \"uid\": \"%s\", \"token\": \"%s\" , \"user_id\":null,\"expires\":\"100000000\",\"provider_id\":\"%s\" } }"
                  ,[uid UTF8String], [token UTF8String], [provider_id UTF8String] ];
            [self gbClientDidComplete:100 result:rstr];
        }
        else if([(NSString *)[dict objectForKey:@"provider_id"] isEqualToString: @"Facebook"]) {
            NSString* uid=[dict objectForKey:@"uid"];
            NSString* token=self.fbsession.accessTokenData.accessToken;
            NSString* provider_id=[dict objectForKey:@"provider_id"];
            NSString* user_id=[dict objectForKey:@"id"];
            
            rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"success\", \"data\": { \"uid\": \"%s\", \"token\": \"%s\" , \"user_id\":\"%s\",\"expires\":\"100000000\",\"provider_id\":\"%s\" } }"
                  ,[uid UTF8String], [token UTF8String], [user_id UTF8String], [provider_id UTF8String] ];
           [self gbClientDidComplete:100 result:rstr];
        }
        else if([(NSString *)[dict objectForKey:@"provider_id"] isEqualToString: @"Gbomb"]) {
            NSString* uid=[dict objectForKey:@"uid"];
            NSString* token=self.fbsession.accessTokenData.accessToken;
            NSString* provider_id=[dict objectForKey:@"provider_id"];
            NSString* user_id=[dict objectForKey:@"id"];
            
            rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"success\", \"data\": { \"uid\": \"%s\", \"token\": \"%s\" , \"user_id\":\"%s\",\"expires\":\"100000000\",\"provider_id\":\"%s\" } }"
                  ,[uid UTF8String], [token UTF8String],  [user_id UTF8String],  [provider_id UTF8String] ];
            [self gbClientDidComplete:100 result:rstr];
        }
        else {
            rstr=@"{ \"status\": \"error\", \"data\": { \"status_code\": 115 } }";
            [self gbClientDidComplete:115 result:rstr];
        }
        [rstr release];
        [connection release];
    }
    else  {
        NSString* rstr= [[NSString alloc] initWithData:_responseData   encoding:NSUTF8StringEncoding];
        [self gbClientDidComplete:100 result:rstr];
        [rstr release];
        [connection release];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSString* rstr= [NSString alloc];
    NSString* path=[[[connection originalRequest] URL] path];
    
    if([path isEqualToString:@"/v1/tracking_installed.php"] ) {
       [rstr release];
        return;
    }
    
        [rstr initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\":%d , \"status_code\": %d } }",
     error.code,
         (NSInteger)[(NSHTTPURLResponse *)_response statusCode]];

    [self gbClientDidNotComplete:115 result:rstr];
    [rstr release];
}


- (void)trackingInstalled  {
    
    NSString *bundle=[GBUtility stringByURLEncodingString:[[NSBundle mainBundle] bundleIdentifier]];
    NSString *systemName=[GBUtility stringByURLEncodingString:[GBUtility getSystemName]];
    NSString *systemVer=[GBUtility stringByURLEncodingString:[GBUtility getSystemVersion]];
    NSString* uri=[[[[[[GB_API_SERVICE_URL stringByAppendingString:@"v1/tracking_installed.php?os="]
                       stringByAppendingString:systemName]
                      stringByAppendingString:@"&version="]
                     stringByAppendingString:systemVer]
                    stringByAppendingString:@"&package_name="]
                   stringByAppendingString:bundle];
    
    
    NSMutableURLRequest* request =
    [NSMutableURLRequest requestWithURL:[NSURL URLWithString:uri]
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:TIMEOUT];
    
    _responseData = [[NSMutableData data] retain];
    
    
    [request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    
    [request setHTTPMethod:@"GET"];
    
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)getUserProfile:(NSString *) provider_id token:(NSString *)token {
    
    NSString* api = @"v1/profile.php";
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
    
    _responseData = [[NSMutableData data] retain];
    
    
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
        if (!(_ftsession.state == FTSessionStateCreated ||
              _ftsession.state == FTSessionStateCreatedTokenLoaded)) {
            [self getUserProfile:@"FreeTrial" token:_ftsession.token];
            return;
        }
        [_ftsession openWithCompletionHandler:^(FTSession *session, FTSessionState status, NSError *error) {
            NSString* rstr = nil;
            switch (status) {
                case FTSessionStateOpen:
                    
                    [self getUserProfile:@"FreeTrial" token:_ftsession.token];
                    break;
                case FTSessionStateClosedLoginFailed:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\": %d } }", error.code];
                    [self gbClientDidComplete:104 result:rstr];
                   break;
                default:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\": 115 } }"];
                    [self gbClientDidComplete:115 result:rstr];                    
                    break; // so we do nothing in response to those state transitions
            }
            if(rstr != nil) [rstr release];
        }];
    }
    else if([url.path isEqualToString:@"/facebook.html"]) {
        if (!(_fbsession.state == FBSessionStateCreated ||
            _fbsession.state == FBSessionStateCreatedTokenLoaded)) {
            [self getUserProfile:@"Facebook" token:_fbsession.accessTokenData.accessToken];
            return;
        }
        [_fbsession openWithCompletionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
            NSString* rstr=nil;
            switch (status) {
                case FBSessionStateOpen:
                    [self getUserProfile:@"Facebook" token:_fbsession.accessTokenData.accessToken];
                    break;
                case FBSessionStateClosedLoginFailed:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\": %d } }", error.code];
                    [self gbClientDidComplete:104 result:rstr];
                    break;
                default:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\": 115 } }"];
                    [self gbClientDidComplete:115 result:rstr];
                    break; // so we do nothing in response to those state transitions
            }
            if(rstr != nil) [rstr release];
        }];
    }
    else if([url.path isEqualToString:@"/gbomb.html"]) {
        if (!(_gbsession.state == GBSessionStateCreated ||
            _gbsession.state == GBSessionStateCreatedTokenLoaded)) {
            [self getUserProfile:@"Gbomb" token:_gbsession.accessTokenData.accessToken];
            return;
        }
        [_gbsession openWithCompletionHandler:^(GBSession *session, GBSessionState status, NSError *error) {
            NSString* rstr=nil;
            switch (status) {
                case GBSessionStateOpen:
                    [self getUserProfile:@"Gbomb" token:_gbsession.accessTokenData.accessToken];
                    break;
                case GBSessionStateClosedLoginFailed:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\": %d } }", error.code];
                    [self gbClientDidComplete:104 result:rstr];
                    break;
                default:
                    rstr=[[NSString alloc] initWithFormat: @"{ \"status\": \"error\", \"data\": { \"error_code\": 115 } }"];
                    [self gbClientDidComplete:115 result:rstr];
                    break; // so we do nothing in response to those state transitions
            }
            if(rstr != nil) [rstr release];
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
    [rstr stringByAppendingFormat:  @"{ \"status\": \"error\", \"data\": { \"error_code\": %d } }", error.code];
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
    return FALSE;
}


@end