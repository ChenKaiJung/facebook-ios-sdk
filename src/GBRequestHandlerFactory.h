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

// Internal only factory class to curry GBRequestHandlers to provide various
// error handling behaviors. See `GBRequestConnection.errorBehavior`
// and `GBRequestConnectionRetryManager` for details.

// Essentially this currying approach offers the flexibility of chaining work internally while
// maintaining the existing surface area of request handlers. In the future this could easily
// be replaced by an actual Promises/Deferred framework (or even provide a responder object param
// to the GBRequestHandler callback for even more extensibility)
@interface GBRequestHandlerFactory : NSObject

+(GBRequestHandler) handlerThatRetries:(GBRequestHandler )handler forRequest:(GBRequest* )request;
+(GBRequestHandler) handlerThatReconnects:(GBRequestHandler )handler forRequest:(GBRequest* )request;
+(GBRequestHandler) handlerThatAlertsUser:(GBRequestHandler )handler forRequest:(GBRequest* )request;

@end
