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

#import "GBAppBridge.h"

#import "GBAppBridgeTypeToJSONConverter.h"
#import "GBAppCall+Internal.h"
#import "FBBase64.h"
#import "FBCrypto.h"
#import "GBDialogsData+Internal.h"
#import "GBError.h"
#import "GBSession+Internal.h"
#import "GBSettings+Internal.h"
#import "GBUtility.h"

/*
 GBBridgeURLParams and GBBridgeKey define the protocol used between the native Facebook app
 and the SDK to communicate over GBAppBridge
 */

/*
 GBBridgeURLParams - parameter names that go directly into the url's query string.
 - bridgeArgs : JSON object with properties used by the bridge.
 - methodArgs : JSON object with properties specified by the method-specific code in the SDK. These are to be
 consumed by the receiving method-specific code in the native Facebook app and are opaque to the bridge.
 - appId : Facebook ID for the calling third party application.
 - schemeSuffix : Suffix used in the scheme to differentiate different apps on the device that share the same GBID.
 - method_results : JSON object with properties specified by the method-specific code in the native Facebook app.
 These are to be consumed by the receiving method-specific code in the SDK and are opaque to the bridge.
 - cipher : Encrypted data containing the above JSON objects. If present, the above objects are not included
 directly in the URL.
 - cipherKey : Sent by the SDK and to used by the native Facebook app in the creation of the cipher blob.
 - version : Version of the protocol and app call, represented by one value.
 */

static const struct {
    NSString *bridgeArgs;
    NSString *methodArgs;
    NSString *appId;
    NSString *schemeSuffix;
    NSString *methodResults;
    NSString *cipher;
    NSString *cipherKey;
    NSString *version;
} GBBridgeURLParams = {
    .bridgeArgs = @"bridge_args",
    .methodArgs = @"method_args",
    .appId = @"app_id",
    .schemeSuffix = @"scheme_suffix",
    .methodResults = @"method_results",
    .cipher = @"cipher",
    .cipherKey = @"cipher_key",
    .version = @"version",
};

/*
 GBBridgeKey - keys into the bridgeArgs JSON object.
 - actionId : GUID used by the bridge to identify a unique AppCall. Generated in the SDK.
 - appName : Name of the calling app.
 - appIcon : Icon of the calling app.
 - clientState : JSON object which is opaque to the bridge and method-specific code. It is simply passed through in the
 response to allow third party apps to pass context into their completion handlers.
 */
static const struct {
    NSString *actionId;
    NSString *appName;
    NSString *appIcon;
    NSString *clientState;
    NSString *error;
} GBBridgeKey = {
    .actionId = @"action_id",
    .appName = @"app_name",
    .appIcon = @"app_icon",
    .clientState = @"client_state",
    .error = @"error",
};

static const struct {
    NSString *code;
    NSString *domain;
    NSString *userInfo;
} GBBridgeErrorKey = {
    .code = @"code",
    .domain = @"domain",
    .userInfo = @"user_info",
};

static NSString *const GBAppBridgeURLHost = @"bridge";
static NSString *const GBAppBridgeURLFormat = @"gbapi%@://dialog/%@?%@";
static NSString *const kSerializeErrorMessage = @"Unable to present native dialog due to error processing arguments. \
The protocol used to communicate with the Facebook application requires arguments to be translated to JSON, which \
failed. Check the arguments and clientState to assure that they are well-formed.";
static NSString *const GBAppBridgePasteboardNamesKey = @"GBAppBridgePasteboards";

/*
 Array of known versions that the native GB app can support.
 They should be ordered with each element being a more recent version than the previous.

 Format of a version : <yyyy><mm><dd>
 */
static NSString *const GBAppBridgeVersions[] = {
    @"20130214",
    @"20130410",
    @"20130702",
    @"20131010"
};

static GBAppBridge *g_sharedInstance;

@interface GBAppBridge()

