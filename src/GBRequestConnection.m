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

#import "GBRequestConnection.h"
#import "GBRequestConnection+Internal.h"

#import <UIKit/UIImage.h>

#import "GBDataDiskCache.h"
#import "GBError.h"
#import "GBErrorUtility+Internal.h"
#import "GBGraphObject.h"
#import "GBLogger.h"
#import "GBRequest+Internal.h"
#import "GBRequestBody.h"
#import "GBRequestConnectionRetryManager.h"
#import "GBRequestHandlerFactory.h"
#import "GBSDKVersion.h"
#import "GBSession+Internal.h"
#import "GBSession.h"
#import "GBSettings.h"
#import "GBSystemAccountStoreAdapter.h"
#import "GBURLConnection.h"
#import "GBUtility.h"
#import "Gbomb.h"

// URL construction constants
NSString *const gbGraphURLPrefix = @"https://graph.";
NSString *const gbGraphVideoURLPrefix = @"https://graph-video.";
NSString *const gbApiURLPrefix = @"https://api.";
NSString *const gbBatchKey = @"batch";
NSString *const gbBatchMethodKey = @"method";
NSString *const gbBatchRelativeURLKey = @"relative_url";
NSString *const gbBatchAttachmentKey = @"attached_files";
NSString *const gbBatchFileNamePrefix = @"file";
NSString *const gbBatchEntryName = @"name";

NSString *const gbAccessTokenKey = @"access_token";
NSString *const gbSDK = @"ios";
NSString *const gbUserAgentBase = @"GBiOSSDK";

NSString *const gbExtendTokenRestMethod = @"auth.extendSSOAccessToken";
NSString *const gbBatchRestMethodBaseURL = @"method/";

// response object property/key
NSString *const GBNonJSONResponseProperty = @"FACEBOOK_NON_JSON_RESULT";

static const int gbRESTAPIAccessTokenErrorCode = 190;
static const int gbRESTAPIPermissionErrorCode = 200;
static const int gbAPISessionNoLongerActiveErrorCode = 2500;
static const NSTimeInterval gbDefaultTimeout = 180.0;
static const int gbMaximumBatchSize = 50;

typedef void (^KeyValueActionHandler)(NSString *key, id value);

// ----------------------------------------------------------------------------
// GBRequestConnectionState

typedef enum GBRequestConnectionState {
    kStateCreated,
    kStateSerialized,
    kStateStarted,
    kStateCompleted,
    kStateCancelled,
} GBRequestConnectionState;

// ----------------------------------------------------------------------------
// Private properties and methods

@interface GBRequestConnection () {
    BOOL _errorBehavior;
}

@property (nonatomic, retain) GBURLConnection *connection;
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic) GBRequestConnectionState state;
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic, retain) NSMutableURLRequest *internalUrlRequest;
@property (nonatomic, retain, readwrite) NSHTTPURLResponse *urlResponse;
@property (nonatomic, retain) GBRequest *deprecatedRequest;
@property (nonatomic, retain) GBLogger *logger;
@property (nonatomic) unsigned long requestStartTime;
@property (nonatomic, readonly) BOOL isResultFromCache;
@property (nonatomic, retain) GBRequestConnectionRetryManager *retryManager;

@end

// ----------------------------------------------------------------------------
// GBRequestConnection

@implementation GBRequestConnection

// ----------------------------------------------------------------------------
// Property implementations

- (NSMutableURLRequest *)urlRequest
{
    if (self.internalUrlRequest) {
        NSMutableURLRequest *request = self.internalUrlRequest;

        [request setValue:[GBRequestConnection userAgent] forHTTPHeaderField:@"User-Agent"];
        [self logRequest:request bodyLength:0 bodyLogger:nil attachmentLogger:nil];

        return request;

    } else {
        // CONSIDER: Could move to kStateSerialized here by caching result, but
        // it seems bad for a get accessor to modify state in observable manner.
        return [self requestWithBatch:self.requests timeout:_timeout];
    }
}

- (void)setUrlRequest:(NSMutableURLRequest *)request
{
    NSAssert((self.state == kStateCreated) || (self.state == kStateSerialized),
             @"Cannot set urlRequest after starting or cancelling.");
    self.state = kStateSerialized;

    self.internalUrlRequest = request;
}

- (GBRequestConnectionErrorBehavior)errorBehavior
{
    return _errorBehavior;
}

- (void)setErrorBehavior:(GBRequestConnectionErrorBehavior)errorBehavior
{
    NSAssert(self.requests.count == 0, @"Cannot set errorBehavior after requests have been added");
    _errorBehavior = errorBehavior;
}

// ----------------------------------------------------------------------------
// Lifetime

- (id)init
{
    return [self initWithTimeout:gbDefaultTimeout];
}

// designated initializer
- (id)initWithTimeout:(NSTimeInterval)timeout
{
    if (self = [super init]) {
        _requests = [[NSMutableArray alloc] init];
        _timeout = timeout;
        _state = kStateCreated;
        _logger = [[GBLogger alloc] initWithLoggingBehavior:GBLoggingBehaviorGBRequests];
        _isResultFromCache = NO;
    }
    return self;
}

// internal constructor used for initializing with existing metadata/GBrequest instances,
// ostensibly for the retry flow.
- (id)initWithMetadata:(NSArray *)metadataArray
{
    if (self = [self initWithTimeout:gbDefaultTimeout]) {
        self.requests = [[metadataArray mutableCopy] autorelease];
    }
    return self;
}

- (void)dealloc
{
    [_connection cancel];
    [_connection release];
    [_requests release];
    [_internalUrlRequest release];
    [_urlResponse release];
    [_deprecatedRequest release];
    [_logger release];
    [_retryManager release];

    [super dealloc];
}

// ----------------------------------------------------------------------------
// Public methods
- (void)addRequest:(GBRequest *)request
 completionHandler:(GBRequestHandler)handler
{
    [self addRequest:request completionHandler:handler batchEntryName:nil];
}

- (void)addRequest:(GBRequest *)request
 completionHandler:(GBRequestHandler)handler
    batchEntryName:(NSString *)name
{
    NSDictionary *batchParams = (name)? @{gbBatchEntryName : name } : nil;
    [self addRequest:request completionHandler:handler batchParameters:batchParams behavior:self.errorBehavior];
}

- (void)addRequest:(GBRequest*)request
 completionHandler:(GBRequestHandler)handler
   batchParameters:(NSDictionary*)batchParameters {
    [self addRequest:request completionHandler:handler batchParameters:batchParameters behavior:self.errorBehavior];
}

- (void)addRequest:(GBRequest*)request
 completionHandler:(GBRequestHandler)handler
   batchParameters:(NSDictionary*)batchParameters
          behavior:(GBRequestConnectionErrorBehavior)behavior
{
    NSAssert(self.state == kStateCreated,
             @"Requests must be added before starting or cancelling.");

    GBRequestMetadata *metadata = [[GBRequestMetadata alloc] initWithRequest:request
                                                           completionHandler:handler
                                                             batchParameters:batchParameters
                                                                    behavior:behavior];

    [self.requests addObject:metadata];
    [metadata release];
}

