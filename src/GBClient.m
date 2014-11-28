//
//  GBClient.m
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/11.
//
//

#import <Foundation/Foundation.h>
#import "GBClient.h"

@implementation GBClient {

}

@synthesize delegate = _delegate;

- (id)initWithGameId : (NSString*) gameId {
    
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