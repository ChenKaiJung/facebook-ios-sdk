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
#define SAFE_TO_USE_GBTESTSESSION

#import "GBTestSession.h"
#import "GBTestSession+Internal.h"
#import "GBSessionManualTokenCachingStrategy.h"
#import "GBError.h"
#import "GBSession+Protected.h"
#import "GBSession+Internal.h"
#import "GBRequest.h"
#import <pthread.h>
#import "GBGraphUser.h"
#import "GBUtility.h"

/*
 Indicates whether the test user for an GBTestSession should be shared
 (created only if necessary, not deleted automatically) or private (created specifically
 for this session, deleted automatically upon close).
 */
typedef enum {
    // Create and delete a new test user for this session.
    GBTestSessionModePrivate    = 0,
    // Use an existing available test user with the right permissions, or create
    // a new one if none are available. Not automatically deleted.
    GBTestSessionModeShared     = 1,
} GBTestSessionMode;

static NSString *const GBPLISTTestAppIDKey = @"IOS_SDK_TEST_APP_ID";
static NSString *const GBPLISTTestAppSecretKey = @"IOS_SDK_TEST_APP_SECRET";
static NSString *const GBPLISTUniqueUserTagKey = @"IOS_SDK_MACHINE_UNIQUE_USER_KEY";
static NSString *const GBLoginAuthTestUserURLPath = @"oauth/access_token";
static NSString *const GBLoginAuthTestUserCreatePathFormat = @"%@/accounts/test-users";
static NSString *const GBLoginTestUserClientID = @"client_id";
static NSString *const GBLoginTestUserClientSecret = @"client_secret";
static NSString *const GBLoginTestUserGrantType = @"grant_type";
static NSString *const GBLoginTestUserGrantTypeClientCredentials = @"client_credentials";
static NSString *const GBLoginTestUserAccessToken = @"access_token";
static NSString *const GBLoginTestUserID = @"id";
static NSString *const GBLoginTestUserName = @"name";

NSString *kSecondTestUserTag = @"Second";
NSString *kThirdTestUserTag = @"Third";

NSString *const GBErrorLoginFailedReasonUnitTestResponseUnrecognized = @"com.facebook.sdk:UnitTestResponseUnrecognized";

#pragma mark Module scoped global variables

static NSMutableDictionary *testUsers = nil;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

#pragma mark -

#pragma mark Private interface

@interface GBTestSession ()
{
    BOOL _forceAccessTokenRefresh;
}

@property (readwrite, copy) NSString *appAccessToken;
@property (readwrite, copy) NSString *testUserID;
@property (readwrite, copy) NSString *testAppID;
@property (readwrite, copy) NSString *testAppSecret;
@property (readwrite, copy) NSString *machineUniqueUserTag;
@property (readwrite, copy) NSString *sessionUniqueUserTag;
@property (readonly, copy) NSString *permissionsString;
@property (readonly, copy) NSString *sharedTestUserIdentifier;
@property (readwrite) GBTestSessionMode mode;

- (id)initWithAppID:(NSString*)appID
          appSecret:(NSString*)appSecret
machineUniqueUserTag:(NSString*)uniqueUserTag
sessionUniqueUserTag:(NSString*)sessionUniqueUserTag
               mode:(GBTestSessionMode)mode
        permissions:(NSArray*)permissions
tokenCachingStrategy:(GBSessionTokenCachingStrategy*)tokenCachingStrategy;
- (void)createNewTestUser;
- (void)retrieveTestUsersForApp;
- (void)findOrCreateSharedUser;
- (void)transitionToOpenWithToken:(NSString*)token;
- (NSString*)validNameStringFromInteger:(NSUInteger)input;
- (void)raiseException:(NSError*)innerError;

+ (void)deleteUnitTestUser:(NSString*)userID accessToken:(NSString*)accessToken;
+ (id)sessionForUnitTestingWithPermissions:(NSArray*)permissions mode:(GBTestSessionMode)mode sessionUniqueUserTag:(NSString*)sessionUniqueUserTag;

@end

#pragma mark -

@implementation GBTestSession

@synthesize appAccessToken = _appAccessToken;
@synthesize testUserID = _testUserID;
@synthesize testAppID = _testAppID;
@synthesize testAppSecret = _testAppSecret;
@synthesize mode = _mode;
@synthesize machineUniqueUserTag = _machineUniqueUserKey;
@synthesize sessionUniqueUserTag = _sessionUniqueUserTag;

