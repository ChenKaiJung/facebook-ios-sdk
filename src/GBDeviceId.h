//
//  GBUUID.h
//  facebook-ios-sdk
//
//  FTUUID.h
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/1/23.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol GBDeviceIdDelegate;

@interface GBDeviceId : NSObject {
    id<GBDeviceIdDelegate> _deviceIdDelegate;
}

@property(nonatomic, assign) id<GBDeviceIdDelegate> deviceIdDelegate;

+ (id)getInstance:(id<GBDeviceIdDelegate>)delegate;

- (void)generateDeviceId;
- (NSString *)getDeviceId;

@end


@protocol GBDeviceIdDelegate <NSObject>

@optional
- (void)gbDidDeviceIdGenerate:(NSString*)deviceId;

@end

