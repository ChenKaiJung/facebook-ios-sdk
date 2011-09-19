//
//  FTLoginButton.h
//  DemoApp
//
//  Created by kaijung on 11/9/19.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//


@interface FTLoginButton :  UIButton {
    BOOL  _isLoggedIn;
}

@property(nonatomic) BOOL isLoggedIn; 

- (void) updateImage;

@end

