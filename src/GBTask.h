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

#import <Foundation/Foundation.h>

/*!
 The consumer view of a Task. A GBTask has methods to
 inspect the state of the task, and to add continuations to
 be run once the task is complete.
 */
@interface GBTask : NSObject

/*!
 Creates a task that is already completed with the given result.
 */
+ (GBTask *)taskWithResult:(id)result;

/*!
 Creates a task that is already completed with the given error.
 */
+ (GBTask *)taskWithError:(NSError *)error;

/*!
 Creates a task that is already completed with the given exception.
 */
+ (GBTask *)taskWithException:(NSException *)exception;

/*!
 Creates a task that is already cancelled.
 */
+ (GBTask *)cancelledTask;

/*!
 Returns a task that will be completed (with result == nil) once
 all of the input tasks have completed.
 */
+ (GBTask *)taskDependentOnTasks:(NSArray *)tasks;

/*!
 Returns a task that will be completed a certain amount of time in the future.
 @param delay The amount of time to wait before the
 task will be finished (with result == nil).
 */
+ (GBTask *)taskWithDelay:(dispatch_time_t)delay;

// Properties that will be set on the task once it is completed.

/*!
 The result of a successful task.
 */
- (id)result;

/*!
 The error of a failed task.
 */
- (NSError *)error;

/*!
 The exception of a failed task.
 */
- (NSException *)exception;

/*!
 Whether this task has been cancelled.
 */
- (BOOL)isCancelled;

/*!
 Whether this task has completed.
 */
- (BOOL)isCompleted;

/*!
 Enqueues the given block to be run once this task is complete.
 @param block The block to be run once this task is complete.
 @returns A task that will be completed after block has run.
 If block returns a GBTask, then the task returned from
 this method will not be completed until that task is completed.
 */
- (GBTask *)dependentTaskWithBlock:(id(^)(GBTask *task))block;

/*!
 Identical to `dependentTaskWithBlock:`, except the block
 is dispatched to the specified queue.
 */
- (GBTask *)dependentTaskWithBlock:(id(^)(GBTask *task))block queue:(dispatch_queue_t)queue;

/*!
 Identical to `dependentTaskWithBlock:`, except that the block is only run
 if this task did not produce a cancellation, error, or exception.
 If it did, then the failure will be propagated to the returned
 task.
 */
- (GBTask *)completionTaskWithBlock:(id(^)(GBTask *task))block;

/*!
 Identical to `completionTaskWithBlock:`, except the block
 is dispatched to the specified queue.
*/
- (GBTask *)completionTaskWithQueue:(dispatch_queue_t)queue block:(id(^)(GBTask *task))block;

/*!
 Waits until this operation is completed.
 This method is inefficient and consumes a thread resource while
 it's running. It should be avoided. This method logs a warning
 message if it is used on the main thread.
 */
- (void)waitUntilFinished;

@end