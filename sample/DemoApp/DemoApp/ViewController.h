//
//  ViewController.h
//  DemoApp
//
//  Created by kaijung on 2014/1/23.
//  Copyright (c) 2014年 kaijung. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Gbomb.h"

@interface ViewController : UIViewController <GBSessionDelegate> {
    Gbomb * _gbomb;
    BOOL _isLogined;
}

@property(readonly) Gbomb *gbomb;
@property(nonatomic) BOOL isLogined;
@property (strong, nonatomic) IBOutlet UILabel *MessageLabel;

- (IBAction)freeTrial:(id)sender;
- (IBAction)loginLogout:(id)sender;

@end