@property (nonatomic, retain) NSMutableDictionary *pendingAppCalls;
@property (nonatomic, retain) NSMutableDictionary *callbacks;
@property (nonatomic, retain) GBAppBridgeTypeToJSONConverter *jsonConverter;
@property (nonatomic, copy) NSString *appID;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *appName;

@end

@implementation GBAppBridge

+(id)sharedInstance
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        g_sharedInstance = [[GBAppBridge alloc] init];
    });
    return g_sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        self.appID = [GBSettings defaultAppID];
        // if we don't have an appID by here, fail -- this is almost certainly an app-bug
        if (!self.appID) {
            [[NSException exceptionWithName:GBInvalidOperationException
                                     reason:@"GBAppBridge: AppID not found; Add a string valued key with the "
              @"appropriate id named GbombAppID to the bundle *.plist"
                                   userInfo:nil]
             raise];
        }

        // Cache these values since they will not change
        self.bundleID = [[NSBundle mainBundle] bundleIdentifier];
        self.appName = [GBSettings defaultDisplayName];

        self.pendingAppCalls = [NSMutableDictionary dictionary];
        self.callbacks = [NSMutableDictionary dictionary];
        self.jsonConverter = [[[GBAppBridgeTypeToJSONConverter alloc] init] autorelease];
    }
    return self;
}

- (void)dealloc
{
    // Probably don't need the releases for singletons
    [_pendingAppCalls release];
    [_callbacks release];
    [_jsonConverter release];
    [_appID release];
    [_bundleID release];

    [super dealloc];
}

- (void)dispatchDialogAppCall:(GBAppCall *)appCall
                      version:(NSString *)version
                      session:(GBSession *)session
            completionHandler:(GBAppCallHandler)handler {
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self performDialogAppCall:appCall
                           version:version
                           session:session
                 completionHandler:handler];
    });
}

- (void)performDialogAppCall:(GBAppCall *)appCall
                     version:(NSString *)version
                     session:(GBSession *)session
           completionHandler:(GBAppCallHandler)handler {
    if (!session) {
        session = GBSession.activeSessionIfExists;
    }
    if (!appCall.isValid || !appCall.dialogData || !version) {
        // NOTE : the GBConditionalLog is wrapped in an if to allow us to return and prevent exceptions
        // further down. No need to check the condition again since we know we are in an error state.
        // TODO : Change this to an assert and remove the if.
        GBConditionalLog(YES, @"GBAppBridge: Must provide a valid AppCall object & version.");
        return;
    }

    NSMutableDictionary *queryParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        self.appID, GBBridgeURLParams.appId,
                                        [GBAppBridge symmetricKeyAndForceRefresh:NO], GBBridgeURLParams.cipherKey,
                                        nil];
    NSMutableDictionary *bridgeParams = [NSMutableDictionary dictionaryWithObject:appCall.ID
                                                                           forKey:GBBridgeKey.actionId];

    [self addAppMetadataToDictionary:bridgeParams];

    if (appCall.dialogData.clientState) {
        // Serialize clientState to JSON prior to converting bridgeParams to be json-ready. This will
        // prevent our code from introspecting into clientState
        NSString *clientStateString = [GBUtility simpleJSONEncode:appCall.dialogData.clientState];
        if (clientStateString) {
            bridgeParams[GBBridgeKey.clientState] = clientStateString;
        } else {
            // clientState is not valid JSON
            [self invoke:handler forFailedAppCall:appCall withMessage:kSerializeErrorMessage];
            return;
        }
    }

    NSString *urlSchemeSuffix = session.urlSchemeSuffix ?: [GBSettings defaultUrlSchemeSuffix];
    if (urlSchemeSuffix) {
        queryParams[GBBridgeURLParams.schemeSuffix] = urlSchemeSuffix;
    }

    NSString *jsonString = [self jsonStringFromDictionary:bridgeParams];
    if (!jsonString) {
        [self invoke:handler forFailedAppCall:appCall withMessage:kSerializeErrorMessage];
        return;
    }
    queryParams[GBBridgeURLParams.bridgeArgs] = jsonString;

    jsonString = [self jsonStringFromDictionary:appCall.dialogData.arguments];
    if (!jsonString) {
        [self invoke:handler forFailedAppCall:appCall withMessage:kSerializeErrorMessage];
        return;
    }
    queryParams[GBBridgeURLParams.methodArgs] = jsonString;

    NSURL *url = [GBAppBridge urlForMethod:appCall.dialogData.method queryParams:queryParams version:version];

    // Track the callback and AppCall, now that we are just about to invoke the url
    [self trackAppCall:appCall withCompletionHandler:handler];

    // Remember what items we put on the pasteboard for this call.
    [self savePasteboardNames:self.jsonConverter.createdPasteboardNames forAppCallID:appCall.ID];

    BOOL success = [[UIApplication sharedApplication] openURL:url];

    if (!success) {
        [self stopTrackingCallWithID:appCall.ID];
        [self invoke:handler
             forFailedAppCall:appCall
                  withMessage:@"Failed to open native dialog. Please ensure that the Facebook app is installed"];
    }
}