- (void)start
{
    [self startWithCacheIdentity:nil
           skipRoundtripIfCached:NO];
}

- (void)cancel {
    // Cancelling self.connection might trigger error handlers that cause us to
    // get freed. Make sure we stick around long enough to finish this method call.
    [[self retain] autorelease];

    // Set the state to cancelled now prior to any handlers being invoked.
    self.state = kStateCancelled;
    [self.connection cancel];
    self.connection = nil;
}

// ----------------------------------------------------------------------------
// Public class methods

+ (GBRequestConnection*)startForMeWithCompletionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForMe];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startForMyFriendsWithCompletionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForMyFriends];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startForUploadPhoto:(UIImage *)photo
                          completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForUploadPhoto:photo];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForPostStatusUpdate:(NSString *)message
                                completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForPostStatusUpdate:message];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForPostStatusUpdate:(NSString *)message
                                            place:(id)place
                                             tags:(id<NSFastEnumeration>)tags
                                completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForPostStatusUpdate:message
                                                         place:place
                                                          tags:tags];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startForPlacesSearchAtCoordinate:(CLLocationCoordinate2D)coordinate
                                          radiusInMeters:(NSInteger)radius
                                            resultsLimit:(NSInteger)limit
                                              searchText:(NSString*)searchText
                                       completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForPlacesSearchAtCoordinate:coordinate
                                                        radiusInMeters:radius
                                                          resultsLimit:limit
                                                            searchText:searchText];

    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startForCustomAudienceThirdPartyID:(GBSession *)session
                                         completionHandler:(GBRequestHandler)handler {

    return [[GBRequest requestForCustomAudienceThirdPartyID:session]
            startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startWithGraphPath:(NSString*)graphPath
                         completionHandler:(GBRequestHandler)handler
{
    return [GBRequestConnection startWithGraphPath:graphPath
                                        parameters:nil
                                        HTTPMethod:nil
                                 completionHandler:handler];
}

+ (GBRequestConnection*)startForDeleteObject:(id)object
                           completionHandler:(GBRequestHandler)handler
{
    GBRequest *request = [GBRequest requestForDeleteObject:object];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startForPostWithGraphPath:(NSString*)graphPath
                                      graphObject:(id<GBGraphObject>)graphObject
                                completionHandler:(GBRequestHandler)handler
{
    GBRequest *request = [GBRequest requestForPostWithGraphPath:graphPath
                                                    graphObject:graphObject];

    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection*)startWithGraphPath:(NSString*)graphPath
                                parameters:(NSDictionary*)parameters
                                HTTPMethod:(NSString*)HTTPMethod
                         completionHandler:(GBRequestHandler)handler
{
    GBRequest *request = [GBRequest requestWithGraphPath:graphPath
                                              parameters:parameters
                                              HTTPMethod:HTTPMethod];

    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForPostOpenGraphObject:(id<GBOpenGraphObject>)object
                                   completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForPostOpenGraphObject:object];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForPostOpenGraphObjectWithType:(NSString *)type
                                                       title:(NSString *)title
                                                       image:(id)image
                                                         url:(id)url
                                                 description:(NSString *)description
                                            objectProperties:(NSDictionary *)objectProperties
                                           completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForPostOpenGraphObjectWithType:type
                                                                    title:title
                                                                    image:image
                                                                      url:url
                                                              description:description
                                                         objectProperties:objectProperties];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForUpdateOpenGraphObject:(id<GBOpenGraphObject>)object
                                     completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForUpdateOpenGraphObject:object];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForUpdateOpenGraphObjectWithId:(id)objectId
                                                       title:(NSString *)title
                                                       image:(id)image
                                                         url:(id)url
                                                 description:(NSString *)description
                                            objectProperties:(NSDictionary *)objectProperties
                                           completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForUpdateOpenGraphObjectWithId:objectId
                                                                    title:title
                                                                    image:image
                                                                      url:url
                                                              description:description
                                                         objectProperties:objectProperties];
    return [request startWithCompletionHandler:handler];
}

+ (GBRequestConnection *)startForUploadStagingResourceWithImage:(UIImage *)photo
                                              completionHandler:(GBRequestHandler)handler {
    GBRequest *request = [GBRequest requestForUploadStagingResourceWithImage:photo];
    return [request startWithCompletionHandler:handler];
}

// ----------------------------------------------------------------------------
// Private methods

- (void)startWithCacheIdentity:(NSString*)cacheIdentity
         skipRoundtripIfCached:(BOOL)skipRoundtripIfCached
{
    if ([self.requests count] == 1) {
        GBRequestMetadata *firstMetadata = [self.requests objectAtIndex:0];
        if ([firstMetadata.request delegate]) {
            self.deprecatedRequest = firstMetadata.request;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            [self.deprecatedRequest setState:kGBRequestStateLoading];
#pragma GCC diagnostic pop
        }
    }

    NSMutableURLRequest *request = nil;
    NSData *cachedData = nil;
    NSURL *cacheIdentityURL = nil;
    if (cacheIdentity) {
        // warning! this property has significant side-effects, and should be executed at the right moment
        // depending on whether there may be batching or whether we are certain there is no batching
        request = self.urlRequest;

        // when we generalize this for consumers of GBRequest, then we will use a more
        // normalized form for our identification scheme than this URL construction; given the only
        // clients are the two pickers -- this scheme achieves stability via being a closed system,
        // and provides a simple first step to the more general solution
        cacheIdentityURL = [[[NSURL alloc] initWithScheme:@"GBRequestCache"
                                                     host:cacheIdentity
                                                     path:[NSString stringWithFormat:@"/%@", request.URL]]
                            autorelease];

        if (skipRoundtripIfCached) {
            cachedData = [[GBDataDiskCache sharedCache] dataForURL:cacheIdentityURL];
        }
    }

    if (self.internalUrlRequest == nil && !cacheIdentity) {
        // If we have all Graph API calls, see if we want to piggyback any internal calls onto
        // the request to reduce round-trips. (The piggybacked calls may themselves be non-Graph
        // API calls, but must be limited to API calls which are batchable. Not all are, which is
        // why we won't piggyback on top of a REST API call.) Don't try this if the caller gave us
        // an already-formed request object, since we don't know its structure.
        BOOL safeForPiggyback = YES;
        for (GBRequestMetadata *requestMetadata in self.requests) {
            if (requestMetadata.request.restMethod) {
                safeForPiggyback = NO;
                break;
            }
        }
        // If we wouldn't be able to compute a batch_app_id, don't piggyback on this
        // request.
        NSString *batchAppID = [self getBatchAppID:self.requests];
        safeForPiggyback &= (batchAppID != nil) && (batchAppID.length > 0);

        if (safeForPiggyback) {
            [self addPiggybackRequests];
        }
    }

    // warning! this property is side-effecting (and should probably be refactored at some point...)
    // still, if we have made it this far and still don't have a request object, we need one now
    if (!request) {
        request = self.urlRequest;
    }

    NSAssert((self.state == kStateCreated) || (self.state == kStateSerialized),
             @"Cannot call start again after calling start or cancel.");
    self.state = kStateStarted;

    _requestStartTime = [GBUtility currentTimeInMilliseconds];

    if (!cachedData) {
        GBURLConnectionHandler handler =
        ^(GBURLConnection *connection,
          NSError *error,
          NSURLResponse *response,
          NSData *responseData) {
            // cache this data if we have successful response and a cache identity to work with
            if (cacheIdentityURL &&
                [response isKindOfClass:[NSHTTPURLResponse class]] &&
                ((NSHTTPURLResponse*)response).statusCode == 200) {
                [[GBDataDiskCache sharedCache] setData:responseData
                                                forURL:cacheIdentityURL];
            }
            // complete on result from round-trip to server
            [self completeWithResponse:response
                                  data:responseData
                               orError:error];
        };

        id<GBRequestDelegate> deprecatedDelegate = [self.deprecatedRequest delegate];
        if ([deprecatedDelegate respondsToSelector:@selector(requestLoading:)]) {
            [deprecatedDelegate requestLoading:self.deprecatedRequest];
        }

        [self startURLConnectionWithRequest:request skipRoundTripIfCached:NO completionHandler:handler];
    } else {
        _isResultFromCache = YES;

        // complete on result from cache
        [self completeWithResponse:nil
                              data:cachedData
                           orError:nil];

    }
}

