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

@protocol GBUUIDDelegate;

@interface GBUUID : NSObject {
    id<GBUUIDDelegate> _uuidDelegate;
}

@property(nonatomic, assign) id<GBUUIDDelegate> uuidDelegate;

+ (id)getInstance:(id<GBUUIDDelegate>)delegate;

- (void)generateUUID;
- (NSString *)getUUID;

@end


@protocol GBUUIDDelegate <NSObject>

@optional
- (void)gbDidUUIDGenerate:(NSString*)uuid;

@end

