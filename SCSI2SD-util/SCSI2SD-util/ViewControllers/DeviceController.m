//
//  DeviceController.m
//  scsi2sd
//
//  Created by Gregory Casamento on 12/3/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import "DeviceController.h"
#import "NSString+Extensions.h"
#import "AppDelegate.h"

#include "ConfigUtil.h"
@interface DeviceController ()


@end

@implementation DeviceController

- (IBAction) enableSCSITarget:(id)sender
{
    NSButton *btn = (NSButton *)sender;
    self.autoStartSector.enabled = (btn.state == NSOnState);
}

- (void) awakeFromNib
{
    self.enableSCSITarget.toolTip = @"Enable this device";
    self.SCSIID.toolTip = @"Unique SCSI ID for target device";
    self.deviceType.toolTip = @"Dervice type: HD, Removable, etc";
    self.sdCardStartSector.toolTip = @"Supports multiple SCSI targets";
    self.sectorSize.toolTip = @"Between 64 and 8192. Default of 512 is suitable in most cases.";
    self.sectorCount.toolTip = @"Number of sectors (device size)";
    self.deviceSize.toolTip = @"Device size";
    self.deviceUnit.toolTip = @"Units for device: GB, MB, etc";
    self.vendor.toolTip = @"SCSI Vendor string. eg. ' codesrc'";
    self.productId.toolTip = @"SCSI Product ID string. eg. 'SCSI2SD";
    self.revsion.toolTip = @"SCSI device revision string. eg. '3.5a'";
    self.serialNumber.toolTip = @"SCSI serial number. eg. '13eab5632a'";
    self.autoStartSector.toolTip = @"Auto start sector based on other targets";
    self.sectorsPerTrack.toolTip = @"Number of sectors in each track";
    self.headsPerCylinder.toolTip = @"Number of heads in cylinder";
    
    // Initial values
    self.autoErrorText.stringValue = @"";
    self.scsiIdErrorText.stringValue = @"";
    
    // Set delegate..
    self.sectorCount.delegate = self;
    self.sdCardStartSector.delegate = self;
    self.deviceSize.delegate = self;

    // Set target action for some controls...
    [self.deviceUnit setTarget: self];
    [self.deviceUnit setAction: @selector(selectDeviceUnit:)];
    self.sdCardStartSector.delegate = self;
    self.sectorSize.delegate = self;
    self.sectorCount.delegate = self;
    self.deviceSize.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidChange:) name:NSControlTextDidChangeNotification object:nil];

    [self evaluate];
}

- (IBAction) selectDeviceUnit: (id)sender
{
    AppDelegate *delegate = (AppDelegate *)[NSApp delegate];
    NSUInteger num_sectors = [self convertUnitsToSectors];
    
    self.sectorCount.stringValue = [NSString stringWithFormat:@"%lld",(long long)num_sectors];
    
    [delegate evaluate];
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
    NSInteger sectors = (NSInteger)(config.scsiSectors);
    NSInteger bytesPerSector = (NSInteger)(config.bytesPerSector);
    NSInteger deviceSize = (NSInteger)((sectors * bytesPerSector) / (1024 * 1024 * 1024));
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];

    f.hasThousandSeparators = NO;
    self.enableSCSITarget.formatter = f;
    self.sdCardStartSector.formatter = f;
    self.sectorSize.formatter = f;
    self.sectorCount.formatter = f;
    self.sectorsPerTrack.formatter = f;
    self.headsPerCylinder.formatter = f;
    
    self.enableSCSITarget.state = (config.scsiId & S2S_CFG_TARGET_ENABLED) ? NSOnState : NSOffState;
    [self.SCSIID setStringValue:
     [NSString stringWithFormat: @"%d", (config.scsiId & S2S_CFG_TARGET_ID_BITS)]];
    [self.deviceType selectItemAtIndex: config.deviceType];
    [self.sdCardStartSector setStringValue:
     [[NSString stringWithFormat:@"%d", config.sdSectorStart] stringByReplacingOccurrencesOfString:@"," withString:@""]];
    [self.sectorSize setStringValue:
     [[NSString stringWithFormat: @"%d", config.bytesPerSector] stringByReplacingOccurrencesOfString:@"," withString:@""]];
    [self.sectorCount setStringValue:
     [[NSString stringWithFormat: @"%d", config.scsiSectors]  stringByReplacingOccurrencesOfString:@"," withString:@""]];
    [self.deviceSize setStringValue:
     [[NSString stringWithFormat: @"%lld", (long long)deviceSize] stringByReplacingOccurrencesOfString:@"," withString:@""]];
    [self.vendor setStringValue: [NSString stringWithCString:config.vendor length:8]];
    [self.productId setStringValue: [NSString stringWithCString:config.prodId length:16]];
    [self.revsion setStringValue: [NSString stringWithCString:config.revision length:4]];
    [self.serialNumber setStringValue: [NSString stringWithCString:config.serial length:16]];
    [self.sectorsPerTrack setStringValue:
     [[NSString stringWithFormat: @"%d", config.sectorsPerTrack] stringByReplacingOccurrencesOfString:@"," withString:@""]];
    [self.headsPerCylinder setStringValue:
     [[NSString stringWithFormat: @"%d", config.headsPerCylinder] stringByReplacingOccurrencesOfString:@"," withString:@""]];
    
    [f autorelease];
    
    [self evaluateSize];
}

