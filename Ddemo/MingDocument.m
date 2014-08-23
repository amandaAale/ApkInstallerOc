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
        _dict = [[NSMutableDictionary alloc]init];
        _dict[@"icon_file"] = @"/tmp/icon.png";
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
    [_label setStringValue:_dict[@"label"] ];
    NSImage *image = [[NSImage alloc]initWithContentsOfFile:_dict[@"icon_file"]];
    [_iconView setImage:image];
    [_deviceCombo addItemsWithObjectValues:[_dict objectForKey:@"devices"]];
    [_deviceCombo selectItemAtIndex:0];

}



+ (BOOL)autosavesInPlace
{
    return YES;
}


- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
    _dict[@"path"] = [url path];
    NSLog(@"url : %@ ", [url path]);
    NSString* cmd = [NSString stringWithFormat: @"aapt d badging %@", _dict[@"path"]];
    NSString *result = [self runCommand: [self loadAppCmd:cmd]];
    NSLog(@"cmd result ==>\n%@\n", result);
    [self readAppInfo:result];
    [self unzipIcon];
    _dict[@"devices"] = [self listDevices];
    return YES;
}

- (NSArray*)listDevices
{
    NSMutableArray *devices = [[NSMutableArray alloc]init];
    
    NSString *result = [self runCommand:[self loadAppCmd:@"adb devices"]];
    NSLog(@"devices : %@", result);
    NSUInteger index = [result rangeOfString:@"List of devices attached"].length;
    NSArray *list = [[result substringFromIndex:index] componentsSeparatedByString:@"\n"];
    for (id string in list) {
        NSString *dev = [self firstStringWithPattern:@"(\\w+)\\s+device" ofString:string];
        if (dev ) {
            [devices addObject:dev];
        }
    }
    NSLog(@"Devices list : %@", devices);
    return devices;
}

- (NSDictionary *) readAppInfo: (NSString *)info
{
    _dict[@"package"] = [self firstStringWithPattern:@"package: name='([\\w|.|-|_]+)'" ofString:info];
    _dict[@"label"] = [self firstStringWithPattern:@"application-label:'([\\w|.|-|_]+)'" ofString:info];
    _dict[@"icon"] = [self firstStringWithPattern:@".*icon='(.+)'" ofString:info];
    NSLog(@"app info is %@", _dict);
    return _dict;
}

-(NSString*) firstStringWithPattern:(NSString*)pattern ofString:(NSString*)target
{
	NSError* err = nil;
	NSString* result = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
																		   options:NSRegularExpressionCaseInsensitive
																			 error:&err];
	NSTextCheckingResult* match = [regex firstMatchInString:target options:0 range:NSMakeRange(0, [target length])];
	if (match) {
		if ([match numberOfRanges]>1)
			result = [target substringWithRange:[match rangeAtIndex:1]];
		else
			result = [target substringWithRange:[match range]];
	}
    
	return result;
}

- (void) unzipIcon
{
    [self runCommand: [NSString stringWithFormat: @"rm -rf %@", _dict[@"icon_file"]]];
    NSString*cmd = [NSString stringWithFormat:@"unzip -p %@ %@ > %@", _dict[@"path"], _dict[@"icon"], _dict[@"icon_file"]];
    [self runCommand:cmd];
}

- (NSString*) loadAppCmd: (NSString*)cmd
{
    return [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], cmd];
}

- (NSString*) runCommand:(NSString*)cmd
{
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    task.arguments = @[@"-c", cmd];
    task.standardOutput = pipe;
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    return grepOutput;
}

@end
