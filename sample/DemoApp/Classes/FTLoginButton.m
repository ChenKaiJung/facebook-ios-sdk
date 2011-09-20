//
//  FTLoginButton.m
//  DemoApp
//
//  Created by kaijung on 11/9/19.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "FTLoginButton.h"
#import "Funtown.h"

#import <dlfcn.h>

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation FTLoginButton

@synthesize isLoggedIn = _isLoggedIn;

///////////////////////////////////////////////////////////////////////////////////////////////////
// private

/**
 * return the regular button image according to the login status
 */
- (UIImage*)buttonImage {
    if (_isLoggedIn) {
        return [UIImage imageNamed:@"FBConnect.bundle/images/ftlogout.png"];
    } else {
        return [UIImage imageNamed:@"FBConnect.bundle/images/fLogo.png"];
    }
}

/**
 * return the highlighted button image according to the login status
 */
- (UIImage*)buttonHighlightedImage {
    if (_isLoggedIn) {
        return [UIImage imageNamed:@"FBConnect.bundle/images/LogoutPressed.png"];
    } else {
        return [UIImage imageNamed:@"FBConnect.bundle/images/LoginPressed.png"];
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// public

/**
 * To be called whenever the login status is changed
 */
- (void)updateImage {
    self.imageView.image = [self buttonImage];
    [self setImage: [self buttonImage]
          forState: UIControlStateNormal];
    
    [self setImage: [self buttonHighlightedImage]
          forState: UIControlStateHighlighted |UIControlStateSelected];
    
}

@end
