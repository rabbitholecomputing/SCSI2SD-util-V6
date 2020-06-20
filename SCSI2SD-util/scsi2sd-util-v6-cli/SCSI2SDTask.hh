//
//  SCSI2SDTask.h
//  scsi2sd-util-cli
//
//  Created by Gregory Casamento on 1/10/20.
//  Copyright © 2020 RabbitHole Computing, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// #include "SCSI2SD_Bootloader.hh"
#include "SCSI2SD_HID.hh"
#include "Firmware.hh"
#include "scsi2sd.h"
#include "Functions.hh"
#include "Dfu.hh"
#include "ConfigUtil.hh"

NS_ASSUME_NONNULL_BEGIN

@interface SCSI2SDTask : NSObject
{
    std::shared_ptr<SCSI2SD::HID> myHID;
    time_t myLastPollTime;
    uint8_t myTickCounter;
    SCSI2SD::Dfu myDfu;

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
