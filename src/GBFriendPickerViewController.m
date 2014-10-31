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

#import "GBFriendPickerViewController.h"
#import "GBFriendPickerViewController+Internal.h"

#import "GBAppEvents+Internal.h"
#import "GBError.h"
#import "GBFriendPickerCacheDescriptor.h"
#import "GBFriendPickerViewDefaultPNG.h"
#import "GBGraphObjectPagingLoader.h"
#import "GBGraphObjectTableCell.h"
#import "GBGraphObjectTableDataSource.h"
#import "GBGraphObjectTableSelection.h"
#import "GBLogger.h"
#import "GBRequest.h"
#import "GBRequestConnection.h"
#import "GBSession+Internal.h"
#import "GBSettings.h"
#import "GBUtility.h"

NSString *const GBFriendPickerCacheIdentity = @"GBFriendPicker";

int const GBRefreshCacheDelaySeconds = 2;

@interface GBFriendPickerViewController () <GBGraphObjectSelectionChangedDelegate,
                                            GBGraphObjectViewControllerDelegate,
                                            GBGraphObjectPagingLoaderDelegate>

@property (nonatomic, retain) GBGraphObjectTableDataSource *dataSource;
@property (nonatomic, retain) GBGraphObjectTableSelection *selectionManager;
@property (nonatomic, retain) GBGraphObjectPagingLoader *loader;
@property (nonatomic) BOOL trackActiveSession;

- (void)initialize;
- (void)centerAndStartSpinner;
- (void)loadDataSkippingRoundTripIfCached:(NSNumber*)skipRoundTripIfCached;
- (GBRequest*)requestForLoadData;
- (void)addSessionObserver:(GBSession*)session;
- (void)removeSessionObserver:(GBSession*)session;
- (void)clearData;

@end

@implementation GBFriendPickerViewController {
    BOOL _allowsMultipleSelection;
}

@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize fieldsForRequest = _fieldsForRequest;
@synthesize selectionManager = _selectionManager;
@synthesize spinner = _spinner;
@synthesize tableView = _tableView;
@synthesize userID = _userID;
@synthesize loader = _loader;
@synthesize sortOrdering = _sortOrdering;
@synthesize displayOrdering = _displayOrdering;
@synthesize trackActiveSession = _trackActiveSession;
@synthesize session = _session;

- (id)init {
    self = [super init];

    if (self) {
        [self initialize];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self initialize];
    }

    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
        [self initialize];
    }

    return self;
}

- (void)initialize {
    // Data Source
    GBGraphObjectTableDataSource *dataSource = [[[GBGraphObjectTableDataSource alloc]
                                                 init]
                                                autorelease];
    dataSource.defaultPicture = [GBFriendPickerViewDefaultPNG image];
    dataSource.controllerDelegate = self;
    dataSource.itemTitleSuffixEnabled = YES;

    // Selection Manager
    GBGraphObjectTableSelection *selectionManager = [[[GBGraphObjectTableSelection alloc]
                                                      initWithDataSource:dataSource]
                                                     autorelease];
    selectionManager.delegate = self;

    // Paging loader
    id loader = [[[GBGraphObjectPagingLoader alloc] initWithDataSource:dataSource
                                                            pagingMode:GBGraphObjectPagingModeImmediate]
                 autorelease];
    self.loader = loader;
    self.loader.delegate = self;

    // Self
    self.allowsMultipleSelection = YES;
    self.dataSource = dataSource;
    self.delegate = nil;
    self.itemPicturesEnabled = YES;
    self.selectionManager = selectionManager;
    self.userID = @"me";
    self.sortOrdering = GBFriendSortByFirstName;
    self.displayOrdering = GBFriendDisplayByFirstName;
    self.trackActiveSession = YES;
}

- (void)dealloc {
    [_loader cancel];
    _loader.delegate = nil;
    [_loader release];

    _dataSource.controllerDelegate = nil;

    [_dataSource release];
    [_fieldsForRequest release];
    [_selectionManager release];
    [_spinner release];
    [_tableView release];
    [_userID release];

    [self removeSessionObserver:_session];
    [_session release];

    [super dealloc];
}

#pragma mark - Custom Properties

