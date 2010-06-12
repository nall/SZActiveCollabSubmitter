//
//  SZActiveCollabExampleAppDelegate.m
//  SZActiveCollabExample
//
//  Created by Jon Nall on 6/9/10.
//  Copyright 2010 Apple Corporation. All rights reserved.
//

#import "SZActiveCollabExampleAppDelegate.h"
#import "SZActiveCollabSubmitterController.h"

@implementation SZActiveCollabExampleAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [SZActiveCollabSubmitterController showIssueWindow:self];
}

@end

