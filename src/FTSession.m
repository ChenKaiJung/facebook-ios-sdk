//
//  FTSession.m
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/7.
//
//

#import "FTSession.h"
#import "GBUtility.h"
#import "FTDialog.h"


static NSString *const GBFreeTrialDialogMethod = @"create.php";

@interface FTSession () <FTDialogDelegate> {
@protected
    // public-property ivars
    NSString *_urlSchemeSuffix;
    
    // private property and non-property ivars
}

@property (readwrite, retain) FTDialog *freeTrialDialog;
@property (readwrite, copy) NSString *accessToken;
@property (readwrite, copy) NSDate *expirationDate;
@property (readwrite, copy) NSArray *permissions;
@property (readwrite, copy) NSString *code;
@property (readwrite, copy) NSDictionary *parameters;
@property (readwrite, copy) NSString *redirectUri;
@end

@implementation FTSession : NSObject



- (id)init {
    self = [super init];
    return self;
}

- (void)dealloc {

    [super dealloc];
}

- (void)openWithCompletionHandler:(FTSessionStateHandler)handler {
    
    NSString *freeTrialDialogURL = [[GBUtility sdkBaseURL] stringByAppendingString:GBFreeTrialDialogMethod];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"trial" forKey:@"provider"];
    
    // open an inline login dialog. This will require the user to enter his or her credentials.
    self.freeTrialDialog = [[[FTDialog alloc]
                             initWithURL:freeTrialDialogURL params:params isViewInvisible:NO delegate:self]
                            autorelease];
    [self.freeTrialDialog show];
}


/**
 * Override GBDialog : to call when the webView Dialog did succeed
 */
- (void) dialogDidSucceed:(NSURL*)url {
    
    NSString *q = [url absoluteString];
    NSString *token = [self getStringFromUrl:q needle:@"access_token="];
    NSString *expTime = [self getStringFromUrl:q needle:@"expires_in="];
    NSDate *expirationDate =nil;
    NSString *code = [self getStringFromUrl:q needle:@"code="];
    
#ifdef DEBUG
    //NSLog(@"dialogDidSucceed : sessionkey = %@, accessToken = %@",session_key, access_token);
#endif
    
    if (expTime != nil) {
        int expVal = [expTime intValue];
        if (expVal == 0) {
            expirationDate = [NSDate distantFuture];
        } else {
            expirationDate = [NSDate dateWithTimeIntervalSinceNow:expVal];
        }
    }
    
    if (((code == (NSString *) [NSNull null]) || (code.length == 0))
        && ((token == (NSString *) [NSNull null]) || (token.length == 0))) {
        [self dialogDidCancel:url];

    }
    
    if(token != nil){
        self.accessToken=token;
    }
    if(code != nil){
        self.code=code;
    }
    if(expTime != nil){
        self.expirationDate =expirationDate;
    }
}

/**
 * Override GBDialog : to call with the login dialog get canceled
 */
- (void)dialogDidCancel:(NSURL *)url {

}


- (void)dismissWithError:(NSError*)error animated:(BOOL)animated {
    

}



@end
