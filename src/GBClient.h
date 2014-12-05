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
@class GDialog;

@protocol GBClientDelegate;
@protocol GDialogDelegate;

@interface GBClient : NSObject <NSURLConnectionDelegate,GDialogDelegate>  {
    id<GBClientDelegate> _delegate;
    GBSession* _gbsession;
    FTSession* _ftsession;
    FBSession* _fbsession;
    GDialog * _gdialog;
    
}


- (id)initWithGameId : (NSString*) gameId delegate:  (id <GBClientDelegate>) delegate;
- (void)login;
- (void)callService : (NSString*)characterProfile;
- (void)getProductList : (NSString*)characterProfile;
- (void)purchase : (NSString*) cid serverId:(NSString*) server
        itemId : (NSString*) item onSalesId: (NSString*) onsalesId
     providerId: (NSString*) providerId characterProfile: (NSString*)characterProfile
          token: (NSString*) token;

- (void)subPush : (NSString*) regid;
- (void)unsubPush : (NSString*) regid;

- (NSString *) getStringFromUrl: (NSString*) url needle:(NSString *) needle;

- (void)GBClientDidComplete:(NSInteger) code result:(NSString *)json;
- (void)GBClientDidNotComplete:(NSInteger) code result:(NSString *)json;
- (void)GBClientDidFailWithError:(NSError *)error;

@property (nonatomic, assign) id<GBClientDelegate> delegate;
@property(readonly) FTSession *ftsession;
@property(readonly) FBSession *fbsession;
@property(readonly) GBSession *gbsession;
@property(readonly) GDialog *gdialog;

@end

@protocol GBClientDelegate <NSObject>

@required

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