#pragma mark Lifecycle

- (id)initWithAppID:(NSString*)appID
          appSecret:(NSString*)appSecret
machineUniqueUserTag:(NSString*)machineUniqueUserTag
sessionUniqueUserTag:(NSString*)sessionUniqueUserTag
               mode:(GBTestSessionMode)mode
        permissions:(NSArray*)permissions
tokenCachingStrategy:(GBSessionTokenCachingStrategy*)tokenCachingStrategy
{
    if (self = [super initWithAppID:appID
                        permissions:permissions
                    urlSchemeSuffix:nil
                 tokenCacheStrategy:tokenCachingStrategy]) {
        self.testAppID = appID;
        self.testAppSecret = appSecret;
        self.machineUniqueUserTag = machineUniqueUserTag;
        self.sessionUniqueUserTag = sessionUniqueUserTag;
        self.appAccessToken = [NSString stringWithFormat:@"%@|%@", appID, appSecret];
        self.mode = mode;
    }

    return self;
}

- (void)dealloc
{
    [_appAccessToken release];
    [_testUserID release];
    [_testAppID release];
    [_testAppSecret release];
    [_machineUniqueUserKey release];
    [_sessionUniqueUserTag release];

    [super dealloc];
}

#pragma mark -
#pragma mark Private methods

- (NSString*)permissionsString {
    NSArray *permissions = self.accessTokenData.permissions ?: self.initializedPermissions;
    return [permissions componentsJoinedByString:@","];
}

- (void)createNewTestUser
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       @"true", @"installed",
                                       [self permissionsString], @"permissions",
                                       @"post", @"method",
                                       self.appAccessToken, @"access_token",
                                       nil];

    // We don't get the user name back on create, so if we want it later, remember it now.
    NSString *newName = nil;
    if (self.mode == GBTestSessionModeShared) {
        // Rename the user with a hashed representation of our permissions, so we can find it
        // again later.
        newName = [NSString stringWithFormat:@"Shared %@ Testuser", self.sharedTestUserIdentifier];
        [parameters setObject:newName forKey:@"name"];
    }

    // fetch a test user and token
    // note, this fetch uses a manually constructed app token using the appid|appsecret approach,
    // if there is demand for support for apps for which this will not work, we may consider handling
    // failure by falling back and fetching an app-token via a request; the current approach reduces
    // traffic for common unit testing configuration, which seems like the right tradeoff to start with
    GBRequest *request = [[[GBRequest alloc] initWithSession:nil
                                                   graphPath:[NSString stringWithFormat:GBLoginAuthTestUserCreatePathFormat, self.appID]
                                                  parameters:parameters
                                                  HTTPMethod:nil]
                          autorelease];
    [request startWithCompletionHandler:
     ^(GBRequestConnection *connection, id result, NSError *error) {
         id userToken;
         id userID;
         if (!error &&
             [result isKindOfClass:[NSDictionary class]] &&
             (userToken = [result objectForKey:GBLoginTestUserAccessToken]) &&
             [userToken isKindOfClass:[NSString class]] &&
             (userID = [result objectForKey:GBLoginTestUserID]) &&
             [userID isKindOfClass:[NSString class]]) {
             // capture the id for future use
             self.testUserID = userID;

             // Remember this user if it is going to be shared.
             if (self.mode == GBTestSessionModeShared) {
                 NSDictionary *user = [NSDictionary dictionaryWithObjectsAndKeys:
                                       userID, GBLoginTestUserID,
                                       userToken, GBLoginTestUserAccessToken,
                                       newName, GBLoginTestUserName,
                                       nil];

                 pthread_mutex_lock(&mutex);

                 [testUsers setObject:user forKey:userID];

                 pthread_mutex_unlock(&mutex);
             }

             [self transitionToOpenWithToken:userToken];
         } else {
             if (error) {
                 NSLog(@"Error: [GBSession createNewTestUserAndRename:] failed with error: %@", error.description);
             } else {
                 // we fetched something unexpected when requesting an app token
                 error = [self errorLoginFailedWithReason:GBErrorLoginFailedReasonUnitTestResponseUnrecognized
                                                errorCode:nil
                                               innerError:nil];
             }
             // state transition, and call the handler if there is one
             [self transitionAndCallHandlerWithState:GBSessionStateClosedLoginFailed
                                               error:error
                                           tokenData:nil
                                         shouldCache:NO];
         }
     }];
}

