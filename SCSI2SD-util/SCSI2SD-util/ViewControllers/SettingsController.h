//
//  SettingsController.h
//  scsi2sd
//
//  Created by Gregory Casamento on 12/3/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "ConfigUtil.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsController : NSObject
{
    IBOutlet NSButton *enableSCSITerminator;
    IBOutlet NSPopUpButton *speedLimit;
    IBOutlet NSTextField *startupDelay;
    IBOutlet NSTextField *startupSelectionDelay;
    IBOutlet NSButton *enableParity;
    IBOutlet NSButton *enableUnitAttention;
    IBOutlet NSButton *enableSCSI2Mode;
    IBOutlet NSButton *respondToShortSCSISelection;
    IBOutlet NSButton *mapLUNStoSCSIIDs;
    IBOutlet NSButton *enableGlitch;
    IBOutlet NSButton *enableCache;
    IBOutlet NSButton *enableDisconnect;
}

- (NSString *) toXml;
- (void) setConfig: (S2S_BoardCfg)config;
- (void) setConfigData: (NSData *)data;
- (S2S_BoardCfg) getConfig;

@end

NS_ASSUME_NONNULL_END
