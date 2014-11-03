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

#import "GBViewController.h"
#import "GBViewController+Internal.h"

#import "GBLogger.h"
#import "GBSettings.h"

@interface GBViewController ()

@property (nonatomic, retain) UINavigationBar *navigationBar;
@property (nonatomic, retain) UIView *canvasView;
@property (nonatomic, copy) GBModalCompletionHandler handler;
@property (nonatomic) BOOL autoDismiss;
@property (nonatomic) BOOL dismissAnimated;

- (void)cancelButtonPressed:(id)sender;
- (void)doneButtonPressed:(id)sender;
- (void)updateBarForPresentedMode;
- (void)updateBarForNavigationMode;
- (void)updateBar;

@end

@implementation GBViewController

@synthesize cancelButton = _cancelButton;
@synthesize doneButton = _doneButton;
@synthesize delegate = _delegate;
@synthesize navigationBar = _navigationBar;
@synthesize canvasView = _canvasView;
@synthesize handler = _handler;
@synthesize autoDismiss = _autoDismiss;
@synthesize dismissAnimated = _dismissAnimated;

#pragma mark View controller lifecycle

- (void)commonInit {
    // We do this at init-time rather than in viewDidLoad so the caller can change the buttons if
    // they want prior to the view loading.
    self.cancelButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                       target:self
                                                                       action:@selector(cancelButtonPressed:)]
                         autorelease];
    self.doneButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                     target:self
                                                                     action:@selector(doneButtonPressed:)]
                       autorelease];
#ifdef __IPHONE_7_0
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (self.parentViewController == nil) {
        UIApplication *application = [UIApplication sharedApplication];
        if (!application.statusBarHidden) {
            if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
                self.edgesForExtendedLayout = UIRectEdgeNone;
            }
        }
    }
#endif
#endif
#endif
}

- (id)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [super dealloc];

    [_cancelButton release];
    [_doneButton release];
    [_navigationBar release];
    [_canvasView release];
    [_handler release];
}

#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.autoresizesSubviews = YES;

    self.canvasView = [[[UIView alloc] init] autorelease];
    [self.canvasView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

    self.canvasView.frame = [self contentBounds];
    [self.view addSubview:self.canvasView];
    [self.view sendSubviewToBack:self.canvasView];

    self.autoDismiss = NO;

    self.doneButton.target = self;
    self.doneButton.action = @selector(doneButtonPressed:);
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancelButtonPressed:);

    [self updateBar];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    // If the view goes away for any reason, nil out the handler to avoid a retain cycle.
    self.handler = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark Public methods

- (void)presentModallyFromViewController:(UIViewController*)viewController
                                animated:(BOOL)animated
                                 handler:(GBModalCompletionHandler)handler {
    self.handler = handler;
    // Assumption: we want to dismiss with the same animated-ness as we present.
    self.dismissAnimated = animated;

    [viewController presentViewController:self animated:animated completion:nil];

    // Set this here because we always revert to NO in viewDidLoad.
    self.autoDismiss = YES;
}

#pragma mark Implementation

- (CGRect)contentBounds
{
    CGRect bounds = self.view.bounds;
#ifdef __IPHONE_7_0
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if (self.parentViewController == nil) {
        UIApplication *application = [UIApplication sharedApplication];
        if (!application.statusBarHidden) {
            if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
                if ((self.edgesForExtendedLayout & UIRectEdgeTop) == 0) {
                    CGFloat offset = CGRectGetMaxY(application.statusBarFrame);
                    bounds.origin.y += offset;
                    bounds.size.height -= offset;
                }
            }
        }
    }
#endif
#endif
#endif
    return bounds;
}

- (void)updateBar {
    if (self.presentingViewController != nil) {
        [self updateBarForPresentedMode];
    } else if (self.navigationController != nil) {
        [self updateBarForNavigationMode];
    }
}

- (void)updateBarForPresentedMode {
    BOOL needBar = (self.doneButton != nil) || (self.cancelButton != nil);
    if (needBar) {
        // If we need a bar but don't have one, create it.
        if (self.navigationBar == nil) {
            self.navigationBar = [[[UINavigationBar alloc] init] autorelease];
            self.navigationBar.barStyle = UIBarStyleDefault;

            [self.navigationBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth];

            [self.view addSubview:self.navigationBar];
        }
    } else {
        // If we have a bar but don't need one, get rid of it.
        if (self.navigationBar != nil) {
            [self.navigationBar removeFromSuperview];
            self.navigationBar = nil;

            self.canvasView.frame = [self contentBounds];
        }
        return;
    }

    UINavigationItem *navigationItem = [[[UINavigationItem alloc] initWithTitle:nil] autorelease];

    if (self.cancelButton != nil) {
        navigationItem.leftBarButtonItem = self.cancelButton;
    }
    if (self.title.length > 0) {
        navigationItem.title = self.title;
    }

    if (self.doneButton != nil) {
        navigationItem.rightBarButtonItem = self.doneButton;
    }

    [self.navigationBar sizeToFit];
    CGRect contentBounds = [self contentBounds];
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(contentBounds), CGRectGetMinY(contentBounds) + CGRectGetHeight(self.navigationBar.bounds));
    self.navigationBar.frame = frame;

    // Make the canvas shorter to account for the navigationBar.
    frame = contentBounds;
    CGFloat navigationBarHeight = self.navigationBar.bounds.size.height;
    frame.origin.y = navigationBarHeight;
    frame.size.height -= navigationBarHeight;
    self.canvasView.frame = frame;

    self.navigationBar.items = @[navigationItem];
}

- (void)updateBarForNavigationMode {
    self.navigationItem.rightBarButtonItem = self.doneButton;
}

- (void)setCancelButton:(UIBarButtonItem *)cancelButton {
    if (_cancelButton != cancelButton) {
        [_cancelButton release];
        _cancelButton = [cancelButton retain];
        [self updateBar];
    }
}

- (void)setDoneButton:(UIBarButtonItem *)doneButton {
    if (_doneButton != doneButton) {
        [_doneButton release];
        _doneButton = [doneButton retain];
        [self updateBar];
    }
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    [self updateBar];
}

#pragma mark Handlers

- (void)cancelButtonPressed:(id)sender {
    if ([self.delegate respondsToSelector:@selector(facebookViewControllerCancelWasPressed:)]) {
        [self.delegate facebookViewControllerCancelWasPressed:self];
    }

    UIViewController *presentingViewController = [self presentingViewController];
    if (self.autoDismiss && presentingViewController) {
        [presentingViewController dismissViewControllerAnimated:self.dismissAnimated completion:nil];

        [self logAppEvents:YES];
        if (self.handler) {
            self.handler(self, NO);
        }
    }
}

- (void)doneButtonPressed:(id)sender {
    if ([self.delegate respondsToSelector:@selector(facebookViewControllerDoneWasPressed:)]) {
        [self.delegate facebookViewControllerDoneWasPressed:self];
    }

    UIViewController *presentingViewController = [self presentingViewController];
    if (self.autoDismiss && presentingViewController) {
        [presentingViewController dismissViewControllerAnimated:self.dismissAnimated completion:nil];

        [self logAppEvents:NO];
        if (self.handler) {
            self.handler(self, YES);
        }
    }
}

- (void)logAppEvents:(BOOL)cancelled {
    // Internal subclasses that will implicitly log app events will do so here.
}


@end