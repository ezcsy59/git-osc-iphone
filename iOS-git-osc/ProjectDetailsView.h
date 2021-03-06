//
//  ProjectDetailsView.h
//  iOS-git-osc
//
//  Created by chenhaoxiang on 14-7-30.
//  Copyright (c) 2014年 chenhaoxiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GLProject;

@interface ProjectDetailsView : UITableViewController

@property GLProject *project;
@property GLProject *parentProject;

- (id)initWithProjectID:(int64_t)projectID;

@end
