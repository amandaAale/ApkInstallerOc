//
//  MingDocument.h
//  Ddemo
//
//  Created by Ming Wang on 8/17/14.
//  Copyright (c) 2014 Ming Wang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MingDocument : NSDocument<NSComboBoxDataSource, NSComboBoxDelegate>
@property (strong) NSMutableDictionary *dict;

@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSImageView *iconView;
@property (weak) IBOutlet NSComboBox *deviceCombo;

@end