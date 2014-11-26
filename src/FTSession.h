//
//  FTSession.h
//  facebook-ios-sdk
//
//  Created by kaijung on 2014/11/7.
//
//

#import <Foundation/Foundation.h>

@class FTSession;

#define FT_SESSIONSTATETERMINALBIT (1 << 8)
#define FT_SESSIONSTATEOPENBIT (1 << 9)

/*!
 @typedef GBSessionState enum
 
 @abstract Passed to handler block each time a session state changes
 
 @discussion
 */
typedef enum {
    /*! One of two initial states indicating that no valid cached token was found */
    FTSessionStateCreated                   = 0,
    /*! One of two initial session states indicating that a cached token was loaded;
     when a session is in this state, a call to open* will result in an open session,
     without UX or app-switching*/
    FTSessionStateCreatedTokenLoaded        = 1,
    /*! One of three pre-open session states indicating that an attempt to open the session
     is underway*/
    FTSessionStateCreatedOpening            = 2,
    
    /*! Open session state indicating user has logged in or a cached token is available */
    FTSessionStateOpen                      = 1 | FT_SESSIONSTATEOPENBIT,
    /*! Open session state indicating token has been extended */
    FTSessionStateOpenTokenExtended         = 2 | FT_SESSIONSTATEOPENBIT,
    
    /*! Closed session state indicating that a login attempt failed */
    FTSessionStateClosedLoginFailed         = 1 | FT_SESSIONSTATETERMINALBIT, // NSError obj w/more info
    /*! Closed session state indicating that the session was closed, but the users token
     remains cached on the device for later use */
    FTSessionStateClosed                    = 2 | FT_SESSIONSTATETERMINALBIT, // "
} FTSessionState;

/*!
 @typedef
 
 @abstract Block type used to define blocks called by <FBSession> for state updates
 @discussion See https://developers.facebook.com/docs/technical-guides/iossdk/errors/
 for error handling best practices.
 
 Requesting additional permissions inside this handler (such as by calling
 `requestNewPublishPermissions`) should be avoided because it is a poor user
 experience and its behavior may vary depending on the login type. You should
 request the permissions closer to the operation that requires it (e.g., when
 the user performs some action).
 */
typedef void (^FTSessionStateHandler)(FTSession *session,
                                      FTSessionState status,
                                      NSError *error);

@interface FTSession : NSObject

/*!
 @methodgroup Creating a session
 */

/*!
 @method
 
 @abstract
 Returns a newly initialized Facebook session with default values for the parameters
 to <initWithAppID:permissions:urlSchemeSuffix:tokenCacheStrategy:>.
 */
- (id)init;


/*!
 @method
 
 @abstract Opens a session for the Facebook.
 
 @discussion
 A session may not be used with <FBRequest> and other classes in the SDK until it is open. If, prior
 to calling open, the session is in the <FBSessionStateCreatedTokenLoaded> state, then no UX occurs, and
 the session becomes available for use. If the session is in the <FBSessionStateCreated> state, prior
 to calling open, then a call to open causes login UX to occur, either via the Facebook application
 or via mobile Safari.
 
 Open may be called at most once and must be called after the `FBSession` is initialized. Open must
 be called before the session is closed. Calling an open method at an invalid time will result in
 an exception. The open session methods may be passed a block that will be called back when the session
 state changes. The block will be released when the session is closed.
 
 @param handler A block to call with the state changes. The default is nil.
 */
- (void)openWithCompletionHandler:(FTSessionStateHandler)handler;

- (NSString *) getStringFromUrl: (NSString*) url needle:(NSString *) needle;

/*! @abstract Detailed session state */
@property (readonly) FTSessionState state;
/*! @abstract The access token for the session object.
 @discussion Deprecated. Use the `accessTokenData` property. */
@property(readonly, copy) NSString *token;
/*! @abstract Gets the code for the session */
@property (readonly, copy) NSString *uid;
/*! @abstract Gets the parameter for the session */
//@property (readonly, copy) NSString *sessionKey;
@property (readonly, copy) NSDictionary *parameters;
/*! @abstract Gets the redirectUri for the session */
@property (readonly, copy) NSString *redirectUri;

@end