- (void) getTargetConfigData: (NSMutableData *)d
{
    S2S_TargetCfg targetConfig;
    
    targetConfig.scsiId = self.SCSIID.intValue & S2S_CFG_TARGET_ID_BITS;
    if (self.enableSCSITarget.state == NSOnState)
    {
        targetConfig.scsiId = targetConfig.scsiId | S2S_CFG_TARGET_ENABLED;
    }
    targetConfig.deviceType = self.deviceType.indexOfSelectedItem;
    targetConfig.sdSectorStart = self.sdCardStartSector.intValue;
    targetConfig.bytesPerSector = self.sectorSize.intValue;
    targetConfig.scsiSectors = self.sectorCount.intValue;
    targetConfig.headsPerCylinder = self.headsPerCylinder.intValue;
    targetConfig.sectorsPerTrack = self.sectorsPerTrack.intValue;
    strncpy(targetConfig.vendor, [self.vendor.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 8);
    strncpy(targetConfig.prodId, [self.productId.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 16);
    strncpy(targetConfig.revision, [self.revsion.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 4);
    strncpy(targetConfig.serial, [self.serialNumber.stringValue cStringUsingEncoding:NSUTF8StringEncoding], 16);

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

- (BOOL) isEnabled
{
    return self.enableSCSITarget.state == NSOnState;
}

- (NSUInteger) getSCSIId
{
    return (NSUInteger)self.SCSIID.integerValue;
}

- (void) setDuplicateID: (BOOL)flag
{
    self.duplicateId = flag;
    if(flag)
        self.scsiIdErrorText.stringValue = @"Duplicate IDs.";
    else
        self.scsiIdErrorText.stringValue = @"";
}
- (void) setSDSectorOverlap: (BOOL)flag
{
    self.sectorOverlap = flag;
    if(flag)
        self.autoErrorText.stringValue = @"Sectors overlap.";
    else
        self.autoErrorText.stringValue = @"";
}

- (NSRange) getSDSectorRange
{
    return NSMakeRange(self.sdCardStartSector.integerValue,
                       self.sectorCount.integerValue);
}

- (void) setAutoStartSectorValue: (NSUInteger)sector
{
    self.sdCardStartSector.integerValue = (NSInteger)sector;
}

- (void) _recalcOnTextChange: (NSControl *)control
{
    if (control == self.sectorSize || control == self.sectorCount)
    {
        [self recalculate];
        [self evaluateSize];
    }
    else if (control == self.deviceSize)
    {
        NSInteger sc = [self convertUnitsToSectors];
        self.sectorCount.stringValue = [NSString stringWithFormat:@"%lld", (long long)sc];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *textfield = [notification object];
    if (textfield != self.vendor &&
        textfield != self.productId &&
        textfield != self.serialNumber &&
        textfield != self.revsion &&
        textfield != self.SCSIID &&
        textfield != self.sdCardStartSector &&
        textfield != self.deviceSize &&
        textfield != self.sectorCount &&
        textfield != self.sectorSize &&
        textfield != self.sectorsPerTrack &&
        textfield != self.headsPerCylinder)
    {
        return; // from another controller... return.
    }
    
    if (textfield != self.vendor &&
        textfield != self.productId &&
        textfield != self.serialNumber &&
        textfield != self.revsion)
    {
        NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];

        char *stringResult = (char *)malloc([textfield.stringValue length]);
        int cpt=0;
        for (int i = 0; i < [textfield.stringValue length]; i++) {
            unichar c = [textfield.stringValue characterAtIndex:i];
            if ([charSet characterIsMember:c]) {
                stringResult[cpt]=c;
                cpt++;
            }
            else
            {
                NSBeep();
            }
        }
        stringResult[cpt]='\0';
        textfield.stringValue = [NSString stringWithUTF8String:stringResult];
        free(stringResult);
        
        [self _recalcOnTextChange: textfield];
    }
}

- (void) recalculate
{
    [self evaluate];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    [self _recalcOnTextChange: control];
    return YES;
}

- (BOOL) evaluate
{
    BOOL valid = YES;
    BOOL enabled = self.enableSCSITarget.state == NSOnState;

    /*
    self.SCSIID.enabled = enabled;
    self.deviceType.enabled = enabled;
    self.sdCardStartSector.enabled = enabled;
    self.autoStartSector.enabled = enabled;
    self.sectorSize.enabled = enabled;
    self.sectorCount.enabled = enabled;
    self.deviceSize.enabled = enabled;
    self.deviceUnit.enabled = enabled;
    self.vendor.enabled = enabled;
    self.productId.enabled = enabled;
    self.revsion.enabled = enabled;
    self.serialNumber.enabled = enabled;*/

    switch (self.deviceType.indexOfSelectedItem)
    {
        case S2S_CFG_FLOPPY_14MB:
            self.sectorSize.stringValue = @"512";
            self.sectorSize.enabled = NO;
            self.sectorCount.stringValue = @"2880";
            self.sectorCount.enabled = NO;
            self.deviceUnit.enabled = NO;
            self.deviceSize.enabled = NO;

            [self evaluateSize];
            break;
    };

    NSUInteger sectorSize = self.sectorSize.integerValue;
    if (sectorSize < 64 || sectorSize > 8192)
    {
        // Set error (TBD)
        valid = NO;
    }
    else
    {
        // clear error (TBD)
    }
    
    NSUInteger numSectors = self.sectorCount.integerValue;
    if (numSectors == 0)
    {
        // myNumSectorMsg->SetLabelMarkup(wxT("<span foreground='red' weight='bold'>Invalid size</span>"));
        valid = NO;
    }
    else
    {
        // myNumSectorMsg->SetLabelMarkup("");
    }
    // [self evaluateSize];

    return valid || !enabled;
}

- (void) evaluateSize
{
    NSInteger numSectors = self.sectorCount.integerValue + 1;

    if (numSectors > 0)
    {
        NSInteger size = 0;
        NSInteger bytes = numSectors * self.sectorSize.integerValue;
        if (bytes >= 1024 * 1024 * 1024)
        {
            size = (bytes / (1024 * 1024 * 1024));
            NSMenuItem *item = [self.deviceUnit itemAtIndex:0]; // GB
            [self.deviceUnit selectItem:item];
        }
        else if (bytes >= 1024 * 1024)
        {
            size = (bytes / (1024 * 1024));
            NSMenuItem *item = [self.deviceUnit itemAtIndex:1]; // MB
            [self.deviceUnit selectItem:item];
        }
        else
        {
            size = (bytes / (1024));
            NSMenuItem *item = [self.deviceUnit itemAtIndex:2]; // KB
            [self.deviceUnit selectItem:item];
        }
        
        self.deviceSize.stringValue = [NSString stringWithFormat:@"%lld",(long long)size];
    }
}

- (NSUInteger) convertUnitsToSectors
{
    NSUInteger index = [self.deviceUnit indexOfSelectedItem];
    NSUInteger gb_size = 1024 * 1024 * 1024,
    mb_size = 1024 * 1024,
    kb_size = 1024;
    CGFloat size = (CGFloat)[[self.deviceSize stringValue] floatValue];
    NSUInteger sectorSize = (NSUInteger)[[self.sectorSize stringValue] integerValue];
    NSUInteger num_sectors = 0;
    NSUInteger size_factor = 0;
    
    switch (index)
    {
        case 0: // GB
            size_factor = gb_size;
            break;
        case 1: // MB
            size_factor = mb_size;
            break;
        case 2: // KB
            size_factor = kb_size;
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unexpected size selection"];
            break;
    }
    
    num_sectors = ((size * size_factor) / sectorSize);
    return num_sectors;
}
@end