- (void)invoke:(GBAppCallHandler)handler
forFailedAppCall:(GBAppCall *)appCall
   withMessage:(NSString *)message {
    if (!handler) {
        // Nothing to do here
        return;
    }

    appCall.error = [NSError errorWithDomain:GbombSDKDomain
                                        code:GBErrorDialog
                                    userInfo:@{@"message":message}];

    handler(appCall);
}

- (BOOL)handleOpenURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
              session:(GBSession *)session
      fallbackHandler:(GBAppCallHandler)fallbackHandler {
    NSString *urlHost = [url.host lowercaseString];
    NSString *urlScheme = [url.scheme lowercaseString];
    NSString *expectedUrlScheme = [[GBSettings defaultURLSchemeWithAppID:session.appID urlSchemeSuffix:session.urlSchemeSuffix] lowercaseString];
    if (![urlHost isEqualToString:GBAppBridgeURLHost] || ![urlScheme isEqualToString:expectedUrlScheme]) {
        GBAppCall *appCall = [GBAppCall appCallFromURL:url];
        if (appCall && fallbackHandler) {
            fallbackHandler(appCall);
            return YES;
        } else {
            return NO;
        }
    }

    // If we're here, this URL was meant for the bridge. So from here on, let's make sure to
    // always call the fallback handler so that the app knows that it doesn't need to
    // try and process the URL any further.

    BOOL success = NO;
    NSInteger preProcessErrorCode = 0;
    if (![GBUtility isFacebookBundleIdentifier:sourceApplication]) {
        // If we're getting a response from another non-GB app, let's drop
        // our old symmetric key, since it might have been compromised.
        [GBAppBridge symmetricKeyAndForceRefresh:YES];

        // The bridge only handles URLs from a native Facebook app.
        preProcessErrorCode = GBErrorUntrustedURL;
    } else {
        NSString *urlPath = nil;
        if ([url.path length] > 1) {
            urlPath = [[url.path lowercaseString] substringFromIndex:1];
        }

        if (urlPath && url.query) {
            NSDictionary *queryParams = [GBUtility dictionaryByParsingURLQueryPart:url.query];
            BOOL isEncrypted = (queryParams[GBBridgeURLParams.cipher] != nil);
            if (isEncrypted) {
                queryParams = [self decryptUrlQueryParams:queryParams
                                                   method:urlPath
                                          fallbackHandler:fallbackHandler];
            }

            success = [self processResponse:queryParams
                                     method:urlPath
                                    session:session
                            fallbackHandler:fallbackHandler];
        }
    }

    if (!success && fallbackHandler) {
        NSError *preProcessError = [NSError errorWithDomain:GbombSDKDomain
                                                       code:preProcessErrorCode ?: GBErrorMalformedURL
                                                   userInfo:@{
                                  GBErrorUnprocessedURLKey : url,
                                 NSLocalizedDescriptionKey : @"The URL could not be processed for an GBAppCall"
                                    }];

        // NOTE : At this point, we don't have a way to know whether this URL was for a pending AppCall.
        // This has the potential to leave some pending AppCalls in an unterminated state until the app shuts down.
        // However, as long as the app has wired up the handleDidBecomeActive method in GBAppCall, it will
        // get invoked by iOS after the openURL: call stack. This will result in all pending AppCalls getting
        // cancelled, which is the desired approach here.
        GBAppCall *dummyCall = [[[GBAppCall alloc] initWithID:nil enforceScheme:NO appID:session.appID urlSchemeSuffix:session.urlSchemeSuffix] autorelease];
        dummyCall.error = preProcessError;
        fallbackHandler(dummyCall);
    }

    return YES;
}

