//
//  SZActiveCollabSubmitterController.m
//  SZActiveCollabSubmitterController
//
//  Created by Jon Nall on 6/8/10.
//  Copyright 2010 STUNTAZ!!!. All rights reserved.
//

#import "SZActiveCollabSubmitterController.h"

NSString* const kszSystemProfilerPath = @"/usr/sbin/system_profiler";

// Bundle Indentifier values
NSString* const SZActiveCollabSubmissionDict = @"SZActiveCollabSubmissionDict";
NSString* const SZActiveCollabSubmissionURL = @"SZActiveCollabSubmissionURL";
NSString* const SZActiveCollabSubmissionProject = @"SZActiveCollabSubmissionProject";
NSString* const SZActiveCollabSubmissionCategories = @"SZActiveCollabSubmissionCategories";
NSString* const SZActiveCollabSubmissionToken = @"SZActiveCollabSubmissionToken";


@interface SZActiveCollabSubmitterController()
@property (assign) BOOL isSending;
@property (retain) NSDictionary* categories;
@end

@interface SZActiveCollabSubmitterController(Private)
-(void)populateIssueTypes;
-(NSURL*)activeCollabURL;
-(NSString*)escapeString:(NSString*)string;
-(BOOL)submit:(NSError**)error;
-(void)cleanup;
-(NSString*)getSysInfo;
@end

@implementation SZActiveCollabSubmitterController
@synthesize originatorName;
@synthesize originatorEmail;
@synthesize issueType;
@synthesize issueSummary;
@synthesize issueDescription;
@synthesize sendSystemInfo;
@synthesize isSending;
@synthesize categories;

+(void)showIssueWindow:(id)sender
{
    SZActiveCollabSubmitterController* controller = [[self alloc]
                                                     initWithWindowNibName:@"SZSubmissionWindow"];
    
    [controller showWindow:sender];

    // controller is released in -cleanup
}

+(NSSet*)keyPathsForValuesAffectingIssueTypes
{
    return [NSSet setWithObjects:@"categories", nil];
}

+(NSSet*)keyPathsForValuesAffectingSubmitEnabled
{
    // The number of characters in this string determine whether we enable
    // submission
    return [NSSet setWithObjects:@"issueSummary", nil];
}

-(id)init
{
    self = [super initWithWindowNibName:@"SZSubmissionWindow"];
    if(self != nil)
    {
    }
    
    return self;
}

-(void)dealloc
{
    [originatorName release];
    [originatorEmail release];
    [issueType release];
    [issueSummary release];
    [issueDescription release];
    [categories release];
    [super dealloc];
}

-(void)windowDidLoad
{
    [self populateIssueTypes];
}

-(void)showWindow:(id)sender
{
    [self.window center];
    [super showWindow:sender];
}

#pragma mark IBActions
-(IBAction)submitIssue:(id)sender
{
    self.isSending = YES;
    {
        NSError* error = nil;
        const BOOL success = [self submit:&error];
        if(success == NO)
        {
            NSRunAlertPanel(@"Submission Error",
                            @"There was an error while submitting: %@. The issue was not submitted.",
                            @"OK",
                            nil, 
                            nil,
                            [error description]);
        }
    }
    self.isSending = NO;
    [self cleanup];
}

-(IBAction)cancelIssue:(id)sender
{
    [self cleanup];
}

