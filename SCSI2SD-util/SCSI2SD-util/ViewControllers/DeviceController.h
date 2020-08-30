//
//  DeviceController.h
//  scsi2sd
//
//  Created by Gregory Casamento on 12/3/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "ConfigUtil.h"

// #import "TargetConfig.h"
#include "scsi2sd.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceController : NSObject
{
     IBOutlet NSButton *enableSCSITarget;
     IBOutlet NSComboBox *SCSIID;
     IBOutlet NSPopUpButton *deviceType;
     IBOutlet NSTextField *sdCardStartSector;
     IBOutlet NSTextField *sectorSize;
     IBOutlet NSTextField *sectorCount;
     IBOutlet NSTextField *deviceSize;
     IBOutlet NSPopUpButton *deviceUnit;
     IBOutlet NSTextField *vendor;
     IBOutlet NSTextField *productId;
     IBOutlet NSTextField *revsion;
     IBOutlet NSTextField *serialNumber;
     IBOutlet NSButton *autoStartSector;
     IBOutlet NSTextField *sectorsPerTrack;
     IBOutlet NSTextField *headsPerCylinder;

     IBOutlet NSTextField *autoErrorText;
     IBOutlet NSTextField *scsiIdErrorText;

    BOOL duplicateId;
    BOOL sectorOverlap;
}

- (void) setTargetConfigData: (NSData *)data;
- (void) setTargetConfig: (S2S_TargetCfg)config;
- (S2S_TargetCfg) getTargetConfig;
- (NSString *) toXml;
- (BOOL) evaluate;

// Getters and setters for properties of the GUI...
- (BOOL) isEnabled;
- (NSUInteger) getSCSIId;
- (void) setDuplicateID: (BOOL)flag;
- (void) setSDSectorOverlap: (BOOL)flag;
- (NSRange) getSDSectorRange;
- (void) setAutoStartSectorValue: (NSUInteger)sector;

@end

NS_ASSUME_NONNULL_END
