//
//  ViewController.m
//  DemoApp
//
//  Created by kaijung on 2014/1/23.
//  Copyright (c) 2014年 kaijung. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize gbomb = _gbomb;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    _gbomb = [[Gbomb alloc] initWithAppId: @"129645243823370" andDelegate:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)freeTrial:(id)sender
{

}

- (IBAction)loginLogout:(id)sender
{
    if (self.isLogined == FALSE)
    {
        [_gbomb authorize:nil];
    }
    else
    {
        [_gbomb logout:self];
    }
}
/**
 * Called when the UUID generated.
 */
- (void)gbDidUUIDGenerate:(NSString*)uuid
{
    self.MessageLabel.text = uuid;
}

/**
 * Called when the user successfully logged in.
 */
- (void)gbDidLogin
{
    self.isLogined = TRUE;
    self.MessageLabel.text = @"Login OK";
}

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)gbDidNotLogin:(BOOL)cancelled
{
    self.isLogined = FALSE;
    self.MessageLabel.text = @"Login Cancelled";
}

/**
 * Called when the user logged error.
 */
- (void)gbDidLoginError:(NSError *)error
{
    self.isLogined = FALSE;
    self.MessageLabel.text = [error localizedDescription];
}

/**
 * Called when the user logged out.
 */
- (void)gbDidLogout
{
    self.isLogined = FALSE;
    self.MessageLabel.text = @"Logout OK";
}


@end
