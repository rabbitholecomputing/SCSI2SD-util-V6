//
//  AppDelegate.h
//  scsi2sd
//
//  Created by Gregory Casamento on 7/23/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// #include "SCSI2SD_Bootloader.hh"
#include "SCSI2SD_HID.h"
// #include "Firmware.h"
#include "scsi2sd.h"
#include "Functions.h"
#include "DeviceFirmwareUpdate.h"

#ifndef GNUSTEP
@interface AppDelegate : NSObject <NSApplicationDelegate, NSComboBoxDataSource>
#else
@interface AppDelegate : NSObject <NSApplicationDelegate>
#endif
{
    HID *myHID;
    DeviceFirmwareUpdate *myDFU;
    
    BOOL myInitialConfig;
    
    uint8_t myTickCounter;
    NSTimeInterval myLastPollTime;
    
    NSTimer *pollDeviceTimer;
    NSLock *aLock;
    
    BOOL shouldLogScsiData;
    BOOL doScsiSelfTest;
}

- (void) evaluate;

@end

