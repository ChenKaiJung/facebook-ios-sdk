//
//  GBClient.h
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/12.
//
//
@class GBSession;
@class FBSession;
@class FTSession;

@protocol GBClientDelegate;

@interface GBClient : NSObject <NSURLConnectionDelegate,GDialogDelegate>  {
    id<GBClientDelegate> _delegate;
    GBSession * _gbsession;
    FBSession * _fbsession;
    FTSession * _ftsession;
    GDialog * _gdialog;
}

@property (nonatomic, assign) id<GBClientDelegate> delegate;

- (id)initWithGameId : (NSString*) gameId;
- (id)login;
- (id)callService : (NSString*)characterProfile;
- (id)getProductList : (NSString*)characterProfile;
- (id)purchase : (NSString*) cid serverId:(NSString*) server
        itemId : (NSString*) item onSalesId: (NSString*) onsalesId
     providerId: (NSString*) providerId characterProfile: (NSString*)characterProfile
          token: (NSString*) token;

- (id)subPush : (NSString*) regid;
- (id)unsubPush : (NSString*) regid;

- (NSString *) getStringFromUrl: (NSString*) url needle:(NSString *) needle;

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