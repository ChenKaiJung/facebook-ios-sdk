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

// Defines the maximum number of retries for the GBRequestConnectionErrorBehaviorRetry.
extern const int GBREQUEST_DEFAULT_MAX_RETRY_LIMIT;

// Internal only class to facilitate GBRequest processing, specifically
// associating GBRequest and GBRequestHandler instances and necessary
// data for retry processing.
@interface GBRequestMetadata : NSObject

@property (nonatomic, retain) GBRequest *request;
@property (nonatomic, copy) GBRequestHandler completionHandler;
@property (nonatomic, copy) NSDictionary *batchParameters;
@property (nonatomic, assign) GBRequestConnectionErrorBehavior behavior;
@property (nonatomic, copy) GBRequestHandler originalCompletionHandler;

@property (nonatomic, assign) int retryCount;
@property (nonatomic, retain) id originalResult;
@property (nonatomic, retain) NSError* originalError;

- (id) initWithRequest:(GBRequest *)request
     completionHandler:(GBRequestHandler)handler
       batchParameters:(NSDictionary *)batchParameters
              behavior:(GBRequestConnectionErrorBehavior) behavior;

- (void)invokeCompletionHandlerForConnection:(GBRequestConnection *)connection
                                 withResults:(id)results
                                       error:(NSError *)error;
@end