- (void)transitionToOpenWithToken:(NSString*)token
{
    GBAccessTokenData *tokenData = [GBAccessTokenData createTokenFromString:token
                                                                permissions:nil
                                                             expirationDate:[NSDate distantFuture]
                                                                  loginType:GBSessionLoginTypeTestUser
                                                                refreshDate:[NSDate date]];
    [self transitionAndCallHandlerWithState:GBSessionStateOpen
                                      error:nil
                                  tokenData:tokenData
                                shouldCache:NO];
}

// We raise exceptions when things go wrong here, because this is intended for use only
// in unit tests and we want things to stop as soon as something bad happens.
- (void)raiseException:(NSError*)innerError
{
    NSDictionary *userInfo = nil;
    if (innerError) {
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                        innerError, GBErrorInnerErrorKey,
                        nil];
    }

    [[NSException exceptionWithName:GBInvalidOperationException
                             reason:@"GBTestSession encountered an error"
                           userInfo:userInfo]
     raise];

}

- (void)populateTestUsers:(NSDictionary*)users testAccounts:(NSArray*)testAccounts
{
    pthread_mutex_lock(&mutex);

    // Map user IDs to test_accounts
    for (NSDictionary *testAccount in testAccounts) {
        id uid = testAccount[GBLoginTestUserID];
        testUsers[uid] = [NSMutableDictionary dictionaryWithDictionary:testAccount];
    }

    // Add the user name to the test_account data.
    for (NSString *uid in [users allKeys]) {
        NSMutableDictionary *testUser = testUsers[uid];
        testUser[GBLoginTestUserName] = users[uid][GBLoginTestUserName];
    }

    pthread_mutex_unlock(&mutex);
}

- (void)retrieveTestUsersForApp
{
    // We need three pieces of data: id, access_token, and name (which we use to
    // encode permissions). Use batched Graph API requests to get the data
    GBRequestConnection *connection = [[[GBRequestConnection alloc] init] autorelease];
    GBRequest *requestForAccountIds = [[[GBRequest alloc] initWithSession:self
                                                  graphPath:[NSString stringWithFormat:@"%@/accounts/test-users",self.appID]
                                                  parameters:@{ @"access_token" : self.appAccessToken }
                                                 HTTPMethod:nil]
                         autorelease];
    __block id testAccounts = nil;
    [connection addRequest:requestForAccountIds completionHandler:^(GBRequestConnection *connection, id result, NSError *error) {
        if (error ||
            !result) {
            [self raiseException:error];
        }
        testAccounts = [result objectForKey:@"data"];
    } batchParameters:@{@"name":@"test-accounts", @"omit_response_on_success":@(NO)}];

    GBRequest *requestForUsersAndNames = [[[GBRequest alloc] initWithSession:self
                                                                   graphPath:@"?ids={result=test-accounts:$.data.*.id}"
                                                                  parameters:@{ @"access_token" : self.appAccessToken }
                                                                  HTTPMethod:nil]
                                          autorelease];
    [connection addRequest:requestForUsersAndNames completionHandler:^(GBRequestConnection *connection, id result, NSError *error) {
        if (error ||
            !result) {
            [self raiseException:error];
        }
        if (!testAccounts) {
            [self raiseException:nil];
        }
        id users = result;

        // Use both sets of results to populate our static array of accounts.
        [self populateTestUsers:users testAccounts:testAccounts];

        // Now that we've populated all test users, we can continue looking for
        // the matching user, which started this all off.
        [self findOrCreateSharedUser];
    }];
    [connection start];
}

// Given a long string, generate its hash value, and then convert that to a string that
// we can use as part of a Facebook test user name (i.e., no digits).
- (NSString*)validNameStringFromInteger:(NSUInteger)input
{
    NSString *hashAsString = [NSString stringWithFormat:@"%lu", (unsigned long)input];
    NSMutableString *result = [NSMutableString stringWithString:@"Perm"];

    // We know each character is a digit. Convert it into a letter starting with 'a'.
    for (int i = 0; i < hashAsString.length; ++i) {
        NSString *ch = [NSString stringWithFormat:@"%C",
                        (unsigned short)([hashAsString characterAtIndex:i] + 'a' - '0')];
        [result appendString:ch];
    }

    return result;
}

