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
        itemID : (NSString*) item onSalesId: (NSString*) onsalesId
     providerID: (NSString*) providerId
          token: (NSString*) token {
    
}

- (id)subPush : (NSString*) regid {
    
}

- (id)unsubPush : (NSString*) regid {
    
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

@end