- (void)startURLConnectionWithRequest:(NSURLRequest *)request
                skipRoundTripIfCached:(BOOL)skipRoundTripIfCached
                    completionHandler:(GBURLConnectionHandler) handler {
    GBURLConnection *connection = [[self newGBURLConnection] initWithRequest:request
                                                          skipRoundTripIfCached:skipRoundTripIfCached
                                                              completionHandler:handler];
    self.connection = connection;
    [connection release];
}

- (GBURLConnection *)newGBURLConnection {
    return [GBURLConnection alloc];
}

//
// Generates a NSURLRequest based on the contents of self.requests, and sets
// options on the request.  Chooses between URL-based request for a single
// request and JSON-based request for batches.
//
- (NSMutableURLRequest *)requestWithBatch:(NSArray *)requests
                                  timeout:(NSTimeInterval)timeout
{
    GBRequestBody *body = [[GBRequestBody alloc] init];
    GBLogger *bodyLogger = [[GBLogger alloc] initWithLoggingBehavior:_logger.loggingBehavior];
    GBLogger *attachmentLogger = [[GBLogger alloc] initWithLoggingBehavior:_logger.loggingBehavior];

    NSMutableURLRequest *request;

    if (requests.count == 0) {
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBRequestConnection: Must have at least one request or urlRequest not specified."
                               userInfo:nil]
         raise];

    }

    if ([requests count] == 1) {
        GBRequestMetadata *metadata = [requests objectAtIndex:0];
        NSURL *url = [NSURL URLWithString:[self urlStringForSingleRequest:metadata.request forBatch:NO]];
        request = [NSMutableURLRequest requestWithURL:url
                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                      timeoutInterval:timeout];

        // HTTP methods are case-sensitive; be helpful in case someone provided a mixed case one.
        NSString *httpMethod = [metadata.request.HTTPMethod uppercaseString];
        [request setHTTPMethod:httpMethod];
        [self appendAttachments:metadata.request.parameters
                         toBody:body
                    addFormData:[httpMethod isEqualToString:@"POST"]
                         logger:attachmentLogger];

        // if we have a post object, also roll that into the body
        if (metadata.request.graphObject) {
            [GBRequestConnection processGraphObject:metadata.request.graphObject
                                            forPath:[url path]
                                                withAction:^(NSString *key, id value) {
                [body appendWithKey:key formValue:value logger:bodyLogger];
            }];
        }
    } else {
        // Find the session with an app ID and use that as the batch_app_id. If we can't
        // find one, try to load it from the plist. As a last resort, pass 0.
        NSString *batchAppID = [self getBatchAppID:requests];
        if (!batchAppID || batchAppID.length == 0) {
            // The Graph API batch method requires either an access token or batch_app_id.
            // If we can't determine an App ID to use for the batch, we can't issue it.
            [[NSException exceptionWithName:GBInvalidOperationException
                                     reason:@"GBRequestConnection: At least one request in a"
                                             " batch must have an open GBSession, or a default"
                                             " app ID must be specified."
                                   userInfo:nil]
             raise];
        }

        [body appendWithKey:@"batch_app_id" formValue:batchAppID logger:bodyLogger];

        NSMutableDictionary *attachments = [[NSMutableDictionary alloc] init];

        [self appendJSONRequests:requests
                          toBody:body
              andNameAttachments:attachments
                          logger:bodyLogger];

        [self appendAttachments:attachments
                         toBody:body
                    addFormData:NO
                         logger:attachmentLogger];

        [attachments release];

        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[GBUtility buildGbombUrlWithPre:gbGraphURLPrefix]]
                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                      timeoutInterval:timeout];
        [request setHTTPMethod:@"POST"];
    }

    [request setHTTPBody:[body data]];
    NSUInteger bodyLength = [[body data] length] / 1024;
    [body release];

    [request setValue:[GBRequestConnection userAgent] forHTTPHeaderField:@"User-Agent"];
    [request setValue:[GBRequestBody mimeContentType] forHTTPHeaderField:@"Content-Type"];

    [self logRequest:request bodyLength:bodyLength bodyLogger:bodyLogger attachmentLogger:attachmentLogger];

    // Safely release now that everything's serialized into the logger.
    [bodyLogger release];
    [attachmentLogger release];

    return request;
}

- (void)logRequest:(NSMutableURLRequest *)request
        bodyLength:(NSUInteger)bodyLength
        bodyLogger:(GBLogger *)bodyLogger
  attachmentLogger:(GBLogger *)attachmentLogger
{
    if (_logger.isActive) {
        [_logger appendFormat:@"Request <#%lu>:\n", (unsigned long)_logger.loggerSerialNumber];
        [_logger appendKey:@"URL" value:[[request URL] absoluteString]];
        [_logger appendKey:@"Method" value:[request HTTPMethod]];
        [_logger appendKey:@"UserAgent" value:[request valueForHTTPHeaderField:@"User-Agent"]];
        [_logger appendKey:@"MIME" value:[request valueForHTTPHeaderField:@"Content-Type"]];

        if (bodyLength != 0) {
            [_logger appendKey:@"Body Size" value:[NSString stringWithFormat:@"%lu kB", (unsigned long)bodyLength / 1024]];
        }

        if (bodyLogger != nil) {
            [_logger appendKey:@"Body (w/o attachments)" value:bodyLogger.contents];
        }

        if (attachmentLogger != nil) {
            [_logger appendKey:@"Attachments" value:attachmentLogger.contents];
        }

        [_logger appendString:@"\n"];

        [_logger emitToNSLog];
    }
}