- (BOOL)allowsMultipleSelection {
    return _allowsMultipleSelection;
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection {
    _allowsMultipleSelection = allowsMultipleSelection;
    if (self.selectionManager) {
        self.selectionManager.allowsMultipleSelection = allowsMultipleSelection;
    }
}

- (BOOL)itemPicturesEnabled {
    return self.dataSource.itemPicturesEnabled;
}

- (void)setItemPicturesEnabled:(BOOL)itemPicturesEnabled {
    self.dataSource.itemPicturesEnabled = itemPicturesEnabled;
}

- (NSArray *)selection {
    // There might be bogus items set via setSelection, so we need to check against
    // datasource and filter them out.
    NSMutableArray* validSelection = [[[NSMutableArray alloc] init] autorelease];
    for (GBGraphObject *item in self.selectionManager.selection) {
        NSIndexPath* indexPath = [self.dataSource indexPathForItem:item];
        if (indexPath != nil) {
            [validSelection addObject:item];
        }
    }
    return validSelection;
}

- (void)setSelection:(NSArray *)selection {
    [self.selectionManager selectItem:selection tableView:self.tableView];
}

// We don't really need to store session, let the loader hold it.
- (void)setSession:(GBSession *)session {
    if (session != _session) {
        [self removeSessionObserver:_session];

        [_session release];
        _session = [session retain];

        [self addSessionObserver:session];

        self.loader.session = session;

        self.trackActiveSession = (session == nil);
    }
}


#pragma mark - Public Methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [GBLogger registerCurrentTime:GBLoggingBehaviorPerformanceCharacteristics
                          withTag:self];
    CGRect bounds = self.canvasView.bounds;

    if (!self.tableView) {
        UITableView *tableView = [[[UITableView alloc] initWithFrame:bounds] autorelease];
        tableView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        self.tableView = tableView;
        [self.canvasView addSubview:tableView];
    }

    if (!self.spinner) {
        UIActivityIndicatorView *spinner = [[[UIActivityIndicatorView alloc]
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray]
                                            autorelease];
        spinner.hidesWhenStopped = YES;
        // We want user to be able to scroll while we load.
        spinner.userInteractionEnabled = NO;

        self.spinner = spinner;
        [self.canvasView addSubview:spinner];
    }

    self.selectionManager.allowsMultipleSelection = self.allowsMultipleSelection;
    self.tableView.delegate = self.selectionManager;
    [self.dataSource bindTableView:self.tableView];
    self.loader.tableView = self.tableView;
}

- (void)viewDidUnload {
    [super viewDidUnload];

    self.loader.tableView = nil;
    self.spinner = nil;
    self.tableView = nil;
}

- (void)configureUsingCachedDescriptor:(GBCacheDescriptor*)cacheDescriptor {
    if (![cacheDescriptor isKindOfClass:[GBFriendPickerCacheDescriptor class]]) {
        [[NSException exceptionWithName:GBInvalidOperationException
                                 reason:@"GBFriendPickerViewController: An attempt was made to configure "
                                        @"an instance with a cache descriptor object that was not created "
                                        @"by the GBFriendPickerViewController class"
                               userInfo:nil]
         raise];
    }
    GBFriendPickerCacheDescriptor *cd = (GBFriendPickerCacheDescriptor*)cacheDescriptor;
    self.userID = cd.userID;
    self.fieldsForRequest = cd.fieldsForRequest;
}

- (void)loadData {
    // when the app calls loadData,
    // if we don't have a session and there is
    // an open active session, use that
    if (!self.session ||
        (self.trackActiveSession && ![self.session isEqual:[GBSession activeSessionIfOpen]])) {
        self.session = [GBSession activeSessionIfOpen];
        self.trackActiveSession = YES;
    }
    [self loadDataSkippingRoundTripIfCached:[NSNumber numberWithBool:YES]];
}

- (void)updateView {
    [self.dataSource update];
    [self.tableView reloadData];
}

- (void)clearSelection {
    [self.selectionManager clearSelectionInTableView:self.tableView];
}