- (NSString*)sharedTestUserIdentifier
{
    NSUInteger permissionsHash = self.permissionsString.hash;
    NSUInteger machineTagHash = self.machineUniqueUserTag.hash;
    NSUInteger sessionTagHash = self.sessionUniqueUserTag.hash;

    NSUInteger combinedHash = permissionsHash ^ machineTagHash ^ sessionTagHash;
    return [self validNameStringFromInteger:combinedHash];
}

- (void)findOrCreateSharedUser
{
    pthread_mutex_lock(&mutex);

    NSString *userIdentifier = self.sharedTestUserIdentifier;

    id matchingTestUser = nil;
    for (id testUser in [testUsers allValues]) {
        NSString *userName = [testUser objectForKey:GBLoginTestUserName];
        // Does this user have the right permissions and is it not in use?
        if ([userName rangeOfString:userIdentifier].length > 0) {
            matchingTestUser = testUser;
            break;
        }
    }

    pthread_mutex_unlock(&mutex);

    if (matchingTestUser) {
        // We can use this user. IDs come back as numbers, make sure we return as a string.
        self.testUserID = [[matchingTestUser objectForKey:GBLoginTestUserID] description];

        [self transitionToOpenWithToken:[matchingTestUser objectForKey:GBLoginTestUserAccessToken]];
    } else {
        // Need to create a user. Do so, and rename it using our hashed permissions string.
        [self createNewTestUser];
    }
}

- (void)setForceAccessTokenRefresh:(BOOL)forceAccessTokenRefresh {
    _forceAccessTokenRefresh = forceAccessTokenRefresh;
}

- (BOOL)forceAccessTokenRefresh {
    return _forceAccessTokenRefresh;
}

#pragma mark -
#pragma mark Overrides

- (BOOL)transitionToState:(GBSessionState)state
      withAccessTokenData:(GBAccessTokenData *)tokenData
              shouldCache:(BOOL)shouldCache {
    // in case we need these after the transition
    NSString *userID = self.testUserID;

    BOOL didTransition = [super transitionToState:state
                              withAccessTokenData:tokenData
                                      shouldCache:shouldCache];

    if (didTransition && GB_ISSESSIONSTATETERMINAL(self.state)) {
        if (self.mode == GBTestSessionModePrivate) {
            [GBTestSession deleteUnitTestUser:userID accessToken:self.appAccessToken];
        }
    }

    return didTransition;
}
- (void)authorizeWithPermissions:(NSArray*)permissions
                        behavior:(GBSessionLoginBehavior)behavior
                 defaultAudience:(GBSessionDefaultAudience)audience
                   isReauthorize:(BOOL)isReauthorize {

    if (isReauthorize) {
        // For the test session, since we don't present UI,
        // we'll just complete the re-auth. Note this obviously means
        // no new permissions are requested.
        [super handleReauthorize:nil
                     accessToken:(self.disableReauthorize) ? nil : self.accessTokenData.accessToken];
    } else {
        // We ignore behavior, since we aren't going to present UI.

        if (self.mode == GBTestSessionModePrivate) {
            // If we aren't wanting a shared user, just create a user. Don't waste time renaming it since
            // we will be deleting it when done.
            [self createNewTestUser];
        } else {
            // We need to see if there are any test users that fit the bill.

            // Did we already get the test users?
            pthread_mutex_lock(&mutex);
            if (testUsers) {
                pthread_mutex_unlock(&mutex);

                // Yes, look for one that we can use.
                [self findOrCreateSharedUser];
            } else {
                // No, populate the list and then continue.
                // We never release testUsers. We should only populate it once.
                testUsers = [[NSMutableDictionary alloc] init];

                pthread_mutex_unlock(&mutex);

                [self retrieveTestUsersForApp];
            }
        }
    }
}

- (BOOL)shouldExtendAccessToken {
    // Note: we reset the flag each time we are queried. Tests should set it as needed for more complicated logic.
    BOOL extend = self.forceAccessTokenRefresh || [super shouldExtendAccessToken];
    self.forceAccessTokenRefresh = NO;
    return extend;
}

