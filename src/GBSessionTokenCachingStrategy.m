/*
 * Copyright 2010-present Facebook.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "GBSessionTokenCachingStrategy.h"

#import "GBAccessTokenData+Internal.h"

// const strings
static NSString *const GBAccessTokenInformationKeyName = @"GBAccessTokenInformationKey";

NSString *const GBTokenInformationTokenKey = @"com.facebook.sdk:TokenInformationTokenKey";
NSString *const GBTokenInformationExpirationDateKey = @"com.facebook.sdk:TokenInformationExpirationDateKey";
NSString *const GBTokenInformationRefreshDateKey = @"com.facebook.sdk:TokenInformationRefreshDateKey";
NSString *const GBTokenInformationUserGBIDKey = @"com.facebook.sdk:TokenInformationUserGBIDKey";
NSString *const GBTokenInformationIsFacebookLoginKey = @"com.facebook.sdk:TokenInformationIsFacebookLoginKey";
NSString *const GBTokenInformationLoginTypeLoginKey = @"com.facebook.sdk:TokenInformationLoginTypeLoginKey";
NSString *const GBTokenInformationPermissionsKey = @"com.facebook.sdk:TokenInformationPermissionsKey";
NSString *const GBTokenInformationPermissionsRefreshDateKey = @"com.facebook.sdk:TokenInformationPermissionsRefreshDateKey";

#pragma mark - private GBSessionTokenCachingStrategyNoOpInstance class

@interface GBSessionTokenCachingStrategyNoOpInstance : GBSessionTokenCachingStrategy

@end
@implementation GBSessionTokenCachingStrategyNoOpInstance

- (void)cacheTokenInformation:(NSDictionary*)tokenInformation {
}

- (NSDictionary*)fetchTokenInformation {
    return [NSDictionary dictionary];
}

- (void)clearToken {
}

@end


@implementation GBSessionTokenCachingStrategy {
    NSString *_accessTokenInformationKeyName;
}

#pragma mark - Lifecycle

- (id)init {
    return [self initWithUserDefaultTokenInformationKeyName:nil];
}

- (id)initWithUserDefaultTokenInformationKeyName:(NSString*)tokenInformationKeyName {

    self = [super init];
    if (self) {
        // get-em
        _accessTokenInformationKeyName = tokenInformationKeyName ? tokenInformationKeyName : GBAccessTokenInformationKeyName;

        // keep-em
        [_accessTokenInformationKeyName retain];
    }
    return self;
}

- (void)dealloc {
    // let-em go
    [_accessTokenInformationKeyName release];
    [super dealloc];
}

#pragma mark -
#pragma mark Public Members

- (void)cacheTokenInformation:(NSDictionary*)tokenInformation {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:tokenInformation forKey:_accessTokenInformationKeyName];
    [defaults synchronize];
}

- (NSDictionary*)fetchTokenInformation {
    // fetch values from defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:_accessTokenInformationKeyName];
}

- (void)clearToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:_accessTokenInformationKeyName];
    [defaults synchronize];
}


- (void)cacheGBAccessTokenData:(GBAccessTokenData *)accessToken {
    // For backwards compatibility, we must call into existing dictionary-based APIs.
    [self cacheTokenInformation:[accessToken dictionary]];
}

- (GBAccessTokenData *)fetchGBAccessTokenData {
    // For backwards compatibility, we must call into existing dictionary-based APIs.
    NSDictionary *dictionary = [self fetchTokenInformation];
    if (![GBSessionTokenCachingStrategy isValidTokenInformation:dictionary]) {
        return nil;
    }
    GBAccessTokenData *fbAccessToken = [GBAccessTokenData createTokenFromDictionary:dictionary];
    return fbAccessToken;
}

+ (BOOL)isValidTokenInformation:(NSDictionary*)tokenInformation {
    id token = [tokenInformation objectForKey:GBTokenInformationTokenKey];
    id expirationDate = [tokenInformation objectForKey:GBTokenInformationExpirationDateKey];
    return  [token isKindOfClass:[NSString class]] &&
            ([token length] > 0) &&
            [expirationDate isKindOfClass:[NSDate class]];
}

+ (GBSessionTokenCachingStrategy*)defaultInstance {
    // static state to assure a single default instance here
    static GBSessionTokenCachingStrategy *sharedDefaultInstance = nil;
    static dispatch_once_t onceToken;

    // assign once to the static, if called
    dispatch_once(&onceToken, ^{
        sharedDefaultInstance = [[GBSessionTokenCachingStrategy alloc] init];
    });
    return sharedDefaultInstance;
}

+ (GBSessionTokenCachingStrategy*)nullCacheInstance {
    // static state to assure a single instance here
    static GBSessionTokenCachingStrategyNoOpInstance *noOpInstance = nil;
    static dispatch_once_t onceToken;

    // assign once to the static, if called
    dispatch_once(&onceToken, ^{
        noOpInstance = [[GBSessionTokenCachingStrategyNoOpInstance alloc] init];
    });
    return noOpInstance;
}

#pragma mark -

@end