- (void)addSessionObserver:(GBSession *)session {
    [session addObserver:self
              forKeyPath:@"state"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
}

- (void)removeSessionObserver:(GBSession *)session {
    [session removeObserver:self
                 forKeyPath:@"state"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([object isEqual:self.session] &&
        self.session.isOpen == NO) {
        [self clearData];
    }
}

- (void)clearData {
    [self.dataSource clearGraphObjects];
    [self.selectionManager clearSelectionInTableView:self.tableView];
    [self.tableView reloadData];
    [self.loader reset];
}

#pragma mark - public class members

+ (GBCacheDescriptor*)cacheDescriptor {
    return [[[GBFriendPickerCacheDescriptor alloc] init] autorelease];
}

+ (GBCacheDescriptor*)cacheDescriptorWithUserID:(NSString*)userID
                               fieldsForRequest:(NSSet*)fieldsForRequest {
    return [[[GBFriendPickerCacheDescriptor alloc] initWithUserID:userID
                                                 fieldsForRequest:fieldsForRequest]
            autorelease];
}


#pragma mark - private members

- (GBRequest*)requestForLoadData {

    // Respect user settings in case they have changed.
    NSMutableArray *sortFields = [NSMutableArray array];
    NSString *groupByField = nil;
    if (self.sortOrdering == GBFriendSortByFirstName) {
        [sortFields addObject:@"first_name"];
        [sortFields addObject:@"middle_name"];
        [sortFields addObject:@"last_name"];
        groupByField = @"first_name";
    } else {
        [sortFields addObject:@"last_name"];
        [sortFields addObject:@"first_name"];
        [sortFields addObject:@"middle_name"];
        groupByField = @"last_name";
    }
    [self.dataSource setSortingByFields:sortFields ascending:YES];
    self.dataSource.groupByField = groupByField;
    self.dataSource.useCollation = YES;

    // me or one of my friends that also uses the app
    NSString *user = self.userID;
    if (!user) {
        user = @"me";
    }

    // create the request and start the loader
    GBRequest *request = [GBFriendPickerViewController requestWithUserID:user
                                                                  fields:self.fieldsForRequest
                                                              dataSource:self.dataSource
                                                                 session:self.session];
    return request;
}

- (void)loadDataSkippingRoundTripIfCached:(NSNumber*)skipRoundTripIfCached {
    if (self.session) {
        [self.loader startLoadingWithRequest:[self requestForLoadData]
                               cacheIdentity:GBFriendPickerCacheIdentity
                       skipRoundtripIfCached:skipRoundTripIfCached.boolValue];
    }
}

+ (GBRequest*)requestWithUserID:(NSString*)userID
                         fields:(NSSet*)fields
                     dataSource:(GBGraphObjectTableDataSource*)datasource
                        session:(GBSession*)session {

    GBRequest *request = [GBRequest requestForGraphPath:[NSString stringWithFormat:@"%@/friends", userID]];
    [request setSession:session];

    // Use field expansion to fetch a 100px wide picture if we're on a retina device.
    NSString *pictureField = ([GBUtility isRetinaDisplay]) ? @"picture.width(100).height(100)" : @"picture";

    NSString *allFields = [datasource fieldsForRequestIncluding:fields,
                           @"id",
                           @"name",
                           @"first_name",
                           @"middle_name",
                           @"last_name",
                           pictureField,
                           nil];
    [request.parameters setObject:allFields forKey:@"fields"];

    return request;
}

- (void)centerAndStartSpinner {
    [GBUtility centerView:self.spinner tableView:self.tableView];
    [self.spinner startAnimating];
}

- (void)logAppEvents:(BOOL)cancelled {
    [GBAppEvents logImplicitEvent:GBAppEventNameFriendPickerUsage
                      valueToSum:nil
                      parameters:@{ GBAppEventParameterDialogOutcome : (cancelled
                                                                             ? GBAppEventsDialogOutcomeValue_Cancelled
                                                                             : GBAppEventsDialogOutcomeValue_Completed),
                                    @"num_friends_picked" : [NSNumber numberWithUnsignedInteger:self.selection.count]
                                  }
                         session:self.session];
}

#pragma mark - GBGraphObjectSelectionChangedDelegate

- (void)graphObjectTableSelectionDidChange:(GBGraphObjectTableSelection *)selection {
    if ([self.delegate respondsToSelector:
         @selector(friendPickerViewControllerSelectionDidChange:)]) {
        [(id)self.delegate friendPickerViewControllerSelectionDidChange:self];
    }
}

#pragma mark - GBGraphObjectViewControllerDelegate

- (BOOL)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                filterIncludesItem:(id<GBGraphObject>)item {
    id<GBGraphUser> user = (id<GBGraphUser>)item;

    if ([self.delegate
         respondsToSelector:@selector(friendPickerViewController:shouldIncludeUser:)]) {
        return [(id)self.delegate friendPickerViewController:self
                                       shouldIncludeUser:user];
    } else {
        return YES;
    }
}

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                             titleOfItem:(id<GBGraphUser>)graphUser {
    // Title is either "First Middle" or "Last" depending on display order.
    if (self.displayOrdering == GBFriendDisplayByFirstName) {
        if (graphUser.middle_name) {
            return [NSString stringWithFormat:@"%@ %@", graphUser.first_name, graphUser.middle_name];
        } else {
            return graphUser.first_name;
        }
    } else {
        return graphUser.last_name;
    }
}

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                       titleSuffixOfItem:(id<GBGraphUser>)graphUser {
    // Title suffix is either "Last" or "First Middle" depending on display order.
    if (self.displayOrdering == GBFriendDisplayByLastName) {
        if (graphUser.middle_name) {
            return [NSString stringWithFormat:@"%@ %@", graphUser.first_name, graphUser.middle_name];
        } else {
            return graphUser.first_name;
        }
    } else {
        return graphUser.last_name;
    }

}

- (NSString *)graphObjectTableDataSource:(GBGraphObjectTableDataSource *)dataSource
                       pictureUrlOfItem:(id<GBGraphObject>)graphObject {
    id picture = [graphObject objectForKey:@"picture"];
    // Depending on what migration the app is in, we may get back either a string, or a
    // dictionary with a "data" property that is a dictionary containing a "url" property.
    if ([picture isKindOfClass:[NSString class]]) {
        return picture;
    }
    id data = [picture objectForKey:@"data"];
    return [data objectForKey:@"url"];
}

- (void)graphObjectTableDataSource:(GBGraphObjectTableDataSource*)dataSource
                customizeTableCell:(GBGraphObjectTableCell*)cell {
    // We want to bold whichever part of the name we are sorting on.
    cell.boldTitle = (self.sortOrdering == GBFriendSortByFirstName && self.displayOrdering == GBFriendDisplayByFirstName) ||
        (self.sortOrdering == GBFriendSortByLastName && self.displayOrdering == GBFriendDisplayByLastName);
    cell.boldTitleSuffix = (self.sortOrdering == GBFriendSortByFirstName && self.displayOrdering == GBFriendDisplayByLastName) ||
        (self.sortOrdering == GBFriendSortByLastName && self.displayOrdering == GBFriendDisplayByFirstName);
}

#pragma mark GBGraphObjectPagingLoaderDelegate members

- (void)pagingLoader:(GBGraphObjectPagingLoader*)pagingLoader willLoadURL:(NSString*)url {
    [self centerAndStartSpinner];
}

- (void)pagingLoader:(GBGraphObjectPagingLoader*)pagingLoader didLoadData:(NSDictionary*)results {
    // This logging currently goes here because we're effectively complete with our initial view when
    // the first page of results come back.  In the future, when we do caching, we will need to move
    // this to a more appropriate place (e.g., after the cache has been brought in).
    [GBLogger singleShotLogEntry:GBLoggingBehaviorPerformanceCharacteristics
                    timestampTag:self
                    formatString:@"Friend Picker: first render "];  // logger will append "%d msec"


    if ([self.delegate respondsToSelector:@selector(friendPickerViewControllerDataDidChange:)]) {
        [(id)self.delegate friendPickerViewControllerDataDidChange:self];
    }
}

- (void)pagingLoaderDidFinishLoading:(GBGraphObjectPagingLoader *)pagingLoader {
    // finished loading, stop animating
    [self.spinner stopAnimating];

    // Call the delegate from here as well, since this might be the first response of a query
    // that has no results.
    if ([self.delegate respondsToSelector:@selector(friendPickerViewControllerDataDidChange:)]) {
        [(id)self.delegate friendPickerViewControllerDataDidChange:self];
    }

    // if our current display is from cache, then kick-off a near-term refresh
    if (pagingLoader.isResultFromCache) {
        [self performSelector:@selector(loadDataSkippingRoundTripIfCached:)
                   withObject:[NSNumber numberWithBool:NO]
                   afterDelay:GBRefreshCacheDelaySeconds];
    }
}

- (void)pagingLoader:(GBGraphObjectPagingLoader*)pagingLoader handleError:(NSError*)error {
    if ([self.delegate
         respondsToSelector:@selector(friendPickerViewController:handleError:)]) {
        [(id)self.delegate friendPickerViewController:self handleError:error];
    }
}

- (void)pagingLoaderWasCancelled:(GBGraphObjectPagingLoader*)pagingLoader {
    [self.spinner stopAnimating];
}

@end
