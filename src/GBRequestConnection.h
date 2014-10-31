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

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "GBGraphObject.h"

// up-front decl's
@class GBRequest;
@class GBRequestConnection;
@class GBSession;
@class UIImage;


/*!
 @attribute beta true

 @typedef GBRequestConnectionErrorBehavior enum

 @abstract Describes what automatic error handling behaviors to provide (if any).

 @discussion This is a bitflag enum that can be composed of different values.

     See GBError.h and GBErrorUtility.h for error category and user message details.
 */
typedef enum {
    /*! The default behavior of none */
    GBRequestConnectionErrorBehaviorNone                   = 0,

    /*! This will retry any requests whose error category is classified as `GBErrorCategoryRetry`.
     If the retry fails, the normal handler is invoked. */
    GBRequestConnectionErrorBehaviorRetry                  = 1,

    /*! This will automatically surface any SDK provided userMessage (at most one), after
     retry attempts, but before any reconnects are tried. The alert will have one button
     whose text can be localized with the key "GBE:AlertMessageButton".

     You should not display your own alert views in your request handler when specifying this
     behavior.
     */
    GBRequestConnectionErrorBehaviorAlertUser              = 2,

    /*! This will automatically reconnect a session if the request failed due to an invalid token
     that would otherwise close the session (such as an expired token or password change). Note
     this will NOT reconnect a session if the user had uninstalled the app, or if the user had
     disabled the app's slider in their privacy settings (in cases of iOS 6 system auth).
     If the session is reconnected, this will transition the session state to GBSessionStateTokenExtended
     which will invoke any state change handlers. Otherwise, the session is closed as normal.

     This behavior should not be used if the GBRequestConnection contains multiple
     session instances. Further, when this behavior is used, you must not request new permissions
     for the session until the connection is completed.

     Lastly, you should avoid using additional GBRequestConnections with the same session because
     that will be subject to race conditions.
     */
    GBRequestConnectionErrorBehaviorReconnectSession     = 4,
} GBRequestConnectionErrorBehavior;

/*!
 Normally requests return JSON data that is parsed into a set of `NSDictionary`
 and `NSArray` objects.

 When a request returns a non-JSON response, that response is packaged in
 a `NSDictionary` using GBNonJSONResponseProperty as the key and the literal
 response as the value.
*/
extern NSString *const GBNonJSONResponseProperty;

/*!
 @typedef GBRequestHandler

 @abstract
 A block that is passed to addRequest to register for a callback with the results of that
 request once the connection completes.

 @discussion
 Pass a block of this type when calling addRequest.  This will be called once
 the request completes.  The call occurs on the UI thread.

 @param connection      The `GBRequestConnection` that sent the request.

 @param result          The result of the request.  This is a translation of
                        JSON data to `NSDictionary` and `NSArray` objects.  This
                        is nil if there was an error.

 @param error           The `NSError` representing any error that occurred.

*/
typedef void (^GBRequestHandler)(GBRequestConnection *connection,
                                 id result,
                                 NSError *error);

/*!
 @class GBRequestConnection

 @abstract
 The `GBRequestConnection` represents a single connection to Facebook to service a request.

 @discussion
 The request settings are encapsulated in a reusable <GBRequest> object. The
 `GBRequestConnection` object encapsulates the concerns of a single communication
 e.g. starting a connection, canceling a connection, or batching requests.

*/
@interface GBRequestConnection : NSObject

/*!
 @methodgroup Creating a request
*/

/*!
 @method

 Calls <initWithTimeout:> with a default timeout of 180 seconds.
*/
- (id)init;

/*!
 @method

 @abstract
 `GBRequestConnection` objects are used to issue one or more requests as a single
 request/response connection with Facebook.

 @discussion
 For a single request, the usual method for creating an `GBRequestConnection`
 object is to call one of the **start* ** methods on <GBRequest>. However, it is
 allowable to init an `GBRequestConnection` object directly, and call
 <addRequest:completionHandler:> to add one or more request objects to the
 connection, before calling start.

 Note that if requests are part of a batch, they must have an open
 GBSession that has an access token associated with it. Alternatively a default App ID
 must be set either in the plist or through an explicit call to <[GBSession defaultAppID]>.

 @param timeout         The `NSTimeInterval` (seconds) to wait for a response before giving up.
*/

- (id)initWithTimeout:(NSTimeInterval)timeout;

// properties

