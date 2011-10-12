/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#import "DemoAppViewController.h"
#import "FBConnect.h"

// Your Facebook APP Id must be set before running this example
// See http://www.facebook.com/developers/createapp.php
// Also, your application must bind to the fb[app_id]:// URL
// scheme (substitute [app_id] for your real Facebook app id).
static NSString* kAppId = @"246490885388325";
static NSString* kCkientId = @"2";
@implementation DemoAppViewController

@synthesize label = _label, facebook = _facebook, funtown = _funtown, isFacebookLogin=_isFacebookLogin;

//////////////////////////////////////////////////////////////////////////////////////////////////
// UIViewController

/**
 * initialization
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  if (!kAppId) {
    NSLog(@"missing app id!");
    exit(1);
    return nil;
  }


  if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    _permissions =  [[NSArray arrayWithObjects:
                      @"read_stream", @"publish_stream", @"offline_access",nil] retain];
    _facebook = [[Facebook alloc] initWithAppId:kAppId
                                    andDelegate:self];

    _funtown = [[Funtown alloc] initWithAppId:kCkientId
                                      andDelegate:self];      
  }
  _isFacebookLogin = true;
  return self;
}

/**
 * Set initial view
 */
- (void)viewDidLoad {
  [self.label setText:@"Please log in"];
  _getUserInfoButton.hidden = YES;
  _getPublicInfoButton.hidden = YES;
  _publishButton.hidden = YES;
  _uploadPhotoButton.hidden = YES;
  _fbButton.isLoggedIn = NO;
  _ftButton.isLoggedIn = NO;    
  [_fbButton updateImage];
  [_ftButton updateImage];    
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (void)dealloc {
  [_label release];
  [_fbButton release];
  [_getUserInfoButton release];
  [_getPublicInfoButton release];
  [_publishButton release];
  [_uploadPhotoButton release];
  [_facebook release];
  [_permissions release];
  [_ftButton release]; 
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

/**
 * Show the authorization dialog.
 */
- (void)login {
  [_facebook authorize:_permissions];
}

/**
 * Invalidate the access token and clear the cookie.
 */
- (void)logout {
  [_facebook logout:self];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// IBAction

/**
 * Called on a login/logout button click.
 */
- (IBAction)fbButtonClick:(id)sender {
   _isFacebookLogin = true;    
  if (_fbButton.isLoggedIn) {
    [self logout];
  } else {
    [self login];
  }
}

/**
 * Make a Graph API Call to get information about the current logged in user.
 */
- (IBAction)getUserInfo:(id)sender {
  [_facebook requestWithGraphPath:@"me" andDelegate:self];
}


/**
 * Make a REST API call to get a user's name using FQL.
 */
- (IBAction)getPublicInfo:(id)sender {
  NSMutableDictionary * params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  @"SELECT uid,name FROM user WHERE uid=4", @"query",
                                  nil];
  [_facebook requestWithMethodName:@"fql.query"
                         andParams:params
                     andHttpMethod:@"POST"
                       andDelegate:self];
}

/**
 * Open an inline dialog that allows the logged in user to publish a story to his or
 * her wall.
 */
- (IBAction)publishStream:(id)sender {

  SBJSON *jsonWriter = [[SBJSON new] autorelease];

  NSDictionary* actionLinks = [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
                               @"Always Running",@"text",@"http://itsti.me/",@"href", nil], nil];

  NSString *actionLinksStr = [jsonWriter stringWithObject:actionLinks];
  NSDictionary* attachment = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"a long run", @"name",
                               @"The Facebook Running app", @"caption",
                               @"it is fun", @"description",
                               @"http://itsti.me/", @"href", nil];
  NSString *attachmentStr = [jsonWriter stringWithObject:attachment];
  NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 @"Share on Facebook",  @"user_message_prompt",
                                 actionLinksStr, @"action_links",
                                 attachmentStr, @"attachment",
                                 nil];


  [_facebook dialog:@"feed"
          andParams:params
        andDelegate:self];
}

/**
 * Upload a photo.
 */
- (IBAction)uploadPhoto:(id)sender {
  NSString *path = @"http://www.facebook.com/images/devsite/iphone_connect_btn.jpg";
  NSURL *url = [NSURL URLWithString:path];
  NSData *data = [NSData dataWithContentsOfURL:url];
  UIImage *img  = [[UIImage alloc] initWithData:data];

  NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 img, @"picture",
                                 nil];

  [_facebook requestWithGraphPath:@"me/photos"
                        andParams:params
                        andHttpMethod:@"POST"
                        andDelegate:self];

  [img release];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// private