//
// Generates a URL for a batch containing only a single request,
// and names all attachments that need to go in the body of the
// request.
//
// The URL contains all parameters that are not body attachments,
// including the session key if present.
//
// Attachments are named and referenced by name in the URL.
//
- (NSString *)urlStringForSingleRequest:(GBRequest *)request forBatch:(BOOL)forBatch
{
    [request.parameters setValue:@"json" forKey:@"format"];
    [request.parameters setValue:gbSDK forKey:@"sdk"];
    NSString *token = request.session.accessTokenData.accessToken;
    if (token) {
        [request.parameters setValue:token forKey:gbAccessTokenKey];
        [self registerTokenToOmitFromLog:token];
    }

    NSString *baseURL;
    if (request.restMethod) {
        if (forBatch) {
            baseURL = [gbBatchRestMethodBaseURL stringByAppendingString:request.restMethod];
        } else {
            baseURL = [[GBUtility buildGbombUrlWithPre:gbApiURLPrefix withPost:@"/method/"] stringByAppendingString:request.restMethod];
        }
    } else {
        if (forBatch) {
            baseURL = request.graphPath;
        } else {
            NSString *prefix = gbGraphURLPrefix;
            // We special case a graph post to <id>/videos and send it to graph-video.facebook.com
            // We only do this for non batch post requests
            if ([[request.HTTPMethod uppercaseString] isEqualToString:@"POST"] &&
                [[request.graphPath lowercaseString] hasSuffix:@"/videos"]) {
                NSArray *components = [request.graphPath componentsSeparatedByString:@"/"];
                if ([components count] == 2) {
                    prefix = gbGraphVideoURLPrefix;
                }
            }
            baseURL = [[GBUtility buildGbombUrlWithPre:prefix withPost:@"/"] stringByAppendingString:request.graphPath];
        }
    }

    NSString *url = [GBRequest serializeURL:baseURL
                                     params:request.parameters
                                 httpMethod:request.HTTPMethod];
    return url;
}

// Find the first session with an app ID and use that as the batch_app_id. If we can't
// find one, return the default app ID (which may still be nil if not specified
// programmatically or via the plist).
- (NSString *)getBatchAppID:(NSArray*)requests
{
    for (GBRequestMetadata *metadata in requests) {
        if (metadata.request.session.appID.length > 0) {
            return metadata.request.session.appID;
        }
    }
    return [GBSettings defaultAppID];
}

//
// Serializes all requests in the batch to JSON and appends the result to
// body.  Also names all attachments that need to go as separate blocks in
// the body of the request.
//
// All the requests are serialized into JSON, with any binary attachments
// named and referenced by name in the JSON.
//
- (void)appendJSONRequests:(NSArray *)requests
                    toBody:(GBRequestBody *)body
        andNameAttachments:(NSMutableDictionary *)attachments
                    logger:(GBLogger *)logger
{
    NSMutableArray *batch = [[NSMutableArray alloc] init];
    for (GBRequestMetadata *metadata in requests) {
        [self addRequest:metadata
                 toBatch:batch
             attachments:attachments];
    }

    NSString *jsonBatch = [GBUtility simpleJSONEncode:batch];

    [batch release];

    [body appendWithKey:gbBatchKey formValue:jsonBatch logger:logger];
}

//
// Adds request data to a batch in a format expected by the JsonWriter.
// Binary attachments are referenced by name in JSON and added to the
// attachments dictionary.
//
- (void)addRequest:(GBRequestMetadata *)metadata
           toBatch:(NSMutableArray *)batch
       attachments:(NSDictionary *)attachments
{
    NSMutableDictionary *requestElement = [[[NSMutableDictionary alloc] init] autorelease];

    if (metadata.batchParameters) {
        [requestElement addEntriesFromDictionary:metadata.batchParameters];
    }

    NSString *token = metadata.request.session.accessTokenData.accessToken;
    if (token) {
        [metadata.request.parameters setObject:token forKey:gbAccessTokenKey];
        [self registerTokenToOmitFromLog:token];
    }

    NSString *urlString = [self urlStringForSingleRequest:metadata.request forBatch:YES];
    [requestElement setObject:urlString forKey:gbBatchRelativeURLKey];
    [requestElement setObject:metadata.request.HTTPMethod forKey:gbBatchMethodKey];

    NSMutableString *attachmentNames = [NSMutableString string];

    for (id key in [metadata.request.parameters keyEnumerator]) {
        NSObject *value = [metadata.request.parameters objectForKey:key];
        if ([self isAttachment:value]) {
            NSString *name = [NSString stringWithFormat:@"%@%lu",
                              gbBatchFileNamePrefix,
                              (unsigned long)[attachments count]];
            if ([attachmentNames length]) {
                [attachmentNames appendString:@","];
            }
            [attachmentNames appendString:name];
            [attachments setValue:value forKey:name];
        }
    }

    // if we have a post object, also roll that into the body
    if (metadata.request.graphObject) {
        NSMutableString *bodyValue = [[[NSMutableString alloc] init] autorelease];
        __block NSString *delimiter = @"";
        [GBRequestConnection
         processGraphObject:metadata.request.graphObject
                    forPath:urlString
         withAction:^(NSString *key, id value) {
             // escape the value
             value = [GBUtility stringByURLEncodingString:[value description]];
             [bodyValue appendFormat:@"%@%@=%@",
              delimiter,
              key,
              value];
             delimiter = @"&";
         }];
        [requestElement setObject:bodyValue forKey:@"body"];
    }

    if ([attachmentNames length]) {
        [requestElement setObject:attachmentNames forKey:gbBatchAttachmentKey];
    }

    [batch addObject:requestElement];
}

- (BOOL)isAttachment:(id)item
{
    return
        [item isKindOfClass:[UIImage class]] ||
        [item isKindOfClass:[NSData class]];
}

- (void)appendAttachments:(NSDictionary *)attachments
                   toBody:(GBRequestBody *)body
              addFormData:(BOOL)addFormData
                   logger:(GBLogger *)logger
{
    // key is name for both, first case is string which we can print, second pass grabs object
    if (addFormData) {
        for (NSString *key in [attachments keyEnumerator]) {
            NSObject *value = [attachments objectForKey:key];
            if ([value isKindOfClass:[NSString class]]) {
                [body appendWithKey:key formValue:(NSString *)value logger:logger];
            }
        }
    }

    for (NSString *key in [attachments keyEnumerator]) {
        NSObject *value = [attachments objectForKey:key];
        if ([value isKindOfClass:[UIImage class]]) {
            [body appendWithKey:key imageValue:(UIImage *)value logger:logger];
        } else if ([value isKindOfClass:[NSData class]]) {
            [body appendWithKey:key dataValue:(NSData *)value logger:logger];
        }
    }
}

#pragma mark Graph Object serialization

