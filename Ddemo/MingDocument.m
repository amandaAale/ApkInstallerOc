//
//  MingDocument.m
//  Ddemo
//
//  Created by Ming Wang on 8/17/14.
//  Copyright (c) 2014 Ming Wang. All rights reserved.
//

#import "MingDocument.h"

@implementation MingDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MingDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return nil;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    NSLog(@"url : %@ ----  %@----", [url path], [url pathComponents ]);
    [self runCommand:@"adb devices"];
    [self runCommand:[NSString stringWithFormat:@"aapt d badging %@ | grep application-label:", [url path]]];

    return YES;
}


- (NSString*) runCommand:(NSString*)cmd
{
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    NSString *cmdline = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], cmd];
    task.arguments = @[@"-c", cmdline];
    task.standardOutput = pipe;
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog(@"%@ result : %@", cmd, grepOutput);
    return grepOutput;
}

@end
