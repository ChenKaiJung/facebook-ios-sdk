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
#import "GBDeviceId.h"

static NSString *const GBFreeTrialDialogMethod = @"create.php";

@interface FTSession () <GBDeviceIdDelegate, FTDialogDelegate> {
@protected
    // public-property ivars
    NSString *_urlSchemeSuffix;
    
    // private property and non-property ivars
}

@property (readwrite) FTSessionState state;
@property (readwrite, retain) FTDialog *freeTrialDialog;
@property (readwrite, copy) NSString *token;
@property (readwrite, copy) NSString *uid;
@property (readwrite, copy) NSDictionary *parameters;
@property (readwrite, copy) NSString *redirectUri;
@property (readwrite, copy) FTSessionStateHandler handler;
@end

@implementation FTSession : NSObject



- (id)init {
    self = [super init];
    
    _state = FTSessionStateCreated;
    return self;
}

- (void)dealloc {

    [super dealloc];
    [_handler release];
}

- (void)openWithCompletionHandler:(FTSessionStateHandler)handler {
    
    NSString *freeTrialDialogURL = [[GBUtility sdkBaseURL] stringByAppendingString:GBFreeTrialDialogMethod];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];

    GBDeviceId *gdid=[GBDeviceId getInstance:self];
    NSString *gdidstr=[gdid getDeviceId];
    NSString *systemVer=[GBUtility getSystemVersion];
    NSString *systemName=[GBUtility getSystemName];
    NSString *systemModel=[GBUtility getSystemModel];
    [params setObject:@"trial" forKey:@"provider_id"];
    [params setObject:gdidstr forKey:@"device_id"];
    [params setObject:systemVer forKey:@"os_sdk_version"];
    [params setObject:systemName forKey:@"os"];
    [params setObject:systemModel forKey:@"device_model"];
    
    if (handler != nil) {
        self.handler = handler;
    }
    
    
    // open an inline login dialog. This will require the user to enter his or her credentials.
    self.freeTrialDialog = [[[FTDialog alloc]
                             initWithURL:freeTrialDialogURL params:params isViewInvisible:NO delegate:self]
                            autorelease];
    [self.freeTrialDialog show];
}


/**
 * Called when the dialog succeeds and is about to be dismissed.
 */
- (void)dialogDidComplete:(FTDialog *)dialog
{
    
}

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

/**
 * Called when the dialog succeeds with a returning url.
 */
- (void)dialogCompleteWithUrl:(NSURL *)url
{
    NSString *q = [url absoluteString];
    NSString *token = [self getStringFromUrl:q needle:@"token="];
    NSString *uid = [self getStringFromUrl:q needle:@"uid="];
    
#ifdef DEBUG
    //NSLog(@"dialogDidSucceed : sessionkey = %@, accessToken = %@",session_key, access_token);
#endif
    
    if(token != nil){
        self.token=token;
    }
    if(uid != nil){
        self.uid=uid;
    }
    
    _state=FTSessionStateOpen;
    
    FTSessionStateHandler handler = [self.handler retain];
    
    self.handler(self,
             self.state,
             nil);
}

/**
 * Called when the dialog get canceled by the user.
 */
- (void)dialogDidNotCompleteWithUrl:(NSURL *)url
{
    if(url)
    {
        _state=FTSessionStateClosedLoginFailed;        
        self.handler(self,
                     self.state,
                     nil);
    }
    
    NSString *q = [url absoluteString];
    NSString * error = [self getStringFromUrl:[url absoluteString] needle:@"error="];
    NSString * errorCode = [self getStringFromUrl:[url absoluteString] needle:@"error_code="];
    NSString * errorDes = [self getStringFromUrl:[url absoluteString] needle:@"error_description="];
    NSDictionary * errorData = [NSDictionary dictionaryWithObject:errorDes forKey:@"error_description"];
    _state=FTSessionStateClosedLoginFailed;
 
    NSError * nserror = [NSError errorWithDomain:@"FreeTrialErrDomain"
                                          code:[errorCode intValue]
                                      userInfo:errorData];
    
    self.handler(self,
            self.state,
            nserror);
}

/**
 * Called when the dialog is cancelled and is about to be dismissed.
 */
- (void)dialogDidNotComplete:(FTDialog *)dialog
{
    _state=FTSessionStateClosedLoginFailed;
    
    self.handler(self,
            self.state,
            nil);
}

/**
 * Called when dialog failed to load due to an error.
 */
- (void)dialog:(FTDialog*)dialog didFailWithError:(NSError *)error
{

    
    _state=FTSessionStateClosedLoginFailed;
    self.handler(self,
            self.state,
            error);
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
- (BOOL)dialog:(FTDialog*)dialog shouldOpenURLInExternalBrowser:(NSURL *)url
{
    
}




@end