- (void)handleDidBecomeActive {
    // See if we had any pending AppCalls. If we did, then we need to signal an error to the app since
    // the app was made active without the response URL from the native facebook app.

    NSError *error = nil;
    NSArray *allPendingAppCalls = [self.pendingAppCalls allValues];

    for (GBAppCall *call in allPendingAppCalls) {
        [call retain];
        GBAppCallHandler handler = [[self.callbacks[call.ID] retain] autorelease];
        [self stopTrackingCallWithID:call.ID];

        @try {
            if (handler) {
                if (!error) {
                    error = [NSError errorWithDomain:GbombSDKDomain
                                                     code:GBErrorAppActivatedWhilePendingAppCall
                                                 userInfo:@{NSLocalizedDescriptionKey : @"The user navigated away from "
                                  @"the Facebook app prior to completing this AppCall. This AppCall is now cancelled "
                                  @"and needs to be retried to get a successful completion"}];
                }
                call.error = error;

                // Passing nil for results, since we are effectively cancelling this action
                handler(call);
            }
        }
        @finally {
            [call release];
        }
    }

}

- (BOOL)processResponse:(NSDictionary *)queryParams
                 method:(NSString *)method
                session:(GBSession *)session
        fallbackHandler:(GBAppCallHandler)fallbackHandler {
    NSDictionary *bridgeArgs = [self dictionaryFromJSONString:queryParams[GBBridgeURLParams.bridgeArgs]];
    NSString *callID = bridgeArgs[GBBridgeKey.actionId];
    NSString *version = queryParams[GBBridgeURLParams.version];

    if (!callID || !version) {
        // If we can't get the call Id, we have no way to proceed
        // Also reject un-versioned responses
        return NO;
    }

    GBAppCallHandler handler = [[self.callbacks[callID] retain] autorelease];
    GBAppCall *call = [self.pendingAppCalls[callID] retain];

    // If we aren't tracking this AppCall, then we need to pass control over to the fallback handler
    // if one has been provided. This is the expected code path if the app was shutdown after switching
    // to the native Facebook app. We can create a duplicate GBAppCall object to pass to the
    // fallback handler, from the data in the url.
    if (!call && fallbackHandler) {
        NSDictionary *methodArgs = [self dictionaryFromJSONString:queryParams[GBBridgeURLParams.methodArgs]];
        NSDictionary *clientState = [GBUtility simpleJSONDecode:bridgeArgs[GBBridgeKey.clientState]];

        GBDialogsData *dialogData = [[[GBDialogsData alloc] initWithMethod:method
                                                                             arguments:methodArgs]
                                           autorelease];
        dialogData.clientState = clientState;

        call = [[GBAppCall alloc] initWithID:callID enforceScheme:NO appID:session.appID urlSchemeSuffix:session.urlSchemeSuffix];
        call.dialogData = dialogData;

        handler = fallbackHandler;
    }

    [self stopTrackingCallWithID:callID];

    // TODO: Log if handler was not found.
    call.dialogData.results = [self dictionaryFromJSONString:queryParams[GBBridgeURLParams.methodResults]];
    call.error = [GBAppBridge errorFromDictionary:bridgeArgs[GBBridgeKey.error]];

    @try {
        if (handler) {
            handler(call);
        }
    }
    @finally {
        [call release];
    }

    // If we were able to find the call Id, then we handled the url.
    return YES;
}

