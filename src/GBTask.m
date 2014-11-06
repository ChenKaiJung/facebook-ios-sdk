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

#import "GBTask.h"

#import <libkern/OSAtomic.h>

#import "GBTaskCompletionSource.h"

__attribute__ ((noinline)) void gbLogOperationOnMainThread() {
    NSLog(@"Warning: A long-running GBTask operation is being executed on the main thread. \n"
          " Break on logOperationOnMainThread() to debug.");
}

@interface GBTask () {
    id _result;
    NSError *_error;
    NSException *_exception;
    BOOL _cancelled;
}

@property (nonatomic, retain, readwrite) NSObject *lock;
@property (nonatomic, retain, readwrite) NSCondition *condition;
@property (nonatomic, assign, readwrite) BOOL completed;
@property (nonatomic, retain, readwrite) NSMutableArray *callbacks;
@end

@implementation GBTask

- (id)init {
    if ((self = [super init])) {
        _lock = [[NSObject alloc] init];
        _condition = [[NSCondition alloc] init];
        _callbacks = [[NSMutableArray array] retain];
    }
    return self;
}

- (void)dealloc {
    [_lock release];
    [_condition release];
    [_callbacks release];

    [super dealloc];
}

+ (GBTask *)taskWithResult:(id)result {
    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    tcs.result = result;
    return tcs.task;
}

+ (GBTask *)taskWithError:(NSError *)error {
    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    tcs.error = error;
    return tcs.task;
}

+ (GBTask *)taskWithException:(NSException *)exception {
    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    tcs.exception = exception;
    return tcs.task;
}

+ (GBTask *)cancelledTask {
    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    [tcs cancel];
    return tcs.task;
}

+ (GBTask *)taskDependentOnTasks:(NSArray *)tasks {
    __block int32_t total = (int32_t)tasks.count;
    if (total == 0) {
        return [GBTask taskWithResult:nil];
    }

    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    for (GBTask *task in tasks) {
        [task dependentTaskWithBlock:^id(GBTask *task) {
            if (OSAtomicDecrement32(&total) == 0) {
                tcs.result = nil;
            }
            return nil;
        }];
    }
    return tcs.task;
}

+ (GBTask *)taskWithDelay:(dispatch_time_t)delay {
    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        tcs.result = nil;
    });
    return tcs.task;
}

- (id)result {
    @synchronized (self.lock) {
        return _result;
    }
}

- (void)setResult:(id)result {
    if (![self trySetResult:result]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot set the result on a completed task."];
    }
}

- (BOOL)trySetResult:(id)result {
    @synchronized (self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        _result = result;
        [self runContinuations];
        return YES;
    }
}

- (NSError *)error {
    @synchronized (self.lock) {
        return _error;
    }
}

- (void)setError:(NSError *)error {
    if (![self trySetError:error]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot set the error on a completed task."];
    }
}

- (BOOL)trySetError:(NSError *)error {
    @synchronized (self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        _error = error;
        [self runContinuations];
        return YES;
    }
}

- (NSException *)exception {
    @synchronized (self.lock) {
        return _exception;
    }
}

- (void)setException:(NSException *)exception {
    if (![self trySetException:exception]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot set the exception on a completed task."];
    }
}

- (BOOL)trySetException:(NSException *)exception {
    @synchronized (self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        _exception = exception;
        [self runContinuations];
        return YES;
    }
}

- (BOOL)isCancelled {
    @synchronized (self.lock) {
        return _cancelled;
    }
}

- (void)cancel {
    @synchronized (self.lock) {
        if (![self trySetCancelled]) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"Cannot cancel a completed task."];
        }
    }
}

- (BOOL)trySetCancelled {
    @synchronized (self.lock) {
        if (self.completed) {
            return NO;
        }
        self.completed = YES;
        _cancelled = YES;
        [self runContinuations];
        return YES;
    }
}

- (BOOL)isCompleted {
    @synchronized (self.lock) {
        return _completed;
    }
}

- (void)setCompleted {
    @synchronized (self.lock) {
        _completed = YES;
    }
}

- (void)runContinuations {
    @synchronized (self.lock) {
        [self.condition lock];
        [self.condition broadcast];
        [self.condition unlock];
        for (void (^callback)() in self.callbacks) {
            callback();
        }
        [self.callbacks removeAllObjects];
    }
}

- (GBTask *)dependentTaskWithBlock:(id(^)(GBTask *task))block {
    return [self dependentTaskWithBlock:block queue:nil];
}

- (GBTask *)dependentTaskWithBlock:(id(^)(GBTask *task))block queue:(dispatch_queue_t)queue {
    block = [[block copy] autorelease];

    GBTaskCompletionSource *tcs = [GBTaskCompletionSource taskCompletionSource];
    queue = queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    // Capture all of the state that needs to used when the continuation is complete.
    void (^wrappedBlock)() = ^() {
        // Always dispatching callbacks async consumes less stack space, and seems
        // to be a little faster, but loses stacktrace information. If you're debugging,
        // consider commenting this line out and running the block synchronously.
        dispatch_async(queue, ^{
            id result = nil;
            @try {
                result = block(self);
            } @catch (NSException *exception) {
                tcs.exception = exception;
                return;
            }

            if ([result isKindOfClass:[GBTask class]]) {
                [(GBTask *)result dependentTaskWithBlock:^id(GBTask *task) {
                    if (task.isCancelled) {
                        [tcs cancel];
                    } else if (task.exception) {
                        tcs.exception = task.exception;
                    } else if (task.error) {
                        tcs.error = task.error;
                    } else {
                        tcs.result = task.result;
                    }
                    return nil;
                } queue:queue];
            } else {
                tcs.result = result;
            }
        });
    };

    BOOL completed;
    @synchronized (self.lock) {
        completed = self.completed;
        if (!completed) {
            [self.callbacks addObject:[[wrappedBlock copy] autorelease]];
        }
    }
    if (completed) {
        wrappedBlock();
    }

    return tcs.task;
}

- (GBTask *)completionTaskWithBlock:(id(^)(GBTask *task))block {
    block = [block copy];
    return [self dependentTaskWithBlock:^id(GBTask *task) {
        if (task.error || task.exception || task.isCancelled) {
            return task;
        } else {
            return [task dependentTaskWithBlock:block];
        }
    }];
}

- (GBTask *)completionTaskWithQueue:(dispatch_queue_t)queue block:(id(^)(GBTask *task))block {
    block = [block copy];
    return [self dependentTaskWithBlock:^id(GBTask *task) {
        if (task.error || task.exception || task.isCancelled) {
            return task;
        } else {
            return [task dependentTaskWithBlock:block queue:queue];
        }
    }];
}

- (void)warnOperationOnMainThread {
    gbLogOperationOnMainThread();
}

// A no-op version to be swizzled in for tests.
- (void)warnOperationOnMainThreadNoOp {
}

// Private methods.

- (void)waitUntilFinished {
    if ([NSThread isMainThread]) {
        [self warnOperationOnMainThread];
    }

    @synchronized (self.lock) {
        if (self.isCompleted) {
            return;
        }
        [self.condition lock];
    }
    [self.condition wait];
    [self.condition unlock];
}

- (id)waitForResult:(NSError **)error {
    [self waitUntilFinished];
    if (self.isCancelled) {
        return nil;
    } else if (self.exception) {
        @throw self.exception;
    }
    if (self.error && error) {
        *error = self.error;
    }
    return self.result;
}

@end