/*!
 @abstract
 The request that will be sent to the server.

 @discussion
 This property can be used to create a `NSURLRequest` without using
 `GBRequestConnection` to send that request.  It is legal to set this property
 in which case the provided `NSMutableURLRequest` will be used instead.  However,
 the `NSMutableURLRequest` must result in an appropriate response.  Furthermore, once
 this property has been set, no more <GBRequest> objects can be added to this
 `GBRequestConnection`.
*/
@property (nonatomic, retain, readwrite) NSMutableURLRequest *urlRequest;

/*!
 @abstract
 The raw response that was returned from the server.  (readonly)

 @discussion
 This property can be used to inspect HTTP headers that were returned from
 the server.

 The property is nil until the request completes.  If there was a response
 then this property will be non-nil during the GBRequestHandler callback.
*/
@property (nonatomic, retain, readonly) NSHTTPURLResponse *urlResponse;

/*!
 @attribute beta true

 @abstract Set the automatic error handling behaviors.
 @discussion

 This must be set before any requests are added.

 When using retry behaviors, note the GBRequestConnection instance
 passed to the GBRequestHandler may be a different instance that the
 one the requests were originally started on.
*/
@property (nonatomic, assign) GBRequestConnectionErrorBehavior errorBehavior;

/*!
 @methodgroup Adding requests
*/

