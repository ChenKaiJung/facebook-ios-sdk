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

#import "GBSessionManualTokenCachingStrategy.h"


@implementation GBSessionManualTokenCachingStrategy

@synthesize accessToken = _accessToken,
            expirationDate = _expirationDate;

- (void)dealloc {
    [_accessToken release];
    [_expirationDate release];
    [super dealloc];
}

- (void)cacheTokenInformation:(NSDictionary*)tokenInformation {
    self.accessToken = [tokenInformation objectForKey:GBTokenInformationTokenKey];
    self.expirationDate = [tokenInformation objectForKey:GBTokenInformationExpirationDateKey];
}

- (NSDictionary*)fetchTokenInformation;
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            self.accessToken, GBTokenInformationTokenKey,
            self.expirationDate, GBTokenInformationExpirationDateKey,
            nil];
}

- (void)clearToken
{
    self.accessToken = nil;
    self.expirationDate = nil;
}

@end
