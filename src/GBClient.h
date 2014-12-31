//
//  GBClient.h
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/12.
//
//
#import <Foundation/Foundation.h>

@class GBSession;
@class FBSession;
@class FTSession;
@class GDialog;

@protocol GBClientDelegate;

@interface GBClient : NSObject

- (id)initWithGameId : (NSString*) gameId;
- (void)login;
- (void)callService : (NSString*)characterProfile;
- (void)getProductList : (NSString*)characterProfile;
- (void)purchase : (NSString*) cid serverId:(NSString*) server
        itemId : (NSString*) item onSalesId: (NSString*) onsalesId
     providerId: (NSString*) providerId characterProfile: (NSString*)characterProfile
          token: (NSString*) token;

- (void)subPush : (NSString*) regid;
- (void)unsubPush : (NSString*) regid;

- (void)getUserProfile:(NSString *) provider_id token:(NSString *)token ;

- (NSString *) getStringFromUrl: (NSString*) url needle:(NSString *) needle;
- (void)trackingInstalled;

- (void)gbClientDidComplete:(NSInteger) code result:(NSString *)json;
- (void)gbClientDidNotComplete:(NSInteger) code result:(NSString *)json;
- (void)gbClientDidFailWithError:(NSError *)error;


@property (nonatomic, assign) id<GBClientDelegate> delegate;
@property(readonly) FTSession *ftsession;
@property(readonly) FBSession *fbsession;
@property(readonly) GBSession *gbsession;
@property(readonly) GDialog *gdialog;
//@property(readonly) NSString *gUrl;
@property(readonly) NSURLConnection *connection;
@property(readonly) NSMutableData *responseData;
@property(readonly) NSURLResponse *response;
@property(readonly) NSInteger statusCode;
@property(readonly) NSString *gameId;
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