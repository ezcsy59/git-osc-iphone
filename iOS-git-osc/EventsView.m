//
//  EventsView.m
//  iOS-git-osc
//
//  Created by chenhaoxiang on 14-7-8.
//  Copyright (c) 2014年 chenhaoxiang. All rights reserved.
//

#import "GLGitlab.h"
#import "EventsView.h"
#import "EventCell.h"
#import "Event.h"
#import "Tools.h"
#import "UIImageView+WebCache.h"
#import "UserDetailsView.h"
#import "ProjectDetailsView.h"
#import "LastCell.h"

static NSString * const kKeyPrivate_token = @"private_token";
static NSString * const EventCellIdentifier = @"EventCell";

@interface EventsView ()

@property int64_t userID;
@property NSString *privateToken;

@property BOOL isFinishedLoad;
@property BOOL isLoading;
@property BOOL isFirstRequest;
@property LastCell *lastCell;

@end

@implementation EventsView

@synthesize events;

- (id)initWithPrivateToken:(NSString *)privateToken
{
    self = [super init];
    if (self) {
        _privateToken = privateToken;
    }
    
    return self;
}

- (id)initWithUserID:(int64_t)userID
{
    self = [super init];
    if (self) {
        _userID = userID;
    }
    
    return self;
}


#pragma mark - view life circle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"动态";
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:nil action:nil];
    [self.navigationItem setBackBarButtonItem:backItem];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[EventCell class] forCellReuseIdentifier:EventCellIdentifier];
    self.tableView.backgroundColor = [Tools uniformColor];
    UIView *footer =[[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.tableFooterView = footer;
    
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    events = [NSMutableArray new];
    _lastCell = [[LastCell alloc] initCell];
    _isFinishedLoad = NO;

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (events.count > 0 || _isFinishedLoad) {
        return;
    }
    
    [self.refreshControl beginRefreshing];
    [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentOffset.y-self.refreshControl.frame.size.height)
                            animated:YES];
    
    if (_privateToken && [Tools isPageCacheExist:9]) {
        [self loadFromCache];
        return;
    }
    
    _isFirstRequest = YES;
    [self loadEventsOnPage:1 refresh:YES];
}

- (void)dealloc
{
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < events.count) {
        GLEvent *event = [self.events objectAtIndex:indexPath.row];
        
        UILabel *label = [UILabel new];
        label.numberOfLines = 0;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        
        [label setAttributedText:[Event getEventDescriptionForEvent:event]];
        CGFloat descriptionHeight = [label sizeThatFits:CGSizeMake(self.tableView.frame.size.width - 60, MAXFLOAT)].height;
        
        CGFloat abstractHeight = 0;
        UITextView *textView = [UITextView new];
        textView.editable = NO;
        textView.scrollEnabled = NO;
        
        [Event setAbstractContent:textView forEvent:event];
        abstractHeight = [textView sizeThatFits:CGSizeMake(self.tableView.frame.size.width - 60, MAXFLOAT)].height;
        
        return descriptionHeight + abstractHeight + 47;
    } else {
        return 60;
    }

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_lastCell.status == LastCellStatusNotVisible) return events.count;
    return events.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < events.count) {
        EventCell *cell = [tableView dequeueReusableCellWithIdentifier:EventCellIdentifier forIndexPath:indexPath];
        
        GLEvent *event = [self.events objectAtIndex:indexPath.row];
        
        [Tools setPortraitForUser:event.author view:cell.userPortrait cornerRadius:5.0];
        UITapGestureRecognizer *tapPortraitRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                action:@selector(tapPortrait:)];
        cell.userPortrait.tag = indexPath.row;
        [cell.userPortrait addGestureRecognizer:tapPortraitRecognizer];
        
        [cell generateEventDescriptionView:event];
        
        [cell.time setAttributedText:[Tools getIntervalAttrStr:event.createdAt]];
        
        [Event setAbstractContent:cell.eventAbstract forEvent:event];
        
        return cell;        
    } else {
        return _lastCell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger row = indexPath.row;
    
    if (row < self.events.count) {
        GLEvent *event = [self.events objectAtIndex:indexPath.row];
        ProjectDetailsView *projectDetails = [[ProjectDetailsView alloc] initWithProjectID:event.projectId];
        [self.navigationController pushViewController:projectDetails animated:YES];
    } else {
        if (!_isLoading) {
            [self loadMore];
        }
    }
}