/**
 * Show the authorization dialog.
 */
- (void)ftLogin {
    [_funtown authorize:_permissions];
}

/**
 * Invalidate the access token and clear the cookie.
 */
- (void)ftLogout {
    [_funtown logout:self];
}

/**
 * Called on a login/logout button click.
 */
- (IBAction)ftButtonClick:(id)sender {
    _isFacebookLogin = false;
    if (_ftButton.isLoggedIn) {
        [self ftLogout];
    } else {
        [self ftLogin];
    }
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}


/**
 * Called when the user has logged in successfully.
 */
- (void)fbDidLogin {
  [self.label setText:@"logged in"];
  _getUserInfoButton.hidden = NO;
  _getPublicInfoButton.hidden = NO;
  _publishButton.hidden = NO;
  _uploadPhotoButton.hidden = NO;
  _fbButton.isLoggedIn = YES;
  [_fbButton updateImage];   
}

/**
 * Called when the user canceled the authorization dialog.
 */
-(void)fbDidNotLogin:(BOOL)cancelled {
  NSLog(@"did not login");
}

/**
 * Called when the request logout has succeeded.
 */
- (void)fbDidLogout {
  [self.label setText:@"Please log in"];
  _getUserInfoButton.hidden    = YES;
  _getPublicInfoButton.hidden   = YES;
  _publishButton.hidden        = YES;
  _uploadPhotoButton.hidden = YES;
   _fbButton.isLoggedIn         = NO;
  [_fbButton updateImage];    
}

/**
 * Called when the user has logged in successfully.
 */
- (void)ftDidLogin {
    [self.label setText:@"logged in"];
    _getUserInfoButton.hidden = YES;
    _getPublicInfoButton.hidden = YES;
    _publishButton.hidden = YES;
    _uploadPhotoButton.hidden = YES;
//    _fbButton.isLoggedIn = YES;
    [_fbButton updateImage];
    _ftButton.isLoggedIn = YES;
    [_ftButton updateImage];    
}

/**
 * Called when the user canceled the authorization dialog.
 */
-(void)ftDidNotLogin:(BOOL)cancelled {
    NSLog(@"did not login");
}

/**
 * Called when authorization error.
 */
- (void)ftDidLoginError:(NSError *)error {
    NSLog(@"login error");
}

/**
 * Called when the request logout has succeeded.
 */
- (void)ftDidLogout {
    [self.label setText:@"Please log in"];
    _getUserInfoButton.hidden    = YES;
    _getPublicInfoButton.hidden   = YES;
    _publishButton.hidden        = YES;
    _uploadPhotoButton.hidden = YES;
    _ftButton.isLoggedIn         = NO;
    [_ftButton updateImage];    
}
////////////////////////////////////////////////////////////////////////////////
// FBRequestDelegate

/**
 * Called when the Facebook API request has returned a response. This callback
 * gives you access to the raw response. It's called before
 * (void)request:(FBRequest *)request didLoad:(id)result,
 * which is passed the parsed response object.
 */
- (void)request:(FBRequest *)request didReceiveResponse:(NSURLResponse *)response {
  NSLog(@"received response");
}

/**
 * Called when a request returns and its response has been parsed into
 * an object. The resulting object may be a dictionary, an array, a string,
 * or a number, depending on the format of the API response. If you need access
 * to the raw response, use:
 *
 * (void)request:(FBRequest *)request
 *      didReceiveResponse:(NSURLResponse *)response
 */
- (void)request:(FBRequest *)request didLoad:(id)result {
  if ([result isKindOfClass:[NSArray class]]) {
    result = [result objectAtIndex:0];
  }
  if ([result objectForKey:@"owner"]) {
    [self.label setText:@"Photo upload Success"];
  } else {
    [self.label setText:[result objectForKey:@"name"]];
  }
};

/**
 * Called when an error prevents the Facebook API request from completing
 * successfully.
 */
- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {
  [self.label setText:[error localizedDescription]];
};


////////////////////////////////////////////////////////////////////////////////
// FBDialogDelegate

/**
 * Called when a UIServer Dialog successfully return.
 */
- (void)dialogDidComplete:(FBDialog *)dialog {
  [self.label setText:@"publish successfully"];
}

@end
