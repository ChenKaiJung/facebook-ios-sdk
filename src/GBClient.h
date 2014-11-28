//
//  GBClient.h
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/12.
//
//
@protocol GBClientDelegate;

@interface GBClient : NSObject {
    id<GBClientDelegate> _delegate;
    GBSession * _gbsession;
    FBSession * _fbsession;
    FTSession * _ftsession;
}

@property (nonatomic, assign) id<GBClientDelegate> delegate;

- (id)initWithGameId : (NSString*) gameId;
- (id)login;
- (id)callService;
- (id)getProductList;
- (id)purchase : (NSString*) cid serverId:(NSString*) server
        itemID : (NSString*) item onSalesId: (NSString*) onsalesId
     providerID: (NSString*) providerId
          token: (NSString*) token;

- (id)subPush : (NSString*) regid;
- (id)unsubPush : (NSString*) regid;

- (void)GBClientDidComplete:(NSInteger) code result:(NSString *)json;
- (void)GBClientDidNotComplete:(NSInteger) code result:(NSString *)json;
- (void)GBClientDidFailWithError:(NSError *)error;
@end

@protocol GBClientDelegate <NSObject>

@optional

/**
 * Called when the dialog succeeds and is about to be dismissed.
 */
- (void)didComplete:(NSInteger) code result:(NSString *)json;

/**
 * Called when the dialog succeeds with a returning url.
 */
- (void)didNotComplete:(NSInteger) code result:(NSString *)json;

/**
 * Called when dialog failed to load due to an error.
 */
- (void)didFailWithError:(NSError *)error;
@end