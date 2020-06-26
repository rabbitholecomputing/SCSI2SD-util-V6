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
#include "Dfu.h"

#ifndef GNUSTEP
@interface AppDelegate : NSObject <NSApplicationDelegate, NSComboBoxDataSource>
#else
@interface AppDelegate : NSObject <NSApplicationDelegate>
#endif
{
#ifndef GNUSTEP
    std::shared_ptr<SCSI2SD::HID> myHID;
#else
    SCSI2SD::HID *myHID;
#endif
    
    // std::shared_ptr<SCSI2SD::Bootloader> myBootloader;
    SCSI2SD::Dfu myDfu;
    
    bool myInitialConfig;
    //std::vector<TargetConfig *> myTargets;
    
    uint8_t myTickCounter;
    NSTimeInterval myLastPollTime;
    
    NSTimer *pollDeviceTimer;
    NSLock *aLock;
    
    BOOL shouldLogScsiData;
    BOOL doScsiSelfTest;
}

@end