+ (void)processGraphObjectPropertyKey:(NSString*)key
                                value:(id)value
                               action:(KeyValueActionHandler)action
                          passByValue:(BOOL)passByValue {
    if ([value conformsToProtocol:@protocol(GBGraphObject)]) {
        NSDictionary<GBGraphObject> *refObject = (NSDictionary<GBGraphObject>*)value;

        if (refObject.provisionedForPost) {
            NSString *value = [GBUtility simpleJSONEncode:refObject];
            action(key, value);
        } else if (passByValue) {
            // We need to pass all properties of this object in key[propertyName] format.
            for (NSString *propertyName in refObject) {
                NSString *subKey = [NSString stringWithFormat:@"%@[%@]", key, propertyName];
                id subValue = [refObject objectForKey:propertyName];
                // Note that passByValue is not inherited by subkeys.
                [self processGraphObjectPropertyKey:subKey value:subValue action:action passByValue:NO];
            }
        } else {
            // Normal case is passing objects by reference, so just pass the ID or URL, if any.
            NSString *subValue;
            if ((subValue = [refObject objectForKey:@"id"])) {          // GBid
                if ([subValue isKindOfClass:[NSDecimalNumber class]]) {
                    subValue = [(NSDecimalNumber*)subValue stringValue];
                }
                action(key, subValue);
            } else if ((subValue = [refObject objectForKey:@"url"])) {  // canonical url (external)
                action(key, subValue);
            }
        }
    } else if ([value isKindOfClass:[NSString class]] ||
               [value isKindOfClass:[NSNumber class]]) {
        // Just serialize these.
        action(key, value);
    } else if ([value isKindOfClass:[NSArray class]]) {
        // Arrays are serialized as multiple elements with keys of the
        // form key[0], key[1], etc.
        NSArray *array = (NSArray*)value;
        NSUInteger count = array.count;
        for (NSUInteger i = 0; i < count; ++i) {
            NSString *subKey = [NSString stringWithFormat:@"%@[%lu]", key, (unsigned long)i];
            id subValue = [array objectAtIndex:i];
            [self processGraphObjectPropertyKey:subKey value:subValue action:action passByValue:passByValue];
        }
    }
}

+ (void)processGraphObject:(id<GBGraphObject>)object forPath:(NSString*)path withAction:(KeyValueActionHandler)action {
    BOOL isOGAction = NO;
    if ([path hasPrefix:@"me/"] ||
        [path hasPrefix:@"/me/"]) {
        // In general, graph objects are passed by reference (ID/URL). But if this is an OG Action,
        // we need to pass the entire values of the contents of the 'image' property, as they
        // contain important metadata beyond just a URL. We don't have a 100% foolproof way of knowing
        // if we are posting an OG Action, given that batched requests can have parameter substitution,
        // but passing the OG Action type as a substituted parameter is unlikely.
        // It looks like an OG Action if it's posted to me/namespace:action[?other=stuff].
        NSUInteger colonLocation = [path rangeOfString:@":"].location;
        NSUInteger questionMarkLocation = [path rangeOfString:@"?"].location;
        isOGAction = (colonLocation != NSNotFound && colonLocation > 3) &&
            (questionMarkLocation == NSNotFound || colonLocation < questionMarkLocation);
    }

    for (NSString *key in [object keyEnumerator]) {
        NSObject *value = [object objectForKey:key];
        BOOL passByValue = isOGAction && [key isEqualToString:@"image"];
        [self processGraphObjectPropertyKey:key value:value action:action passByValue:passByValue];
    }
}

#pragma mark -

- (void)completeWithResponse:(NSURLResponse *)response
                        data:(NSData *)data
                     orError:(NSError *)error
{
    if (self.state != kStateCancelled) {
        NSAssert(self.state == kStateStarted,
                 @"Unexpected state %d in completeWithResponse",
                 self.state);
        self.state = kStateCompleted;
    }

    NSInteger statusCode;
    if (response) {
        NSAssert([response isKindOfClass:[NSHTTPURLResponse class]],
                 @"Expected NSHTTPURLResponse, got %@",
                 response);
        self.urlResponse = (NSHTTPURLResponse *)response;
        statusCode = self.urlResponse.statusCode;

        if (!error && [response.MIMEType hasPrefix:@"image"]) {
            error = [self errorWithCode:GBErrorNonTextMimeTypeReturned
                             statusCode:0
                     parsedJSONResponse:nil
                             innerError:nil
                                message:@"Response is a non-text MIME type; endpoints that return images and other "
                                        @"binary data should be fetched using NSURLRequest and NSURLConnection"];
        }
    } else {
        // the cached case is always successful, from an http perspective
        statusCode = 200;
    }



    NSArray *results = nil;
    if (!error) {
        results = [self parseJSONResponse:data
                                    error:&error
                               statusCode:statusCode];
    }

    // the cached case has data but no response,
    // in which case we skip connection-related errors
    if (response || !data) {
        error = [self checkConnectionError:error
                                statusCode:statusCode
                        parsedJSONResponse:results];
    }

    if (!error) {
        if ([self.requests count] != [results count]) {
            [GBLogger singleShotLogEntry:GBLoggingBehaviorGBRequests formatString:@"Expected %lu results, got %lu",
                            (unsigned long)[self.requests count], (unsigned long)[results count]];
            error = [self errorWithCode:GBErrorProtocolMismatch
                             statusCode:statusCode
                     parsedJSONResponse:results
                             innerError:nil
                                message:nil];
        }
    }

    if (!error) {

        [_logger appendFormat:@"Response <#%lu>\nDuration: %lu msec\nSize: %lu kB\nResponse Body:\n%@\n\n",
         (unsigned long)[_logger loggerSerialNumber],
         [GBUtility currentTimeInMilliseconds] - _requestStartTime,
         (unsigned long)[data length],
         results];

    } else {

        [_logger appendFormat:@"Response <#%lu> <Error>:\n%@\n%@\n",
         (unsigned long)[_logger loggerSerialNumber],
         [error localizedDescription],
         [error userInfo]];

    }
    [_logger emitToNSLog];

    if (self.deprecatedRequest) {
        [self completeDeprecatedWithData:data results:results orError:error];
    } else {
        [self completeWithResults:results orError:error];
    }

    self.connection = nil;
    self.urlResponse = (NSHTTPURLResponse *)response;
}

