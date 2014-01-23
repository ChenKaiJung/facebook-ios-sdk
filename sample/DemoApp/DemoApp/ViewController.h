//
//  ViewController.h
//  DemoApp
//
//  Created by kaijung on 2014/1/23.
//  Copyright (c) 2014年 kaijung. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FTUUID.h"
#import "Funtown.h"

@interface ViewController : UIViewController <FTUUIDDelegate,FTSessionDelegate> {
    FTUUID * _ftUUID;
    Funtown * _funtown;
    BOOL _isLogined;
}

@property(readonly) FTUUID *ftUUID;
@property(readonly) Funtown *funtown;
@property(nonatomic) BOOL isLogined;
@property (strong, nonatomic) IBOutlet UILabel *MessageLabel;

- (IBAction)generateUUID:(id)sender;
- (IBAction)loginLogout:(id)sender;

@end

