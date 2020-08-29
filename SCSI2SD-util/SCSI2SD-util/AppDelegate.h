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

@class DeviceController;
@class SettingsController;

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
    NSMutableArray *deviceControllers;
}

@property  IBOutlet NSWindow *window;
@property  IBOutlet NSWindow *mainWindow;
@property  IBOutlet NSTextField *infoLabel;
@property  IBOutlet NSPanel *logPanel;
@property  IBOutlet NSPanel *dfuPanel;
@property  IBOutlet NSTextView *logTextView;
@property  IBOutlet NSTextView *dfuTextView;
@property  IBOutlet NSTabView *tabView;

@property  IBOutlet DeviceController *device1;
@property  IBOutlet DeviceController *device2;
@property  IBOutlet DeviceController *device3;
@property  IBOutlet DeviceController *device4;
@property  IBOutlet DeviceController *device5;
@property  IBOutlet DeviceController *device6;
@property  IBOutlet DeviceController *device7;

@property  IBOutlet NSProgressIndicator *progress;

@property  IBOutlet NSMenuItem *saveMenu;
@property  IBOutlet NSMenuItem *openMenu;
@property  IBOutlet NSMenuItem *readMenu;
@property  IBOutlet NSMenuItem *writeMenu;
@property  IBOutlet NSMenuItem *scsiSelfTest;
@property  IBOutlet NSMenuItem *scsiLogData;

@property  IBOutlet SettingsController *settings;
@property  IBOutlet NSWindow *customAboutWindow;

- (IBAction) loadDefaults: (id)sender;

@end

