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
    IBOutlet NSWindow *window;
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSTextField *infoLabel;

  
    IBOutlet NSPanel *dfuPanel;
    IBOutlet NSPanel *logPanel;
    IBOutlet NSTextView *dfuTextView;
    IBOutlet NSTextView *logTextView;
    
    IBOutlet NSTabView *tabView;
    IBOutlet DeviceController *device1;
    IBOutlet DeviceController *device2;
    IBOutlet DeviceController *device3;
    IBOutlet DeviceController *device4;
    IBOutlet DeviceController *device5;
    IBOutlet DeviceController *device6;
    IBOutlet DeviceController *device7;
    IBOutlet NSScroller *dfuScroller;
    IBOutlet NSScroller *logScroller;
    
    IBOutlet NSProgressIndicator *progress;

    IBOutlet NSMenuItem *saveMenu;
    IBOutlet NSMenuItem *openMenu;
    IBOutlet NSMenuItem *readMenu;
    IBOutlet NSMenuItem *writeMenu;
    IBOutlet NSMenuItem *scsiSelfTest;
    IBOutlet NSMenuItem *scsiLogData;

    IBOutlet SettingsController *settings;
    IBOutlet NSWindow *customAboutWindow;
}

- (IBAction) loadDefaults: (id)sender;
- (IBAction) scsiSelfTest:(id)sender;
- (IBAction) shouldLogScsiData: (id)sender;
- (IBAction) updateDFU2020: (id)sender;

- (void) evaluate;
- (void) logScsiData;

@end