- (NSDictionary *)decryptUrlQueryParams:(NSDictionary *)cipherParams
                                 method:(NSString *)method
                        fallbackHandler:(GBAppCallHandler)fallbackHandler {
    // Fetch the key from NSUserDefaults & pull apart the encrypted url query parameters
    NSString *symmetricKey = [GBAppBridge symmetricKeyAndForceRefresh:NO];
    NSString *version = cipherParams[GBBridgeURLParams.version];
    NSString *cipherText = cipherParams[GBBridgeURLParams.cipher];
    if (!symmetricKey || !cipherText || !version) {
        return nil;
    }

    // Build up the data needed to check the cipher's signature
    NSArray *additionalDataComponents = [NSArray arrayWithObjects:
                                         self.bundleID,
                                         self.appID,
                                         GBAppBridgeURLHost,
                                         method,
                                         version,
                                         nil];
    NSString *additionalData = [additionalDataComponents componentsJoinedByString:@":"];

    // Now that we have all required info, decrypt!
    FBCrypto *crypto = [[FBCrypto alloc] initWithMasterKey:symmetricKey];
    NSData *decryptedData = [crypto decrypt:cipherText
                       additionalSignedData:[additionalData dataUsingEncoding:NSUTF8StringEncoding]];
    [crypto release];
    if (!decryptedData) {
        return nil;
    }

    // Now create the decrypted query params dictionary
    NSString *queryParamsStr = [[NSString alloc] initWithData:decryptedData
                                                     encoding:NSUTF8StringEncoding];
    NSMutableDictionary *queryParams = [NSMutableDictionary dictionaryWithDictionary:
                                        [GBUtility dictionaryByParsingURLQueryPart:queryParamsStr]];
    queryParams[GBBridgeURLParams.version] = version;
    [queryParamsStr release];

    return queryParams;
}

+ (NSString *)symmetricKeyAndForceRefresh:(BOOL)forceRefresh {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *symmetricKey = [defaults objectForKey:GBBridgeURLParams.cipherKey];
    if (!symmetricKey || forceRefresh) {
        // Generate keys
        symmetricKey = [FBCrypto makeMasterKey];

        // Store the keys
        [defaults setObject:symmetricKey forKey:GBBridgeURLParams.cipherKey];
    }

    return symmetricKey;
}

- (void)addAppMetadataToDictionary:(NSMutableDictionary *)dictionary {
    if (self.appName) {
        dictionary[GBBridgeKey.appName] = self.appName;
    }

    UIImage *appIcon = [GBAppBridge appIconFromBundleInfo:[[NSBundle mainBundle] infoDictionary]];
    if (appIcon) {
        dictionary[GBBridgeKey.appIcon] = appIcon;
    }
}

- (void)trackAppCall:(GBAppCall *)call
withCompletionHandler:(GBAppCallHandler)handler {
    self.pendingAppCalls[call.ID] = call;
    if (!handler) {
        // a noop handler if nil is passed in
        handler = ^(GBAppCall *call) {};
    }
    // Can immediately autorelease since adding it to self.callbacks causes a retain.
    self.callbacks[call.ID] = [Block_copy(handler) autorelease];
}

- (void)stopTrackingCallWithID:(NSString *)callID {
    [self.pendingAppCalls removeObjectForKey:callID];
    [self.callbacks removeObjectForKey:callID];

    [self deletePasteboardsForAppCallID:callID];
}

- (NSString *)jsonStringFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary) {
        return nil;
    }
    NSDictionary *wrappedDictionary = [self.jsonConverter jsonDictionaryFromDictionaryWithAppBridgeTypes:dictionary];
    return [GBUtility simpleJSONEncode:wrappedDictionary];
}

- (NSDictionary *)dictionaryFromJSONString:(NSString *)jsonString {
    if (!jsonString) {
        return nil;
    }
    NSDictionary *jsonDictionary = [GBUtility simpleJSONDecode:jsonString];
    return [self.jsonConverter dictionaryWithAppBridgeTypesFromJSONDictionary:jsonDictionary];
}

