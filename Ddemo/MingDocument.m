//
//  MingDocument.m
//  Ddemo
//
//  Created by Ming Wang on 8/17/14.
//  Copyright (c) 2014 Ming Wang. All rights reserved.
//

#import "MingDocument.h"
@interface MingDocument()
@property NSWindow *currentWindow;
@property bool installing;
@end
@implementation MingDocument


- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"remove observer....");
}

- (id)init
{
    self = [super init];
    if (self) {
        _dict = [[NSMutableDictionary alloc]init];
        _dict[@"icon_file"] = @"/tmp/icon.png";
    }
    return self;
}

- (void) receiveNotification:(NSNotification *) notification {
    NSLog(@"notify : %@", [notification debugDescription]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reload];
    });
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"usb" object:nil];
        NSLog(@"add observer....");
    return @"MingDocument";
}
-  (BOOL)isDocumentEdited
{
    return NO;
}


- (BOOL)hasUnautosavedChanges
{
    return NO;
}


- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    _currentWindow = [aController window];
    _errorMessage.hidden = TRUE;
    _process.hidden = TRUE;
    [_deviceCombo setStringValue:@"No devices"];
    [_deviceCombo setEnabled:NO];
    [_installButton setEnabled:NO];
    [_label setStringValue:_dict[@"label"]];
    _versionCode.stringValue = [NSString stringWithFormat:@"Version Code: %@", _dict[@"versionCode"]];
    _versionName.stringValue = [NSString stringWithFormat:@"Version Name: %@", _dict[@"versionName"]];
    _appSize.stringValue = [NSString stringWithFormat:@"Size: %@", _dict[@"appSize"]];
    NSImage *image = [[NSImage alloc]initWithContentsOfFile:_dict[@"icon_file"]];
    [_iconView setImage:image];

    [self reload];
}

- (void) reload
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        _dict[@"devices"] = [self listDevices];
        dispatch_async(dispatch_get_main_queue(), ^{
            if([_dict[@"devices"] count] == 0) {
                [_deviceCombo setStringValue:@"No devices"];
                [_deviceCombo setEnabled:NO];
                [_installButton setEnabled:NO];
            } else {
                [_deviceCombo selectItemAtIndex:0];
                [_deviceCombo setEnabled:!_installing];
                [_installButton setEnabled:!_installing];
            }
        });
    });
}

- (NSString*) installAPK
{
    NSString *device = [[_dict[@"devices"] objectAtIndex:[_deviceCombo indexOfSelectedItem]] objectForKey:@"serial"];
    NSString *cmd = [self loadAppCmd:[NSString stringWithFormat:@"adb -s %@ install -r %@", device, [_dict objectForKey:@"path"]]];
    NSString *result = [self runCommand:cmd];
    NSLog(@"install result :  %@ to %@", result, device);
    return result;
}

- (IBAction)install:(id)sender {
    _errorMessage.hidden = YES;
    _process.hidden = NO;
    _installButton.enabled = NO;
    _deviceCombo.enabled = NO;
    [_process startAnimation:self];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        _installing = YES;
        NSString *result = [[self installAPK] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray * array = [result componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        dispatch_async(dispatch_get_main_queue(), ^{
            _installing = NO;
            _process.hidden = YES;
            _errorMessage.hidden = NO;
            _errorMessage.stringValue = [array lastObject];
            _installButton.enabled = YES;
            _deviceCombo.enabled = YES;
        });
    });
}


- (IBAction)cancel:(id)sender {
    if(_currentWindow)
    {
        [_currentWindow close];
    }
}
- (IBAction)check:(id)sender {
}

+ (BOOL)autosavesInPlace
{
    return NO;
}

-(NSInteger) numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    return [_dict[@"devices"] count];
}

-(id) comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    NSDictionary *dict = [_dict[@"devices"] objectAtIndex:index];
    return [NSString stringWithFormat:@"%@ - %@", dict[@"model"], dict[@"serial"]];
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
    result = [self firstStringWithPattern:@"((\\w+\\s+device\\s+)+)" ofString:result];
    NSLog(@"devices : %@", result);
    if (result) {
        NSArray *list = [result componentsSeparatedByString:@"\n"];
        for (id string in list) {
            NSString *dev = [self firstStringWithPattern:@"(\\w+)\\s+device" ofString:string];
            if (dev) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                dict[@"serial"] = dev;
                NSString * cmd = [NSString stringWithFormat:@"adb -s %@ shell getprop ro.product.model", dev];
                dict[@"model"] = [[self runCommand:[self loadAppCmd:cmd]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [devices addObject:dict];
            }
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
    _dict[@"versionCode"] = [self firstStringWithPattern:@"versionCode='(\\d+)'" ofString:info];
    _dict[@"versionName"] = [self firstStringWithPattern:@"versionName='(.*)'" ofString:info];
    NSDictionary *file = [[NSFileManager defaultManager] attributesOfItemAtPath:_dict[@"path"] error:nil];
    _dict[@"appSize"] = [NSByteCountFormatter stringFromByteCount:[file fileSize] countStyle:NSByteCountFormatterCountStyleFile];
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
