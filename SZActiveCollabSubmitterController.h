//
//  SZActiveCollabSubmitterController.h
//  SZActiveCollabSubmitterController
//
//  Created by Jon Nall on 6/8/10.
//  Copyright 2010 STUNTAZ!!!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SZActiveCollabSubmitterController : NSWindowController
{
    NSString* originatorName;
    NSString* originatorEmail;
    NSString* issueType;
    NSString* issueSummary;
    NSAttributedString* issueDescription;
    BOOL sendSystemInfo;
    
    NSDictionary* categories;
    BOOL isSending;
}
@property (retain) NSString* originatorName;
@property (retain) NSString* originatorEmail;
@property (retain) NSString* issueType;
@property (retain) NSString* issueSummary;
@property (retain) NSAttributedString* issueDescription;
@property (assign) BOOL sendSystemInfo;

@property (readonly) NSArray* issueTypes;
@property (readonly) BOOL isSending;
@property (readonly) BOOL submitEnabled;

+(void)showIssueWindow:(id)sender;
-(IBAction)submitIssue:(id)sender;
-(IBAction)cancelIssue:(id)sender;

@end