/*!
 @method

 @abstract
 This method adds an <GBRequest> object to this connection.

 @discussion
 The completion handler is retained until the block is called upon the
 completion or cancellation of the connection.

 @param request       A request to be included in the round-trip when start is called.
 @param handler       A handler to call back when the round-trip completes or times out.
                      The handler will be invoked on the main thread.
*/
- (void)addRequest:(GBRequest*)request
 completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 This method adds an <GBRequest> object to this connection.

 @discussion
 The completion handler is retained until the block is called upon the
 completion or cancellation of the connection. This request can be named
 to allow for using the request's response in a subsequent request.

 @param request         A request to be included in the round-trip when start is called.

 @param handler         A handler to call back when the round-trip completes or times out.
                        The handler will be invoked on the main thread.

 @param name            An optional name for this request.  This can be used to feed
 the results of one request to the input of another <GBRequest> in the same
 `GBRequestConnection` as described in
 [Graph API Batch Requests]( https://developers.facebook.com/docs/reference/api/batch/ ).
*/
- (void)addRequest:(GBRequest*)request
 completionHandler:(GBRequestHandler)handler
    batchEntryName:(NSString*)name;

/*!
 @method

 @abstract
 This method adds an <GBRequest> object to this connection.

 @discussion
 The completion handler is retained until the block is called upon the
 completion or cancellation of the connection. This request can be named
 to allow for using the request's response in a subsequent request.

 @param request         A request to be included in the round-trip when start is called.

 @param handler         A handler to call back when the round-trip completes or times out.

 @param batchParameters The optional dictionary of parameters to include for this request
 as described in [Graph API Batch Requests]( https://developers.facebook.com/docs/reference/api/batch/ ).
 Examples include "depends_on", "name", or "omit_response_on_success".
 */
- (void)addRequest:(GBRequest*)request
 completionHandler:(GBRequestHandler)handler
   batchParameters:(NSDictionary*)batchParameters;

/*!
 @methodgroup Instance methods
*/

/*!
 @method

 @abstract
 This method starts a connection with the server and is capable of handling all of the
 requests that were added to the connection.

 @discussion
 Errors are reported via the handler callback, even in cases where no
 communication is attempted by the implementation of `GBRequestConnection`. In
 such cases multiple error conditions may apply, and if so the following
 priority (highest to lowest) is used:

 - `GBRequestConnectionInvalidRequestKey` -- this error is reported when an
 <GBRequest> cannot be encoded for transmission.

 - `GBRequestConnectionInvalidBatchKey`   -- this error is reported when any
 request in the connection cannot be encoded for transmission with the batch.
 In this scenario all requests fail.

 This method cannot be called twice for an `GBRequestConnection` instance.
*/
- (void)start;

/*!
 @method

 @abstract
 Signals that a connection should be logically terminated as the
 application is no longer interested in a response.

 @discussion
 Synchronously calls any handlers indicating the request was cancelled. Cancel
 does not guarantee that the request-related processing will cease. It
 does promise that  all handlers will complete before the cancel returns. A call to
 cancel prior to a start implies a cancellation of all requests associated
 with the connection.
*/
- (void)cancel;

/*!
 @method

 @abstract
 Simple method to make a graph API request for user info (/me), creates an <GBRequest>
 then uses an <GBRequestConnection> object to start the connection with Facebook. The
 request uses the active session represented by `[GBSession activeSession]`.

 See <connectionWithSession:graphPath:parameters:HTTPMethod:completionHandler:>

 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForMeWithCompletionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to make a graph API request for user friends (/me/friends), creates an <GBRequest>
 then uses an <GBRequestConnection> object to start the connection with Facebook. The
 request uses the active session represented by `[GBSession activeSession]`.

 See <connectionWithSession:graphPath:parameters:HTTPMethod:completionHandler:>

 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForMyFriendsWithCompletionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to make a graph API post of a photo. The request
 uses the active session represented by `[GBSession activeSession]`.

 @param photo            A `UIImage` for the photo to upload.
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForUploadPhoto:(UIImage *)photo
                          completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to make a graph API post of a status update. The request
 uses the active session represented by `[GBSession activeSession]`.

 @param message         The message to post.
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection *)startForPostStatusUpdate:(NSString *)message
                                completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to make a graph API post of a status update. The request
 uses the active session represented by `[GBSession activeSession]`.

 @param message         The message to post.
 @param place           The place to checkin with, or nil. Place may be an fbid or a
 graph object representing a place.
 @param tags            Array of friends to tag in the status update, each element
 may be an fbid or a graph object representing a user.
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection *)startForPostStatusUpdate:(NSString *)message
                                            place:(id)place
                                             tags:(id<NSFastEnumeration>)tags
                                completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Starts a request representing a Graph API call to the "search" endpoint
 for a given location using the active session.

 @discussion
 Simplifies starting a request to search for places near a coordinate.

 This method creates the necessary <GBRequest> object and initializes and
 starts an <GBRequestConnection> object. A successful Graph API call will
 return an array of <GBGraphPlace> objects representing the nearby locations.

 @param coordinate      The search coordinates.

 @param radius          The search radius in meters.

 @param limit           The maxiumum number of results to return.  It is
                        possible to receive fewer than this because of the
                        radius and because of server limits.

 @param searchText      The text to use in the query to narrow the set of places
                        returned.
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForPlacesSearchAtCoordinate:(CLLocationCoordinate2D)coordinate
                                          radiusInMeters:(NSInteger)radius
                                            resultsLimit:(NSInteger)limit
                                              searchText:(NSString*)searchText
                                       completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Starts a request representing the Graph API call to retrieve a Custom Audience "third party ID" for the app's Facebook user.
 Callers will send this ID back to their own servers, collect up a set to create a Facebook Custom Audience with,
 and then use the resultant Custom Audience to target ads.

 @param session    The GBSession to use to establish the user's identity for users logged into Facebook through this app.
 If `nil`, then the activeSession is used.

 @discussion
 This method will throw an exception if <[GBSettings defaultAppID]> is `nil`.  The appID won't be nil when the pList
 includes the appID, or if it's explicitly set.

 The JSON in the request's response will include an "custom_audience_third_party_id" key/value pair, with the value being the ID retrieved.
 This ID is an encrypted encoding of the Facebook user's ID and the invoking Facebook app ID.
 Multiple calls with the same user will return different IDs, thus these IDs cannot be used to correlate behavior
 across devices or applications, and are only meaningful when sent back to Facebook for creating Custom Audiences.

 The ID retrieved represents the Facebook user identified in the following way: if the specified session (or activeSession if the specified
 session is `nil`) is open, the ID will represent the user associated with the activeSession; otherwise the ID will represent the user logged into the
 native Facebook app on the device.  If there is no native Facebook app, no one is logged into it, or the user has opted out
 at the iOS level from ad tracking, then a `nil` ID will be returned.

 This method returns `nil` if either the user has opted-out (via iOS) from Ad Tracking, the app itself has limited event usage
 via the `[GBAppEvents setLimitEventUsage]` flag, or a specific Facebook user cannot be identified.

 @param handler The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForCustomAudienceThirdPartyID:(GBSession *)session
                                         completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to make a graph API request, creates an <GBRequest> object for HTTP GET,
 then uses an <GBRequestConnection> object to start the connection with Facebook. The
 request uses the active session represented by `[GBSession activeSession]`.

 See <connectionWithSession:graphPath:parameters:HTTPMethod:completionHandler:>

 @param graphPath        The Graph API endpoint to use for the request, for example "me".
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startWithGraphPath:(NSString*)graphPath
                         completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to delete an object using the graph API, creates an <GBRequest> object for
 HTTP DELETE, then uses an <GBRequestConnection> object to start the connection with Facebook.
 The request uses the active session represented by `[GBSession activeSession]`.

 @param object           The object to delete, may be an NSString or NSNumber representing an fbid or an NSDictionary with an id property
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForDeleteObject:(id)object
                           completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Simple method to post an object using the graph API, creates an <GBRequest> object for
 HTTP POST, then uses <GBRequestConnection> to start a connection with Facebook. The request uses
 the active session represented by `[GBSession activeSession]`.

 @param graphPath        The Graph API endpoint to use for the request, for example "me".

 @param graphObject      An object or open graph action to post.

 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForPostWithGraphPath:(NSString*)graphPath
                                      graphObject:(id<GBGraphObject>)graphObject
                                completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Creates an `GBRequest` object for a Graph API call, instantiate an
 <GBRequestConnection> object, add the request to the newly created
 connection and finally start the connection. Use this method for
 specifying the request parameters and HTTP Method. The request uses
 the active session represented by `[GBSession activeSession]`.

 @param graphPath        The Graph API endpoint to use for the request, for example "me".

 @param parameters       The parameters for the request. A value of nil sends only the automatically handled parameters, for example, the access token. The default is nil.

 @param HTTPMethod       The HTTP method to use for the request. A nil value implies a GET.

 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startWithGraphPath:(NSString*)graphPath
                                parameters:(NSDictionary*)parameters
                                HTTPMethod:(NSString*)HTTPMethod
                         completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Creates an `GBRequest` for creating a user owned Open Graph object, instantiate a
 <GBRequestConnection> object, add the request to the newly created
 connection and finally start the connection. The request uses
 the active session represented by `[GBSession activeSession]`.

 @param object           The Open Graph object to create. Some common expected fields include "title", "image", "url", etc.

 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForPostOpenGraphObject:(id<GBOpenGraphObject>)object
                                  completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Creates an `GBRequest` for creating a user owned Open Graph object, instantiate a
 <GBRequestConnection> object, add the request to the newly created
 connection and finally start the connection. The request uses
 the active session represented by `[GBSession activeSession]`.

 @param type             The fully-specified Open Graph object type (e.g., my_app_namespace:my_object_name)
 @param title            The title of the Open Graph object.
 @param image            The link to an image to be associated with the Open Graph object.
 @param url              The url to be associated with the Open Graph object.
 @param description      The description for the object.
 @param objectProperties Any additional properties for the Open Graph object.
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForPostOpenGraphObjectWithType:(NSString *)type
                                                      title:(NSString *)title
                                                      image:(id)image
                                                        url:(id)url
                                                description:(NSString *)description
                                           objectProperties:(NSDictionary *)objectProperties
                                          completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Creates an `GBRequest` for updating a user owned Open Graph object, instantiate a
 <GBRequestConnection> object, add the request to the newly created
 connection and finally start the connection. The request uses
 the active session represented by `[GBSession activeSession]`.

 @param object           The Open Graph object to update the existing object with.

 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection*)startForUpdateOpenGraphObject:(id<GBOpenGraphObject>)object
                                    completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Creates an `GBRequest` for updating a user owned Open Graph object, instantiate a
 <GBRequestConnection> object, add the request to the newly created
 connection and finally start the connection. The request uses
 the active session represented by `[GBSession activeSession]`.

 @param objectId         The id of the Open Graph object to update.
 @param title            The updated title of the Open Graph object.
 @param image            The updated link to an image to be associated with the Open Graph object.
 @param url              The updated url to be associated with the Open Graph object.
 @param description      The object's description.
 @param objectProperties Any additional properties to update for the Open Graph object.
 @param handler          The handler block to call when the request completes with a success, error, or cancel action.
 */
+ (GBRequestConnection *)startForUpdateOpenGraphObjectWithId:(id)objectId
                                                       title:(NSString *)title
                                                       image:(id)image
                                                         url:(id)url
                                                 description:(NSString *)description
                                            objectProperties:(NSDictionary *)objectProperties
                                           completionHandler:(GBRequestHandler)handler;

/*!
 @method

 @abstract
 Starts a request connection to upload an image
 to create a staging resource. Staging resources allow you to post binary data
 such as images, in preparation for a post of an open graph object or action
 which references the image. The URI returned when uploading a staging resource
 may be passed as the value for the image property of an open graph object or action.

 @discussion
 This method simplifies the preparation of a Graph API call be creating the GBRequest
 object and starting the request connection with a single method

 @param image            A `UIImage` for the image to upload.
 @param handler          The handler block to call when the request completes.
 */
+ (GBRequestConnection *)startForUploadStagingResourceWithImage:(UIImage *)image
                                              completionHandler:(GBRequestHandler)handler;

@end
