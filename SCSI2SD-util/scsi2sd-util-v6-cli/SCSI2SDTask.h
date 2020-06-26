//
//  SCSI2SDTask.h
//  scsi2sd-util-cli
//
//  Created by Gregory Casamento on 1/10/20.
//  Copyright © 2020 RabbitHole Computing, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// #include "SCSI2SD_Bootloader.hh"
#include "SCSI2SD_HID.h"
#include "Firmware.h"
#include "scsi2sd.h"
#include "Functions.h"
#include "Dfu.hh"
#include "ConfigUtil.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCSI2SDTask : NSObject
{
    HID *myHID;
    time_t myLastPollTime;
    uint8_t myTickCounter;
    Dfu *myDfu;
}

@property (nonatomic, assign) BOOL repeatMode;

+ (instancetype) task;
- (BOOL) getHid;
- (void) waitForHidConnection;
- (void) saveFromDeviceToFilename: (NSString *)filename;
- (void) saveToDeviceFromFilename: (NSString *)filename;
- (void) upgradeFirmwareDeviceFromFilename: (NSString *)filename;
- (void) runScsiSelfTest;

@end

NS_ASSUME_NONNULL_END
