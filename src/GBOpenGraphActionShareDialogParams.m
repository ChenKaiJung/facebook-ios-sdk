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

#import "GBOpenGraphActionShareDialogParams.h"

#import "GBAppBridge.h"
#import "GBDialogsParams+Internal.h"
#import "GBError.h"
#import "GBLogger.h"
#import "GBUtility.h"

#ifndef GB_BUILD_ONLY
#define GB_BUILD_ONLY
#endif

#import "GBSettings.h"

#ifdef GB_BUILD_ONLY
#undef GB_BUILD_ONLY
#endif

NSString *const GBPostObjectOfType = @"fbsdk:create_object_of_type";
NSString *const GBPostObject = @"fbsdk:create_object";

NSString *const kGBAppBridgeMinVersion = @"20130214";
NSString *const kGBAppBridgeImageSupportVersion = @"20130410";

@implementation GBOpenGraphActionShareDialogParams

- (void)dealloc
{
    [_previewPropertyName release];
    [_actionType release];
    [_action release];

    [super dealloc];
}

+ (NSString *)getPostedObjectTypeFromObject:(id<GBGraphObject>)obj {
    if ([(id)obj objectForKey:GBPostObject] &&
        [(id)obj objectForKey:@"type"]) {
        return [(id)obj objectForKey:@"type"];
    }
    return nil;
}
+ (NSString *)getIdOrUrlFromObject:(id<GBGraphObject>)obj {
    id result;
    if ((result = [(id)obj objectForKey:@"id"]) ||
        (result = [(id)obj objectForKey:@"url"])) {
      return result;
    }
    return nil;
}

- (NSError *)validate {
    NSString *errorReason = nil;

    if (!self.action || !self.actionType || !self.previewPropertyName) {
        errorReason = GBErrorDialogInvalidOpenGraphActionParameters;
    } else {
        for (NSString *key in (id)self.action) {
            id obj = [(id)self.action objectForKey:key];
            if ([obj conformsToProtocol:@protocol(GBGraphObject)]) {
                if (![GBOpenGraphActionShareDialogParams getPostedObjectTypeFromObject:obj] &&
                    ![GBOpenGraphActionShareDialogParams getIdOrUrlFromObject:obj]) {
                    errorReason = GBErrorDialogInvalidOpenGraphObject;
                }
            }
        }
    }
    if (errorReason) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[GBErrorDialogReasonKey] = errorReason;
        return [NSError errorWithDomain:GbombSDKDomain
                                   code:GBErrorDialog
                               userInfo:userInfo];
    }
    return nil;
}

- (id)flattenObject:(id)obj {
    if ([obj conformsToProtocol:@protocol(GBGraphObject)]) {
        // #2267154: Temporarily work around change in native protocol. This will be removed
        // before leaving beta. After that, just don't flatten objects that have GBPostObject.
        NSString *postedObjectType;
        NSString *idOrUrl;
        if ((postedObjectType = [GBOpenGraphActionShareDialogParams getPostedObjectTypeFromObject:obj])) {
            if (![GBAppBridge installedGBNativeAppVersionForMethod:@"ogshare"
                                                        minVersion:@"20130410"]) {
                // We only need to do this for pre-20130410 versions.
                [obj setObject:postedObjectType forKey:GBPostObjectOfType];
                [obj removeObjectForKey:GBPostObject];
                [obj removeObjectForKey:@"type"];
            }
        } else if ((idOrUrl = [GBOpenGraphActionShareDialogParams getIdOrUrlFromObject:obj])) {
              return idOrUrl;
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *flattenedArray = [[[NSMutableArray alloc] init] autorelease];
        for (id val in obj) {
            [flattenedArray addObject:[self flattenObject:val]];
        }
        return flattenedArray;
    }
    return obj;
}

- (id)flattenGraphObjects:(id)dict {
    NSMutableDictionary *flattened = [[[NSMutableDictionary alloc] initWithDictionary:dict] autorelease];
    for (NSString *key in dict) {
        id value = [dict objectForKey:key];
        // Since flattenGraphObjects is only called for the OG action AND image is a special
        // object with attributes that should NOT be flattened (e.g., "user_generated"),
        // we should skip flattening the image dictionary.
        if ([key isEqualToString:@"image"]) {
          [flattened setObject:value forKey:key];
        } else {
          [flattened setObject:[self flattenObject:value] forKey:key];
        }
    }
    return flattened;
}

- (NSDictionary *)dictionaryMethodArgs
{
    NSMutableDictionary *args = [NSMutableDictionary dictionary];
    if (self.action) {
        [args setObject:[self flattenGraphObjects:self.action] forKey:@"action"];
    }
    if (self.actionType) {
        [args setObject:self.actionType forKey:@"actionType"];
    }
    if (self.previewPropertyName) {
        [args setObject:self.previewPropertyName forKey:@"previewPropertyName"];
    }

    return args;
}

- (NSString *)appBridgeVersion
{
    NSString *imgSupportVersion = [GBAppBridge installedGBNativeAppVersionForMethod:@"ogshare"
                                                                         minVersion:kGBAppBridgeImageSupportVersion];
    if (!imgSupportVersion) {
        NSString *minVersion = [GBAppBridge installedGBNativeAppVersionForMethod:@"ogshare" minVersion:kGBAppBridgeMinVersion];
        if ([GBSettings isBetaFeatureEnabled:GBBetaFeaturesOpenGraphShareDialog] && minVersion) {
            if ([self containsUIImages:self.action]) {
                [GBLogger singleShotLogEntry:GBLoggingBehaviorDeveloperErrors
                                    logEntry:@"GBOpenGraphActionShareDialogParams: the current Facebook app does not support embedding UIImages."];
                return nil;
            }
            return minVersion;
        }
        return nil;
    }
    return imgSupportVersion;
}

- (BOOL)containsUIImages:(id)param
{
    BOOL containsUIImages = NO;
    NSArray *values = nil;
    if ([param isKindOfClass:[NSDictionary class]]) {
        values = ((NSDictionary *)param).allValues;
    } else if ([param isKindOfClass:[NSArray class]]) {
        values = param;
    } else if ([param isKindOfClass:[UIImage class]]) {
        return YES;
    }
    if (values) {
        for (id value in values) {
            containsUIImages = containsUIImages || [self containsUIImages:value];
        }
    }
    return containsUIImages;
}

@end
