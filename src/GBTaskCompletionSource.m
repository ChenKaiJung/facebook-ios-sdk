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

#import "GBTaskCompletionSource.h"

#import "GBTask.h"

@interface GBTaskCompletionSource ()
@property (nonatomic, retain, readwrite) GBTask *task;
@end

@interface GBTask (GBTaskCompletionSource)
- (void)setResult:(id)result;
- (void)setError:(NSError *)error;
- (void)setException:(NSException *)exception;
- (void)cancel;
- (BOOL)trySetResult:(id)result;
- (BOOL)trySetError:(NSError *)error;
- (BOOL)trySetException:(NSException *)exception;
- (BOOL)trySetCancelled;
@end

@implementation GBTaskCompletionSource

+ (GBTaskCompletionSource *)taskCompletionSource {
    return [[[GBTaskCompletionSource alloc] init] autorelease];
}

- (id)init {
    if ((self = [super init])) {
        _task = [[GBTask alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_task release];

    [super dealloc];
}

- (void)setResult:(id)result {
    [self.task setResult:result];
}

- (void)setError:(NSError *)error {
    [self.task setError:error];
}

- (void)setException:(NSException *)exception {
    [self.task setException:exception];
}

- (void)cancel {
    [self.task cancel];
}

- (BOOL)trySetResult:(id)result {
    return [self.task trySetResult:result];
}

- (BOOL)trySetError:(NSError *)error {
    return [self.task trySetError:error];
}

- (BOOL)trySetException:(NSException *)exception {
    return [self.task trySetException:exception];
}

- (BOOL)trySetCancelled {
    return [self.task trySetCancelled];
}

@end
