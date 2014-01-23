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

@synthesize ftUUID = _ftUUID,funtown = _funtown;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    _ftUUID = [FTUUID getInstance:self];
    _funtown = [[Funtown alloc] init:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)generateUUID:(id)sender
{
    [_ftUUID generateUUID];
}

- (IBAction)loginLogout:(id)sender
{
    if (self.isLogined == FALSE)
    {
        [_funtown authorize:nil];
    }
    else
    {
        [_funtown logout:self];
    }
}
/**
 * Called when the UUID generated.
 */
- (void)ftDidUUIDGenerate:(NSString*)uuid
{
    self.MessageLabel.text = uuid;
}

/**
 * Called when the user successfully logged in.
 */
- (void)ftDidLogin
{
    self.isLogined = TRUE;
    self.MessageLabel.text = @"Login OK";
}

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)ftDidNotLogin:(BOOL)cancelled
{
    self.isLogined = FALSE;
    self.MessageLabel.text = @"Login Cancelled";
}

/**
 * Called when the user logged error.
 */
- (void)ftDidLoginError:(NSError *)error
{
    self.isLogined = FALSE;
    self.MessageLabel.text = [error localizedDescription];
}

/**
 * Called when the user logged out.
 */
- (void)ftDidLogout
{
    self.isLogined = FALSE;
    self.MessageLabel.text = @"Logout OK";
}


@end