- (void)savePasteboardNames:(NSArray *)pasteboardNames forAppCallID:(NSString *)appCallID {
    if (pasteboardNames.count == 0) {
        return;
    }

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dictionary = [[[userDefaults objectForKey:GBAppBridgePasteboardNamesKey] mutableCopy] autorelease];

    dictionary[appCallID] = pasteboardNames;
    [userDefaults setObject:dictionary forKey:GBAppBridgePasteboardNamesKey];
    [userDefaults synchronize];
}

- (void)deletePasteboardsForAppCallID:(NSString *)appCallID {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dictionary = [[[userDefaults objectForKey:GBAppBridgePasteboardNamesKey] mutableCopy] autorelease];
    NSArray *pasteboardNames = dictionary[appCallID];

    if (!pasteboardNames) {
        return;
    }

    for (NSString *pasteboardName in pasteboardNames) {
        UIPasteboard *board = [UIPasteboard pasteboardWithName:pasteboardName create:NO];
        if (board) {
            [UIPasteboard removePasteboardWithName:board.name];
        }
    }

    [dictionary removeObjectForKey:appCallID];

    [userDefaults setObject:dictionary forKey:GBAppBridgePasteboardNamesKey];
    [userDefaults synchronize];
}

+ (NSURL *)urlForMethod:(NSString *)method
            queryParams:(NSDictionary *)queryParams
                version:(NSString *)version {
    NSString *queryParamsStr = (queryParams) ? [GBUtility stringBySerializingQueryParameters:queryParams] : @"";
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:
                   GBAppBridgeURLFormat,
                   version,
                   method,
                   queryParamsStr]];
    return url;
}

+ (NSString *)installedGBNativeAppVersionForMethod:(NSString *)method
                                        minVersion:(NSString *)minVersion {
    NSString *version = nil;
    int index = sizeof(GBAppBridgeVersions)/sizeof(GBAppBridgeVersions[0]);
    while (index--) {
        version = GBAppBridgeVersions[index];
        BOOL isMinVersion = [version isEqualToString:minVersion];
        NSURL *url = [GBAppBridge urlForMethod:method queryParams:nil version:version];

        if (![[UIApplication sharedApplication] canOpenURL:url]) {
            version = nil;
        }

        if (version || isMinVersion) {
            // Either we found an installed version, or we just hit the minimum
            // version for this method and did not find it to be installed.
            // In either case, we are done searching
            break;
        }
    }

    return version;
}

+ (UIImage *)appIconFromBundleInfo:(NSDictionary *)bundleInfo {
    NSArray *bundleIconFiles = nil;
    NSDictionary *bundleIcons = bundleInfo[@"CGBundleIcons"];
    if (bundleIcons) {
        // iOS 5.0 and above.
        bundleIconFiles = bundleIcons[@"CGBundlePrimaryIcon"][@"CGBundleIconFiles"];
    } else {
        // iOS 3.2 and above. Note, that it appears to be missing in iOS 6.0
        bundleIconFiles = bundleInfo[@"CGBundleIconFiles"];
    }
    UIImage *appIcon = nil;
    if (bundleIconFiles && bundleIconFiles.count > 0) {
        // This should auto-select the right image file (w.r.t. resolution)
        appIcon = [UIImage imageNamed:[bundleIconFiles objectAtIndex:0]];
    }
    return appIcon;
}

+ (NSError *)errorFromDictionary:(NSDictionary *)errorDictionary {
    NSError *error = nil;
    if (errorDictionary) {
        NSString *domain = errorDictionary[GBBridgeErrorKey.domain];
        NSInteger code = [(NSNumber *)errorDictionary[GBBridgeErrorKey.code] integerValue];
        NSDictionary *userInfo = errorDictionary[GBBridgeErrorKey.userInfo];

        error = [NSError errorWithDomain:domain code:code userInfo:userInfo];
    }

    return error;
}

@end