//
// If there is one request, the JSON is the response.
// If there are multiple requests, the JSON has an array of dictionaries whose
// body property is the response.
//   [{ "code":200,
//      "body":"JSON-response-as-a-string" },
//    { "code":200,
//      "body":"JSON-response-as-a-string" }]
//
// In both cases, this function returns an NSArray containing the results.
// The NSArray looks just like the multiple request case except the body
// value is converted from a string to parsed JSON.
//
- (NSArray *)parseJSONResponse:(NSData *)data
                         error:(NSError **)error
                    statusCode:(NSInteger)statusCode;
{
    // Graph API can return "true" or "false", which is not valid JSON.
    // Translate that before asking JSON parser to look at it.
    NSString *responseUTF8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *results = nil;
    id response = [self parseJSONOrOtherwise:responseUTF8 error:error];

    if (*error) {
        // no-op
    } else if ([self.requests count] == 1) {
        // response is the entry, so put it in a dictionary under "body" and add
        // that to array of responses.
        NSMutableDictionary *result = [[[NSMutableDictionary alloc] init] autorelease];
        [result setObject:[NSNumber numberWithInteger:statusCode] forKey:@"code"];
        [result setObject:response forKey:@"body"];

        NSMutableArray *mutableResults = [[[NSMutableArray alloc] init] autorelease];
        [mutableResults addObject:result];
        results = mutableResults;
    } else if ([response isKindOfClass:[NSArray class]]) {
        // response is the array of responses, but the body element of each needs
        // to be decoded from JSON.
        NSMutableArray *mutableResults = [[[NSMutableArray alloc] init] autorelease];
        for (id item in response) {
            // Don't let errors parsing one response stop us from parsing another.
            NSError *batchResultError = nil;
            if (![item isKindOfClass:[NSDictionary class]]) {
                [mutableResults addObject:item];
            } else {
                NSDictionary *itemDictionary = (NSDictionary *)item;
                NSMutableDictionary *result = [[[NSMutableDictionary alloc] init] autorelease];
                for (NSString *key in [itemDictionary keyEnumerator]) {
                    id value = [itemDictionary objectForKey:key];
                    if ([key isEqualToString:@"body"]) {
                        id body = [self parseJSONOrOtherwise:value error:&batchResultError];
                        [result setObject:body forKey:key];
                    } else {
                        [result setObject:value forKey:key];
                    }
                }
                [mutableResults addObject:result];
            }
            if (batchResultError) {
                // We'll report back the last error we saw.
                *error = batchResultError;
            }
        }
        results = mutableResults;
    } else {
        *error = [self errorWithCode:GBErrorProtocolMismatch
                          statusCode:statusCode
                  parsedJSONResponse:results
                          innerError:nil
                             message:nil];
    }

    [responseUTF8 release];
    return results;
}

- (id)parseJSONOrOtherwise:(NSString *)utf8
                     error:(NSError **)error
{
    id parsed = nil;
    if (!(*error)) {
        parsed = [GBUtility simpleJSONDecode:utf8 error:error];
        // if we fail parse we attemp a reparse of a modified input to support results in the form "foo=bar", "true", etc.
        if (*error) {
            // we round-trip our hand-wired response through the parser in order to remain
            // consistent with the rest of the output of this function (note, if perf turns out
            // to be a problem -- unlikely -- we can return the following dictionary outright)
            NSDictionary *original = [NSDictionary dictionaryWithObjectsAndKeys:
                                      utf8, GBNonJSONResponseProperty,
                                      nil];
            NSString *jsonrep = [GBUtility simpleJSONEncode:original];
            NSError *reparseError = nil;
            parsed = [GBUtility simpleJSONDecode:jsonrep error:&reparseError];
            if (!reparseError) {
                *error = nil;
            }
        }
    }
    return parsed;
}

- (void)completeDeprecatedWithData:(NSData *)data
                           results:(NSArray *)results
                           orError:(NSError *)error
{
    id result = [results objectAtIndex:0];
    if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *resultDictionary = (NSDictionary *)result;
        result = [resultDictionary objectForKey:@"body"];
    }

    id<GBRequestDelegate> delegate = [self.deprecatedRequest delegate];

    if (!error) {
        if ([delegate respondsToSelector:@selector(request:didReceiveResponse:)]) {
            [delegate request:self.deprecatedRequest
                     didReceiveResponse:self.urlResponse];
        }
        if ([delegate respondsToSelector:@selector(request:didLoadRawResponse:)]) {
            [delegate request:self.deprecatedRequest didLoadRawResponse:data];
        }

        error = [self errorFromResult:result];
    }

    if (!error) {
        if ([delegate respondsToSelector:@selector(request:didLoad:)]) {
            [delegate request:self.deprecatedRequest didLoad:result];
        }
    } else {
        if ([self isInvalidSessionError:error resultIndex:0]) {
            [self.deprecatedRequest setSessionDidExpire:YES];
            [self.deprecatedRequest.session close];
        }

        [self.deprecatedRequest setError:error];
        if ([delegate respondsToSelector:@selector(request:didFailWithError:)]) {
            [delegate request:self.deprecatedRequest didFailWithError:error];
        }
    }
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [self.deprecatedRequest setState:kGBRequestStateComplete];
#pragma GCC diagnostic pop
}

- (NSError*) unpackIndividualJSONResponseError:(NSError *)itemError {
    // task #1256476: in the current implementation, GBErrorParsedJSONResponseKey has two
    // semantics; both of which are used by the implementation; the right fix is to break the meaning into
    // two throughout, and surface both in the public API; the following fix is a lower risk and also
    // less correct solution that improves the public API surface for this release
    // Unpack GBErrorParsedJSONResponseKey array if present
    id parsedResponse;
    if ((parsedResponse = itemError.userInfo) && // do we have an error with userInfo
        (parsedResponse = [parsedResponse objectForKey:GBErrorParsedJSONResponseKey]) && // response present?
        ([parsedResponse isKindOfClass:[NSArray class]])) { // array?
        id newValue = nil;
        // if we successfully spelunk this far, then we don't want to return GBErrorParsedJSONResponseKey as is
        // but if there is an empty array here, then we are better off nil-ing the key
        if ([parsedResponse count]) {
            newValue = [parsedResponse objectAtIndex:0];
        }
        itemError = [self errorWithCode:(GBErrorCode)itemError.code
                             statusCode:[[itemError.userInfo objectForKey:GBErrorHTTPStatusCodeKey] intValue]
                     parsedJSONResponse:newValue
                             innerError:[itemError.userInfo objectForKey:GBErrorInnerErrorKey]
                                message:[itemError.userInfo objectForKey:NSLocalizedDescriptionKey]];
    }
    return itemError;

}

// Helper method to determine if GBRequestConnection should close
// the session for a given GBRequest.
- (BOOL) shouldCloseRequestSession:(GBRequest *)request {
    // We don't close requests whose session is being repaired
    // since the repair resolution is now responsible for
    // either maintaining the session or closing it.
    return request.canCloseSessionOnError && !request.session.isRepairing;
}