#pragma mark - recognizer
- (void)tapPortrait:(UITapGestureRecognizer *)sender
{
    GLUser *user = [events objectAtIndex:((UIImageView *)sender.view).tag];
    UserDetailsView *userDetails = [[UserDetailsView alloc] initWithPrivateToken:nil userID:user.userId];
    [self.navigationController pushViewController:userDetails animated:YES];
}

#pragma mark - 上拉加载更多

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    // 下拉到最底部时显示更多数据
	if(scrollView.contentOffset.y > ((scrollView.contentSize.height - scrollView.frame.size.height)))
	{
        [self loadMore];
	}
}

#pragma mark - 从缓存加载

- (void)loadFromCache
{
    [events removeAllObjects];
    _lastCell.status = LastCellStatusVisible;
    
    [events addObjectsFromArray:[Tools getPageCache:9]];
    _isFinishedLoad = events.count < 20;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
        _isFinishedLoad? [_lastCell finishedLoad]: [_lastCell normal];
    });
}



#pragma mark - 刷新

- (void)refresh
{
    static BOOL refreshInProgress = NO;
    
    if (!refreshInProgress)
    {
        refreshInProgress = YES;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self loadEventsOnPage:1 refresh:YES];
            refreshInProgress = NO;
        });
    }
}

- (void)loadMore
{
    if (_isFinishedLoad || _isLoading) {return;}
    
    _isLoading = YES;
    [_lastCell loading];
    
    // (events.count + 19) / 20 -- events.count / 20 向上取整
    [self loadEventsOnPage:(events.count + 19) / 20 + 1 refresh:NO];
}




- (void)loadEventsOnPage:(NSUInteger)page refresh:(BOOL)refresh
{
    if (![Tools isNetworkExist]) {
        if (refresh) {
            [self.refreshControl endRefreshing];
            _lastCell.status = LastCellStatusVisible;
        } else {
            _isLoading = NO;
            if (_isFinishedLoad) {
                [_lastCell finishedLoad];
            } else {
                [_lastCell normal];
            }
        }
        [Tools toastNotification:@"网络连接失败，请检查网络设置" inView:self.parentViewController.view];
        return;
    }

    GLGitlabSuccessBlock success = ^(id responseObject) {
        if (refresh) {
            [self.refreshControl endRefreshing];
            _lastCell.status = LastCellStatusVisible;
            [events removeAllObjects];
        }
        
        if ([responseObject count] == 0) {
            _isFinishedLoad = YES;
            [_lastCell finishedLoad];
        } else {
            _isFinishedLoad = [(NSArray *)responseObject count] < 20;
            
            NSUInteger repeatedCount = [Tools numberOfRepeatedEvents:events event:[responseObject objectAtIndex:0]];
            NSUInteger length = [responseObject count] < 20 - repeatedCount? [responseObject count]: 20 - repeatedCount;
            [events addObjectsFromArray:[responseObject subarrayWithRange:NSMakeRange(repeatedCount, length)]];

            if (_privateToken && (refresh || _isFirstRequest)) {
                [Tools savePageCache:responseObject type:9];
                _isFirstRequest = NO;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
                if (refresh) {[self.refreshControl endRefreshing];}
                _isFinishedLoad? [_lastCell finishedLoad]: [_lastCell normal];
            });
        }
        _isLoading = NO;
    };
    
    GLGitlabFailureBlock failure = ^(NSError *error) {
        if (error != nil) {
            [Tools toastNotification:[NSString stringWithFormat:@"网络异常，错误码：%ld", (long)error.code] inView:self.view];
        } else {
            [Tools toastNotification:@"网络错误" inView:self.view];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _lastCell.status = LastCellStatusVisible;
            [_lastCell errorStatus];
            [self.tableView reloadData];
            if (refresh) {
                [self.refreshControl endRefreshing];
            }
        });
        
        _isLoading = NO;
    };
    
    if (_privateToken) {
        [[GLGitlabApi sharedInstance] getEventsWithPrivateToken:_privateToken page:page success:success failure:failure];
    } else {
        [[GLGitlabApi sharedInstance] getUserEvents:_userID page:page success:success failure:failure];
    }
}



@end
