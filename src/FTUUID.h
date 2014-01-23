//
//  FTUUID.h
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/1/23.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol FTUUIDDelegate;

@interface FTUUID : NSObject {
  id<FTUUIDDelegate> _uuidDelegate;
}

@property(nonatomic, assign) id<FTUUIDDelegate> uuidDelegate;

+ (id)getInstance:(id<FTUUIDDelegate>)delegate;

- (void)generateUUID;

@end


@protocol FTUUIDDelegate <NSObject>

@optional
- (void)ftDidUUIDGenerate:(NSString*)uuid;

@end