-(NSArray*)issueTypes
{
    return [[self.categories allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

-(BOOL)submitEnabled
{
    // ActiveCollab balks at summaries <= 3 characters
    return [self.issueSummary length] > 3;
}

@end

#pragma mark Private Methods
@implementation SZActiveCollabSubmitterController(Private)
-(void)cleanup
{
    [self.window close];    
    [self autorelease];
}

-(void)populateIssueTypes
{
    NSDictionary* infoDict = [[[NSBundle mainBundle] infoDictionary] objectForKey:SZActiveCollabSubmissionDict];
    self.categories = [infoDict objectForKey:SZActiveCollabSubmissionCategories];
}

-(BOOL)submit:(NSError**)error
{
    // Get the category ID and convert it to the correct string
    //
    const NSInteger index = [self.issueType integerValue];
    NSString* categoryID = [self.categories objectForKey:[self.issueTypes objectAtIndex:index]];
    
    // Setup the ticket params
    //
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    [params setObject:categoryID forKey:@"ticket[parent_id]"]; // category
    [params setObject:@"1" forKey:@"ticket[visibility]"]; // publicly viewable
    [params setObject:self.issueSummary forKey:@"ticket[name]"];
    
    // Complete the body -- give it a little structure and add the system info
    // if requested
    //
    NSString* finalDescription = [NSString stringWithFormat:@"Name: %@\nEmail:%@\n\n%@",
                                  self.originatorName, self.originatorEmail, [self.issueDescription string]];
    if(self.sendSystemInfo)
    {
        // Append system info
        finalDescription = [NSString stringWithFormat:@"%@\n\n== System Info ==\n%@", finalDescription, [self getSysInfo]];
    }
    
    [params setObject:finalDescription forKey:@"ticket[body]"];
    
    // Create the request and setup its data
    //
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[self activeCollabURL]];

    // Create escaped request POST data
    {
        NSMutableString* paramString = [NSMutableString stringWithFormat:@"submitted=submitted"];
        for(NSString* key in [params allKeys]) // [parameters keyEnumerator])
        {
            NSAssert1([params objectForKey:key] != nil,
                      @"Found not parameters for %@", key);
                        
            [paramString appendFormat:@"&%@=%@", key, [self escapeString:[params objectForKey:key]]];        
        }
        
        NSData* postData = [paramString dataUsingEncoding:NSASCIIStringEncoding
                                       allowLossyConversion:YES];
        NSString* postLength = [NSString stringWithFormat:@"%d", [postData length]];
        [request setHTTPMethod:@"POST"];        
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];  
    }
    
    // Send the request and return YES on success
    //
    NSHTTPURLResponse* response = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:error];
    (void)response;
    (void)data;
    return [response statusCode] == 200;
}

-(NSURL*)activeCollabURL
{
    NSDictionary* infoDict = [[[NSBundle mainBundle] infoDictionary] objectForKey:SZActiveCollabSubmissionDict];
    NSString* baseUrlString = [infoDict objectForKey:SZActiveCollabSubmissionURL];
    NSString* token = [infoDict objectForKey:SZActiveCollabSubmissionToken];
    NSInteger projectID = [[infoDict objectForKey:SZActiveCollabSubmissionProject] integerValue];
    NSString* fullUrlString = [NSString stringWithFormat:@"%@/public/api.php?path_info=projects/%d/tickets/add&token=%@", baseUrlString, projectID, token];
    NSURL* result = [NSURL URLWithString:fullUrlString];
    if(result == nil)
    {
        NSLog(@"ERROR: Couldn't create valid URL from SZActiveCollabSubmissionURL = \"%@\"",
              baseUrlString);
    }
    
    return result;
}

-(NSString*)escapeString:(NSString*)string
{
    NSString* result = (NSString*)
    CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                            (CFStringRef)string,
                                            NULL,
                                            CFSTR("$&+,/:;=?@ \"<>#%{}|\\^~`"),
                                            kCFStringEncodingUTF8);
    return result;
}

-(NSString*)getSysInfo
{
    // First attempt to run the system_profiler
    //
    if([[NSFileManager defaultManager] fileExistsAtPath:kszSystemProfilerPath])
    {
        NSTask* task = [[[NSTask alloc] init] autorelease];
        [task setLaunchPath:kszSystemProfilerPath];
        [task setArguments:[NSArray arrayWithObjects:
                            @"-detailLevel",
                            @"mini",
                            nil]];
        NSPipe* taskOutput = [NSPipe pipe];    
        [task setStandardOutput:taskOutput];
        [task setStandardError:taskOutput];
        [task launch];
        [task waitUntilExit];
        
        NSMutableString* result = [NSMutableString string];
        const int status = [task terminationStatus];
        if(status != 0)
        {
            [result appendFormat:@"ERROR: Couldn't acquire system info: Reason = %d\n", [task terminationReason]];
        }
        
        NSFileHandle* output = [taskOutput fileHandleForReading];
        NSData* data = [output readDataToEndOfFile];
        [result appendString:[[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]];
        
        return result;
    }
    
    // If that didn't work, just use the process info to get the OS version and
    // other minor stuff
    //
    else
    {
        NSMutableString* info = [NSMutableString stringWithFormat:@"Couldn't find %@. Using NSProcessInfo.\n",
                                 kszSystemProfilerPath];
        NSProcessInfo* pInfo = [NSProcessInfo processInfo];
        [info appendFormat:@"osName: %@\n", [pInfo operatingSystemName]];
        [info appendFormat:@"osVersion: %@\n", [pInfo operatingSystemVersionString]];
        [info appendFormat:@"processorCount: %d\n", [pInfo processorCount]];
        [info appendFormat:@"physicalMemory: %lld\n", [pInfo physicalMemory]];
        [info appendFormat:@"processorCount: %d\n", [pInfo processorCount]];
        [info appendFormat:@"activeProcessorCount: %d\n", [pInfo activeProcessorCount]];
        
        return info;
    }
}

@end