- (void)completeWithResults:(NSArray *)results
                    orError:(NSError *)error
{
    // set up a new retry manager for this flow.
    self.retryManager = [[[GBRequestConnectionRetryManager alloc] initWithGBRequestConnection:self] autorelease];

    NSUInteger count = [self.requests count];
    NSMutableArray *tasks = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < count; i++) {
        GBRequestMetadata *metadata = [self.requests objectAtIndex:i];
        id result = error ? nil : [results objectAtIndex:i];
        NSError *itemError = error ? error : [self errorFromResult:result];

        // Describes the cleaned up NSError to return back to callbacks.
        NSError *unpackedError = [self unpackIndividualJSONResponseError:itemError];

        id body = nil;
        if (!itemError && [result isKindOfClass:[NSDictionary class]]) {
            NSDictionary *resultDictionary = (NSDictionary *)result;
            body = [GBGraphObject graphObjectWrappingDictionary:[resultDictionary objectForKey:@"body"]];
        }

        NSUInteger resultIndex = error == itemError ? i : 0;
        GBTask *taskWork = [GBTask taskWithResult:nil];
        GBSystemAccountStoreAdapter *systemAccountStoreAdapter = [GBSystemAccountStoreAdapter sharedInstance];

        if ((metadata.request.session.accessTokenData.loginType == GBSessionLoginTypeSystemAccount) &&
            [self isInsufficientPermissionError:error resultIndex:resultIndex]) {
            // if we lack permissions, use this as a cue to refresh the
            // OS's understanding of current permissions
            taskWork = [taskWork dependentTaskWithBlock:^id(GBTask *task) {
                return [systemAccountStoreAdapter renewSystemAuthorizationAsTask];
            } queue:dispatch_get_main_queue()];
        } else if ([self isInvalidSessionError:itemError resultIndex:resultIndex]) {
            if (metadata.request.session.accessTokenData.loginType == GBSessionLoginTypeSystemAccount){
                // For system auth, there are a number of edge cases we pre-process before
                // closing the session.

                if ([self isExpiredTokenError:itemError resultIndex:resultIndex]
                    && systemAccountStoreAdapter.canRequestAccessWithoutUI) {
                    // If token is expired and iOS says user has granted permissions
                    // we can simply renew the token and flip the error to a retry.

                    taskWork = [taskWork dependentTaskWithBlock:^id(GBTask *task) {
                        return [systemAccountStoreAdapter renewSystemAuthorizationAsTask];
                    } queue:dispatch_get_main_queue()];

                    taskWork = [taskWork completionTaskWithQueue:dispatch_get_main_queue() block:^id(GBTask *task) {
                        if (task.result == ACAccountCredentialRenewResultRenewed) {
                            GBTask *requestAccessTask = [systemAccountStoreAdapter requestAccessToFacebookAccountStoreAsTask:metadata.request.session];
                            return [requestAccessTask completionTaskWithQueue:dispatch_get_main_queue() block:^id(GBTask *task) {
                                if (task.result) { // aka success means task.result ==  (oauthToken)
                                    [metadata.request.session refreshAccessToken:task.result expirationDate:[NSDate distantFuture]];
                                    [metadata invokeCompletionHandlerForConnection:self
                                                                       withResults:body
                                                                             error:[GBErrorUtility gberrorForRetry:unpackedError]];
                                    return [GBTask cancelledTask];
                                }
                                return [GBTask taskWithError:nil];
                            }];
                        }
                        return [GBTask taskWithError:nil];
                    }];
                } else if ([self isPasswordChangeError:itemError resultIndex:resultIndex]) {
                    // For iOS6, when the password is changed on the server, the system account store
                    // will continue to issue the old token until the user has changed the
                    // password AND _THEN_ a renew call is made. To prevent opening
                    // with an old token which would immediately be closed, we tell our adapter
                    // that we want to force a blocking renew until success.
                    [GBSystemAccountStoreAdapter sharedInstance].forceBlockingRenew = YES;
                } else {
                    // For other invalid session cases, we can simply issue the renew now
                    // to update the system account's world view.
                    taskWork = [taskWork dependentTaskWithBlock:^id(GBTask *task) {
                        return [systemAccountStoreAdapter renewSystemAuthorizationAsTask];
                    } queue:dispatch_get_main_queue()];
                }
            }
            // Invalid session case, should close the session at end of this if block
            // unless we signified not to earlier via a task cancellation.
            taskWork = [taskWork dependentTaskWithBlock:^id(GBTask *task) {
                if (task.isCancelled) {
                    return task;
                }
                if ([self shouldCloseRequestSession:metadata.request]) {
                    [metadata.request.session closeAndClearTokenInformation:unpackedError];
                }
                return [GBTask taskWithResult:nil];
            } queue:dispatch_get_main_queue()];
        } else if ([metadata.request.session shouldExtendAccessToken]) {
            // If we have not had the opportunity to piggyback a token-extension request,
            // but we need to, do so now as a separate request.
            taskWork = [taskWork dependentTaskWithBlock:^id(GBTask *task) {
                GBRequestConnection *connection = [[GBRequestConnection alloc] init];
                [GBRequestConnection addRequestToExtendTokenForSession:metadata.request.session
                                                            connection:connection];
                [connection start];
                [connection release];
                return [GBTask taskWithResult:nil];
            } queue:dispatch_get_main_queue()];
        }

        // Always invoke handler at the end.
        taskWork = [taskWork dependentTaskWithBlock:^id(GBTask *task) {
            if (task.isCancelled) {
                return task;
            }
            [metadata invokeCompletionHandlerForConnection:self withResults:body error:unpackedError];
            return [GBTask taskWithResult:nil];
        } queue:dispatch_get_main_queue()];
        [tasks addObject:taskWork];
    } //end for loop


    GBTask *finalTask = [GBTask taskDependentOnTasks:tasks];
    [finalTask dependentTaskWithBlock:^id(GBTask *task) {
        [self.retryManager performRetries];
        return [GBTask taskWithResult:nil];
    } queue:dispatch_get_main_queue()];
    [tasks release];
}

- (NSError *)errorFromResult:(id)idResult
{
    if ([idResult isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)idResult;

        if ([dictionary objectForKey:@"error"] ||
            [dictionary objectForKey:@"error_code"] ||
            [dictionary objectForKey:@"error_msg"] ||
            [dictionary objectForKey:@"error_reason"]) {

            NSMutableDictionary *userInfo = [[[NSMutableDictionary alloc] init] autorelease];
            [userInfo addEntriesFromDictionary:dictionary];
            return [self errorWithCode:GBErrorRequestConnectionApi
                            statusCode:200
                    parsedJSONResponse:idResult
                            innerError:nil
                               message:nil];
        }

        NSNumber *code = [dictionary valueForKey:@"code"];
        if (code) {
            return [self checkConnectionError:nil
                                   statusCode:[code intValue]
                           parsedJSONResponse:idResult];
        }
    }

    return nil;
}

- (NSError *)errorWithCode:(GBErrorCode)code
                statusCode:(NSInteger)statusCode
        parsedJSONResponse:(id)response
                innerError:(NSError*)innerError
                   message:(NSString*)message {
    NSMutableDictionary *userInfo = [[[NSMutableDictionary alloc] init] autorelease];
    [userInfo setObject:[NSNumber numberWithInteger:statusCode] forKey:GBErrorHTTPStatusCodeKey];

    if (response) {
        userInfo[GBErrorParsedJSONResponseKey] = response;
    }

    if (innerError) {
        userInfo[GBErrorInnerErrorKey] = innerError;
    }

    if (message) {
        userInfo[NSLocalizedDescriptionKey] = message;
    }

    // if we only have one session (possibly more than once) in this batch, stuff it in the error,
    // otherwise it is a more advanced batch and the app is responsible for handling error state
    GBSession *session = nil;
    for (GBRequestMetadata *requestMetadata in self.requests) {
        if (requestMetadata.request.session) {
            if (!session) {
                session = requestMetadata.request.session;
            } else if (session != requestMetadata.request.session) {
                session = nil; // two sessions in a batch, no clear reporting policy here
                break;
            }
        }
    }

    if (session) {
        userInfo[GBErrorSessionKey] = session;
    }

    NSError *error = [[[NSError alloc]
                       initWithDomain:GbombSDKDomain
                       code:code
                       userInfo:userInfo]
                      autorelease];

    return error;
}

