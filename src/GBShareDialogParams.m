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

#import "GBShareDialogParams.h"

#import "GBAppBridge.h"
#import "GBDialogsParams+Internal.h"
#import "GBLogger.h"
#import "GBUtility.h"

#ifndef GB_BUILD_ONLY
#define GB_BUILD_ONLY
#endif

#import "GBSettings.h"

#ifdef GB_BUILD_ONLY
#undef GB_BUILD_ONLY
#endif

@implementation GBShareDialogParams

static NSString *const kGBHttpScheme  = @"http";
static NSString *const kGBHttpsScheme = @"https";

static NSString *const kGBShareDialogBetaVersion = @"20130214";
static NSString *const kGBShareDialogProdVersion = @"20130410";

- (void)dealloc
{
    [_link release];
    [_name release];
    [_caption release];
//    [_description release];
    [_picture release];
    [_friends release];
    [_place release];
    [_ref release];

    [super dealloc];
}

- (NSDictionary *)dictionaryMethodArgs
{
    NSMutableDictionary *args = [NSMutableDictionary dictionary];
    if (self.link) {
        [args setObject:[self.link absoluteString] forKey:@"link"];
    }
    if (self.name) {
        [args setObject:self.name forKey:@"name"];
    }
    if (self.caption) {
        [args setObject:self.caption forKey:@"caption"];
    }
    if (self.description) {
        [args setObject:self.description forKey:@"description"];
    }
    if (self.picture) {
        [args setObject:[self.picture absoluteString] forKey:@"picture"];
    }
    if (self.friends) {
        NSMutableArray *tags = [NSMutableArray arrayWithCapacity:self.friends.count];
        for (id tag in self.friends) {
            [tags addObject:[GBUtility stringGBIDFromObject:tag]];
        }
        [args setObject:tags forKey:@"tags"];
    }
    if (self.place) {
        [args setObject:[GBUtility stringGBIDFromObject:self.place] forKey:@"place"];
    }
    if (self.ref) {
        [args setObject:self.ref forKey:@"ref"];
    }
    [args setObject:[NSNumber numberWithBool:self.dataFailuresFatal] forKey:@"dataFailuresFatal"];

    return args;
}

- (void)setLink:(NSURL *)link
{
    [_link autorelease];
    if(link && ![self isSupportedScheme:link.scheme]) {
        _link = nil;
        [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors
                            logEntry:@"GBShareDialogParams: only \"http\" or \"https\" schemes are supported for link shares"];
    } else {
        _link = [link copy];
    }
}

- (void)setPicture:(NSURL *)picture
{
    [_picture autorelease];
    if (picture && ![self isSupportedScheme:picture.scheme]) {
        _picture = nil;
        [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors
                            logEntry:@"GBShareDialogParams: only \"http\" or \"https\" schemes are supported for link thumbnails"];
    } else {
        _picture = [picture copy];
    }
}

- (BOOL)isSupportedScheme:(NSString *)scheme
{
    return [[scheme lowercaseString] isEqualToString:kGBHttpScheme] ||
           [[scheme lowercaseString] isEqualToString:kGBHttpsScheme];
}

- (NSString *)appBridgeVersion
{
    if (_link && ![self isSupportedScheme:_link.scheme]) {
        return nil;
    }
    if (_picture && ![self isSupportedScheme:_picture.scheme]) {
        return nil;
    }

    NSString *prodVersion = [GBAppBridge installedGBNativeAppVersionForMethod:@"share"
                                                                   minVersion:kGBShareDialogProdVersion];
    if (!prodVersion) {
        if (![GBSettings isBetaFeatureEnabled:GBBetaFeaturesShareDialog]) {
            return nil;
        }
        return [GBAppBridge installedGBNativeAppVersionForMethod:@"share" minVersion:kGBShareDialogBetaVersion];
    }
    return prodVersion;
}

@end
