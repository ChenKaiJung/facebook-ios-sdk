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
    
}

- (id)callService {
    
}

- (id)getProductList {
    
}

- (id)purchase : (NSString*) cid serverId:(NSString*) server
        itemId : (NSString*) item onSalesId: (NSString*) onsalesId
     providerId: (NSString*) providerId characterProfile : (NSString*)characterProfile
          token: (NSString*) token {
    
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


@end