- (NSError *)checkConnectionError:(NSError *)innerError
                       statusCode:(NSInteger)statusCode
               parsedJSONResponse:response
{
    // We don't want to re-wrap our own errors.
    if (innerError &&
        [innerError.domain isEqualToString:GbombSDKDomain]) {
        return innerError;
    }
    NSError *result = nil;
    if (innerError || ((statusCode < 200) || (statusCode >= 300))) {
        [GBLogger singleShotLogEntry:GBLoggingBehaviorGBRequests formatString:@"Error: HTTP status code: %lu", (unsigned long)statusCode];
        result = [self errorWithCode:GBErrorHTTPError
                          statusCode:statusCode
                  parsedJSONResponse:response
                          innerError:innerError
                             message:nil];
    }
    return result;
}

- (BOOL)isInsufficientPermissionError:(NSError *)error
                          resultIndex:(NSUInteger)index {
    int code;
    [GBErrorUtility gberrorGetCodeValueForError:error
                                   index:index
                                    code:&code
                                 subcode:nil];
    return code == gbRESTAPIPermissionErrorCode;
}

- (BOOL)isInvalidSessionError:(NSError *)error
                  resultIndex:(NSUInteger)index {
    // Please note the retry behaviors in GBRequestHandlerFactory are coupled
    // to the GBRequestConnection invalid session behavior, so any changes
    // to conditions that trigger `closeAndClearTokenInformation` will probably
    // need to replicate to the GBRequestHandlerFactory.
    int code = 0, subcode = 0;
    [GBErrorUtility gberrorGetCodeValueForError:error
                                          index:index
                                           code:&code
                                        subcode:&subcode];

    return [GBErrorUtility gberrorCategoryFromError:error
                                               code:code
                                            subcode:subcode
                               returningUserMessage:nil
                                andShouldNotifyUser:nil] == GBErrorCategoryAuthenticationReopenSession;
}

- (BOOL)isPasswordChangeError:(NSError *)error
                  resultIndex:(NSUInteger)index {
    int code = 0, subcode = 0;
    [GBErrorUtility gberrorGetCodeValueForError:error
                                          index:index
                                           code:&code
                                        subcode:&subcode];

    [GBErrorUtility gberrorCategoryFromError:error
                                        code:code
                                     subcode:subcode
                        returningUserMessage:nil
                         andShouldNotifyUser:nil];
    return subcode == GBAuthSubcodePasswordChanged;
}

- (BOOL)isExpiredTokenError:(NSError *)error
                resultIndex:(NSUInteger)index {
    int code = 0, subcode = 0;
    [GBErrorUtility gberrorGetCodeValueForError:error
                                          index:index
                                           code:&code
                                        subcode:&subcode];

    [GBErrorUtility GBerrorCategoryFromError:error
                                        code:code
                                     subcode:subcode
                        returningUserMessage:nil
                         andShouldNotifyUser:nil];
    return subcode == GBAuthSubcodeExpired;
}

- (void)registerTokenToOmitFromLog:(NSString *)token
{
    if (![[GBSettings loggingBehavior] containsObject:GBLoggingBehaviorAccessTokens]) {
        [GBLogger registerStringToReplace:token replaceWith:@"ACCESS_TOKEN_REMOVED"];
    }
}

+ (NSString *)userAgent
{
    static NSString *agent = nil;

    if (!agent) {
        agent = [[NSString stringWithFormat:@"%@.%@", gbUserAgentBase, GB_IOS_SDK_VERSION_STRING] retain];
    }

    return agent;
}

- (void)addPiggybackRequests
{
    // Get the set of sessions used by our requests
    NSMutableSet *sessions = [[NSMutableSet alloc] init];
    for (GBRequestMetadata *requestMetadata in self.requests) {
        // Have we seen this session yet? If not, assume we'll extend its token if it wants us to.
        if (requestMetadata.request.session) {
            [sessions addObject:requestMetadata.request.session];
        }
    }

    for (GBSession *session in sessions) {
        if (self.requests.count >= gbMaximumBatchSize) {
            break;
        }
        if ([session shouldExtendAccessToken]) {
            [GBRequestConnection addRequestToExtendTokenForSession:session connection:self];
        }
        if (self.requests.count < gbMaximumBatchSize && [session shouldRefreshPermissions]) {
            [GBRequestConnection addRequestToRefreshPermissionsSession:session connection:self];
        }
    }

    [sessions release];
}

+ (void)addRequestToExtendTokenForSession:(GBSession*)session connection:(GBRequestConnection*)connection
{
    GBRequest *request = [[GBRequest alloc] initWithSession:session
                                                 restMethod:gbExtendTokenRestMethod
                                                 parameters:nil
                                                 HTTPMethod:nil];
    [connection addRequest:request
         completionHandler:^(GBRequestConnection *connection, id result, NSError *error) {
             // extract what we care about
             id token = [result objectForKey:@"access_token"];
             id expireTime = [result objectForKey:@"expires_at"];

             // if we have a token and it is not a string (?) punt
             if (token && ![token isKindOfClass:[NSString class]]) {
                 expireTime = nil;
             }

             // get a date if possible
             NSDate *expirationDate = nil;
             if (expireTime) {
                 NSTimeInterval timeInterval = [expireTime doubleValue];
                 if (timeInterval != 0) {
                     expirationDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
                 }
             }

             // if we ended up with at least a date (and maybe a token) refresh the session token
             if (expirationDate) {
                 [session refreshAccessToken:token
                              expirationDate:expirationDate];
             }
         }];
    [request release];
}

+ (void)addRequestToRefreshPermissionsSession:(GBSession*)session connection:(GBRequestConnection*)connection {
    GBRequest *request = [[GBRequest alloc] initWithSession:session graphPath:@"me/permissions"];
    request.canCloseSessionOnError = NO;

    [connection addRequest:request
         completionHandler:^(GBRequestConnection *connection, id result, NSError *error) {
             if (!error && [result isKindOfClass:[NSDictionary class] ]) {
                 NSArray *resultData = result[@"data"];
                 if (resultData.count > 0) {
                     NSDictionary *permissionsDictionary = resultData[0];
                     id permissions = [permissionsDictionary allKeys];
                     if (permissions && [permissions isKindOfClass:[NSArray class]]) {
                         [session refreshPermissions:permissions];
                     }
                 }
             }
         }];
    [request release];
}

// Helper method to map a request to its metadata instance.
- (GBRequestMetadata *) getRequestMetadata:(GBRequest *)request {
    for (GBRequestMetadata *metadata in self.requests) {
        if (metadata.request == request) {
            return metadata;
        }
    }
    return nil;
}

#pragma mark Debugging helpers

- (NSString*)description {
    NSMutableString *result = [NSMutableString stringWithFormat:@"<%@: %p, %lu request(s): (\n",
                               NSStringFromClass([self class]),
                               self,
                               (unsigned long)self.requests.count];
    BOOL comma = NO;
    for (GBRequestMetadata *metadata in self.requests) {
        GBRequest *request = metadata.request;
        if (comma) {
            [result appendString:@",\n"];
        }
        [result appendString:[request description]];
        comma = YES;
    }
    [result appendString:@"\n)>"];
    return result;

}

#pragma mark -

@end