#pragma mark -
#pragma mark Class methods

+ (id)sessionWithSharedUserWithPermissions:(NSArray*)permissions
                             uniqueUserTag:(NSString*)uniqueUserTag
{
    return [self sessionForUnitTestingWithPermissions:permissions
                                                 mode:GBTestSessionModeShared
                                 sessionUniqueUserTag:uniqueUserTag];

}

+ (id)sessionWithSharedUserWithPermissions:(NSArray*)permissions
{
    return [self sessionWithSharedUserWithPermissions:permissions uniqueUserTag:nil];
}

+ (id)sessionWithPrivateUserWithPermissions:(NSArray*)permissions
{
    return [self sessionForUnitTestingWithPermissions:permissions
                                                 mode:GBTestSessionModePrivate
                                 sessionUniqueUserTag:nil];
}

+ (id)sessionForUnitTestingWithPermissions:(NSArray*)permissions
                                      mode:(GBTestSessionMode)mode
                      sessionUniqueUserTag:(NSString*)sessionUniqueUserTag
{
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *appID = [environment objectForKey:GBPLISTTestAppIDKey];
    NSString *appSecret = [environment objectForKey:GBPLISTTestAppSecretKey];
    if (!appID || !appSecret || appID.length == 0 || appSecret.length == 0) {
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:
          @"GBTestSession: Missing App ID or Secret; ensure that you have an .xcconfig file at:\n"
          @"\t${REPO_ROOT}/src/tests/TestAppIdAndSecret.xcconfig\n"
          @"containing your unit-testing Facebook Application's ID and Secret in this format:\n"
          @"\tIOS_SDK_TEST_APP_ID = // your app ID, e.g.: 1234567890\n"
          @"\tIOS_SDK_TEST_APP_SECRET = // your app secret, e.g.: 1234567890abcdef\n"
          @"To create a Facebook AppID, visit https://developers.facebook.com/apps"
                               userInfo:nil]
         raise];
    }

    // This is non-fatal if it's missing.
    NSString *machineUniqueUserTag = [environment objectForKey:GBPLISTUniqueUserTagKey];

    GBSessionManualTokenCachingStrategy *tokenCachingStrategy =
    [[GBSessionManualTokenCachingStrategy alloc] init];

    if (!permissions.count) {
        permissions = [NSArray arrayWithObjects:@"email", @"publish_actions", nil];
    }

    // call our internal designated initializer to create a unit-testing instance
    GBTestSession *session = [[[GBTestSession alloc]
                               initWithAppID:appID
                                   appSecret:appSecret
                        machineUniqueUserTag:machineUniqueUserTag
                        sessionUniqueUserTag:sessionUniqueUserTag
                                        mode:mode
                                 permissions:permissions
                        tokenCachingStrategy:tokenCachingStrategy]
            autorelease];

    [tokenCachingStrategy release];

    return session;
}

+ (void)deleteUnitTestUser:(NSString*)userID
               accessToken:(NSString*)accessToken
{
    if (userID && accessToken) {
        // use GBRequest/GBRequestConnection to create an NSURLRequest
        GBRequest *temp = [[GBRequest alloc ] initWithSession:nil
                                                    graphPath:userID
                                                   parameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               @"delete", @"method",
                                                               accessToken, @"access_token",
                                                               nil]
                                                   HTTPMethod:nil];
        GBRequestConnection *connection = [[GBRequestConnection alloc] init];
        [connection addRequest:temp completionHandler:nil];
        NSURLRequest *request = connection.urlRequest;
        [temp release];
        [connection release];

        // synchronously delete the user
        NSURLResponse *response;
        NSError *error = nil;
        NSData *data;
        data = [NSURLConnection sendSynchronousRequest:request
                                     returningResponse:&response
                                                 error:&error];
        // if !data or if data == false, log
        NSString *body = !data ? nil : [[[NSString alloc] initWithData:data
                                                              encoding:NSUTF8StringEncoding]
                                        autorelease];
        if (!data || [body isEqualToString:@"false"]) {
            NSLog(@"GBSession !delete test user with id:%@ error:%@", userID, error ? error : body);
        }
    }
}

#pragma mark -

@end
