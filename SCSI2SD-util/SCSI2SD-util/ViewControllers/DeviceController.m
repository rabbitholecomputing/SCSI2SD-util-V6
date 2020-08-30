//
//  DeviceController.m
//  scsi2sd
//
//  Created by Gregory Casamento on 12/3/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import "DeviceController.h"
#import "NSString+Extensions.h"

#include "ConfigUtil.h"
@interface DeviceController ()

@end

@implementation DeviceController

- (void) awakeFromNib
{
    [enableSCSITarget setToolTip: @"Enable this device"];
    SCSIID.toolTip = @"Unique SCSI ID for target device";
    deviceType.toolTip = @"Dervice type: HD, Removable, etc";
    sdCardStartSector.toolTip = @"Supports multiple SCSI targets";
    sectorSize.toolTip = @"Between 64 and 8192. Default of 512 is suitable in most cases.";
    sectorCount.toolTip = @"Number of sectors (device size)";
    deviceSize.toolTip = @"Device size";
    deviceUnit.toolTip = @"Units for device: GB, MB, etc";
    vendor.toolTip = @"SCSI Vendor string. eg. ' codesrc'";
    productId.toolTip = @"SCSI Product ID string. eg. 'SCSI2SD";
    revsion.toolTip = @"SCSI device revision string. eg. '3.5a'";
    serialNumber.toolTip = @"SCSI serial number. eg. '13eab5632a'";
    autoStartSector.toolTip = @"Auto start sector based on other targets";
    sectorsPerTrack.toolTip = @"Number of sectors in each track";
    headsPerCylinder.toolTip = @"Number of heads in cylinder";
    
    // Initial values
    autoErrorText.stringValue = @"";
    scsiIdErrorText.stringValue = @"";
}

- (NSData *) structToData: (S2S_TargetCfg)config withMutableData: (NSMutableData *)d
{
    [d appendBytes:&config length:sizeof(S2S_TargetCfg)];
    return [d copy];
}

- (NSData *) structToData: (S2S_TargetCfg)config
{
    return [self structToData:config withMutableData:[[NSMutableData alloc] init]];
}

- (S2S_TargetCfg) dataToStruct: (NSData *)d
{
    S2S_TargetCfg config;
    memcpy(&config, [d bytes], sizeof(S2S_TargetCfg));
    return config;
}

- (void) setTargetConfig: (S2S_TargetCfg)config
{
    NSData *d = [self structToData:config];
    [self performSelectorOnMainThread:@selector(setTargetConfigData:)
                           withObject:d
                        waitUntilDone:YES];
}

- (void) setTargetConfigData: (NSData *)data
{
    S2S_TargetCfg config = [self dataToStruct: data];

    enableSCSITarget.state = (config.scsiId & 0x80) ? NSOnState : NSOffState;
    [SCSIID setStringValue:
     [NSString stringWithFormat: @"%d", (config.scsiId & 0x80) ?
      (config.scsiId - 0x80) : config.scsiId]];
    [deviceType selectItemAtIndex: config.deviceType];
    [sdCardStartSector setStringValue:[NSString stringWithFormat:@"%d", config.sdSectorStart]];
    [sectorSize setStringValue: [NSString stringWithFormat: @"%d", config.bytesPerSector]];
    [sectorCount setStringValue: [NSString stringWithFormat: @"%d", config.scsiSectors]];
    [deviceSize setStringValue: [NSString stringWithFormat: @"%d", (((config.scsiSectors * config.bytesPerSector) / (1024 * 1024)) + 1) / 1024]];

    // Sectors per track...
    [vendor setStringValue: [NSString stringWithCString:config.vendor length:8]];
    [productId setStringValue: [NSString stringWithCString:config.prodId length:16]];
    [revsion setStringValue: [NSString stringWithCString:config.revision length:4]];
    [serialNumber setStringValue: [NSString stringWithCString:config.serial length:16]];
    [sectorsPerTrack setStringValue: [NSString stringWithFormat: @"%d", config.sectorsPerTrack]];
    [headsPerCylinder setStringValue: [NSString stringWithFormat: @"%d", config.headsPerCylinder]];
    // [autoStartSector setState:]
}

- (void) getTargetConfigData: (NSMutableData *)d
{
    S2S_TargetCfg targetConfig;
    targetConfig.scsiId = SCSIID.intValue & S2S_CFG_TARGET_ID_BITS;
    if (enableSCSITarget.state == NSOnState)
    {
        targetConfig.scsiId = targetConfig.scsiId | S2S_CFG_TARGET_ENABLED;
    }
    targetConfig.deviceType = deviceType.indexOfSelectedItem;
    targetConfig.sdSectorStart = sdCardStartSector.intValue;
    targetConfig.bytesPerSector = sectorSize.intValue;
    targetConfig.scsiSectors = sectorCount.intValue;
    targetConfig.headsPerCylinder = headsPerCylinder.intValue;
    targetConfig.sectorsPerTrack = sectorsPerTrack.intValue;
    strncpy(targetConfig.vendor, [vendor.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 8);
    strncpy(targetConfig.prodId, [productId.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 16);
    strncpy(targetConfig.revision, [revsion.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 4);
    strncpy(targetConfig.serial, [serialNumber.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 16);
    [self structToData: targetConfig withMutableData: d];
}

- (S2S_TargetCfg) getTargetConfig
{
    NSMutableData *d = [NSMutableData data];
    [self performSelectorOnMainThread:@selector(getTargetConfigData:)
                           withObject:d
                        waitUntilDone:YES];
    return  [self dataToStruct: d];
}

- (NSString *) toXml
{
    return [ConfigUtil targetCfgToXML: [self getTargetConfig]]; // [NSString stringWithCString:str.c_str() encoding:NSUTF8StringEncoding];
}

- (BOOL) evaluate
{
    // NSLog(@"fromXml");
    return YES;
}

- (BOOL) isEnabled
{
    return enableSCSITarget.state == NSOnState;
}

- (NSUInteger) getSCSIId
{
    return (NSUInteger)SCSIID.integerValue;
}

- (void) setDuplicateID: (BOOL)flag
{
    duplicateId = flag;
    if(flag)
        scsiIdErrorText.stringValue = @"Duplicate IDs.";
    else
        scsiIdErrorText.stringValue = @"";
}
- (void) setSDSectorOverlap: (BOOL)flag
{
    sectorOverlap = flag;
    if(flag)
        autoErrorText.stringValue = @"Sectors overlap.";
    else
        autoErrorText.stringValue = @"";
}

- (NSRange) getSDSectorRange
{
    return NSMakeRange(sdCardStartSector.integerValue,
                       sectorCount.integerValue);
}

- (void) setAutoStartSectorValue: (NSUInteger)sector
{
    sdCardStartSector.integerValue = (NSInteger)sector;
}
@end
