//
//  AppDelegate.m
//  scsi2sd
//
//  Created by Gregory Casamento on 7/23/18.
//  Copyright © 2018 Open Logic. All rights reserved.
//

#import "AppDelegate.h"
#import "DeviceController.h"
#import "SettingsController.h"
#import <Foundation/NSDate.h>

#include <time.h>
#include <stdio.h>

// #include "z.h"
// #include "ConfigUtil.hh"
#define TIMER_INTERVAL 0.1

NSString *dfuOutputNotification = @"DFUOutputNotification";
NSString *dfuProgressNotification = @"DFUProgressNotification";

int dfu_util(int argc, char **argv, unsigned char *buf); // our one and only interface with the dfu library...

void dfu_printf(char *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *fmt = [NSString stringWithCString:format encoding:NSUTF8StringEncoding];
    NSString *formatString = [[NSString alloc] initWithFormat:fmt arguments:args];
    // NSLog(@"formatString = %@", formatString);
    [[NSNotificationCenter defaultCenter]
     postNotificationName: dfuOutputNotification
     object: formatString];
    va_end(args);
}

void dfu_report_progress(double percent)
{
    [[NSNotificationCenter defaultCenter]
     postNotificationName: dfuProgressNotification
     object: [NSNumber numberWithDouble:percent]];
}

void clean_exit_on_sig(int sig_num)
{
    NSLog(@"Signal %d received\n",sig_num);
    exit( 0 ); // exit cleanly...
}

char** convertNSArrayToCArray(NSArray *array)
{
    char **carray = NULL;
    int c = (int)[array count];
    
    carray = (char **)calloc(c, sizeof(char*));
    for (int i = 0; i < [array count]; i++)
    {
        NSString *s = [array objectAtIndex: i];
        char *cs = (char *)[s cStringUsingEncoding:NSUTF8StringEncoding];
        carray[i] = cs;
    }
    
    return carray;
}

char** convertNSArrayToCArrayForMain(NSArray *array)
{
    NSMutableArray *narray = [NSMutableArray arrayWithObject: @"dummy"]; // add dummy for executable name
    [narray arrayByAddingObjectsFromArray: array];
    return convertNSArrayToCArray([narray copy]);
}

BOOL RangesIntersect(NSRange range1, NSRange range2) {
    if(range1.location > range2.location + range2.length) return NO;
    if(range2.location > range1.location + range1.length) return NO;
    return YES;
}

#define MIN_FIRMWARE_VERSION 0x0400
#define MIN_FIRMWARE_VERSION 0x0400

@interface AppDelegate ()
{
    NSMutableArray *deviceControllers;
}

@property (nonatomic) IBOutlet NSWindow *window;
@property (nonatomic) IBOutlet NSWindow *mainWindow;
@property (nonatomic) IBOutlet NSTextField *infoLabel;
@property (nonatomic) IBOutlet NSPanel *logPanel;
@property (nonatomic) IBOutlet NSPanel *dfuPanel;
@property (nonatomic) IBOutlet NSTextView *logTextView;
@property (nonatomic) IBOutlet NSTextView *dfuTextView;
@property (nonatomic) IBOutlet NSTabView *tabView;

@property (nonatomic) IBOutlet DeviceController *device1;
@property (nonatomic) IBOutlet DeviceController *device2;
@property (nonatomic) IBOutlet DeviceController *device3;
@property (nonatomic) IBOutlet DeviceController *device4;
@property (nonatomic) IBOutlet DeviceController *device5;
@property (nonatomic) IBOutlet DeviceController *device6;
@property (nonatomic) IBOutlet DeviceController *device7;

@property (nonatomic) IBOutlet NSProgressIndicator *progress;

@property (nonatomic) IBOutlet NSMenuItem *saveMenu;
@property (nonatomic) IBOutlet NSMenuItem *openMenu;
@property (nonatomic) IBOutlet NSMenuItem *readMenu;
@property (nonatomic) IBOutlet NSMenuItem *writeMenu;
@property (nonatomic) IBOutlet NSMenuItem *scsiSelfTest;
@property (nonatomic) IBOutlet NSMenuItem *scsiLogData;

@property (nonatomic) IBOutlet SettingsController *settings;
@property (nonatomic) IBOutlet NSWindow *customAboutWindow;

@end

@implementation AppDelegate

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
// Update progress...
- (void) updateProgress: (NSNumber *)prog
{
    [self.progress setDoubleValue: [prog doubleValue]];
}

- (void) showProgress: (id)sender
{
    [self.progress setHidden:NO];
}

- (void) hideProgress: (id)sender
{
    [self.progress setHidden:YES];
}

- (IBAction)handleAboutPanel:(id)sender
{
    [self.customAboutWindow orderFrontRegardless];
}

- (IBAction)handleLogPanel:(id)sender {
    if ([self.logPanel isVisible])
    {
        [self.logPanel setIsVisible: NO];
    }
    else
    {
        [self.logPanel setIsVisible: YES];
        [self.logPanel orderFrontRegardless];
    }
}

- (IBAction)handleDFUPanel:(id)sender {
    if ([self.dfuPanel isVisible])
    {
        [self.dfuPanel setIsVisible: NO];
    }
    else
    {
        [self.dfuPanel setIsVisible: YES];
        [self.dfuPanel orderFrontRegardless];
    }
}

- (void) outputToPanel: (NSString* )formatString
{
    NSString *string = [self.logTextView string];
    string = [string stringByAppendingString: formatString];
    [self.logTextView setString: string];
    [self.logTextView scrollToEndOfDocument:self];
}

- (void) outputToDFUPanel: (NSString* )formatString
{
    NSString *string = [self.dfuTextView string];
    string = [string stringByAppendingString: formatString];
    [self.dfuTextView setString: string];
    [self.dfuTextView scrollToEndOfDocument:self];
}

// Output to the debug info panel...
- (void) logStringToPanel: (NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
    [self performSelectorOnMainThread:@selector(outputToPanel:)
                           withObject:formatString
                        waitUntilDone:YES];
    va_end(args);
}

// Output to the label...
- (void) logStringToLabel: (NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
    [self.infoLabel performSelectorOnMainThread:@selector(setStringValue:)
                                     withObject:formatString
                                  waitUntilDone:YES];
    va_end(args);
}

// dfu panel logging...
- (void) logStringToDFUPanel: (NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
    [self performSelectorOnMainThread:@selector(outputToDFUPanel:)
                           withObject:formatString
                        waitUntilDone:YES];
    va_end(args);
}


- (void) showWrongFilenamePanel: (id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];

    [self hideProgress:self];
    alert.messageText = @"Wrong filename";
    alert.informativeText = @"Firmware does not match device hardware";
    [alert runModal];
}

- (void) showReadCompletionPanel: (id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];

    [self hideProgress:self];
    alert.messageText = @"Operation Completed";
    alert.informativeText = @"Configuration was read from device";
    [alert runModal];
}

- (void) showWriteCompletionPanel: (id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];

    [self hideProgress:self];
    alert.messageText = @"Operation Completed";
    alert.informativeText = @"Configuration was written to device";
    [alert runModal];
}

// Start polling for the device...
- (void) startTimer
{
    pollDeviceTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)TIMER_INTERVAL
                                                       target:self
                                                     selector:@selector(doTimer)
                                                     userInfo:nil
                                                      repeats:YES];
}

// Pause the timer...
- (void) stopTimer
{
    [pollDeviceTimer invalidate];
}

// Reset the HID...
- (void) reset_hid
{
    @try
    {
        myHID = [HID open];
        if(myHID)
        {
            NSString *msg = [NSString stringWithFormat: @"SCSI2SD Ready, firmware version %@",[myHID getFirmwareVersionStr]];
            [self logStringToLabel:msg];
        }
    }
    @catch (NSException *e)
    {
        NSLog(@"Exception caught : %@\n", [e reason]);
    }
}

- (void) close_hid
{
    @try
    {
        myHID = nil;
    }
    @catch (NSException *e)
    {
        NSLog(@"Exception caught : %@\n", [e reason]);
    }
}

- (void) reset_bootloader
{
    @try
    {
        // myBootloader.reset(SCSI2SD::Bootloader::Open());
    }
    @catch (NSException *e)
    {
        NSLog(@"Exception caught : %@\n", [e reason]);
    }
}

- (void) handleDFUNotification: (NSNotification *)notification
{
    if ([NSThread currentThread] != [NSThread mainThread])
    {
        [self performSelectorOnMainThread:_cmd
                               withObject:notification
                            waitUntilDone:YES];
        return;
    }
    
    NSString *s = [notification object];
    [self logStringToDFUPanel:s];
}

- (void) handleDFUProgressNotification: (NSNotification *)notification
{
    if ([NSThread currentThread] != [NSThread mainThread])
    {
        [self performSelectorOnMainThread:_cmd
                               withObject:notification
                            waitUntilDone:YES];
        return;
    }
    
    NSNumber *n = [notification object];
    if ([n doubleValue] < 100.0)
    {
        [self showProgress:self];
    }
    else
    {
        NSAlert *alert = [[NSAlert alloc] init];

        [self hideProgress:self];

        alert.messageText = @"DFU Update Complete";
        alert.informativeText = @"The USB bus has been reset.  Please disconnect and reconnect device.";
        [alert runModal];
    }
    [self updateProgress:n];
}

// Initialize everything once we finish launching...
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    signal(SIGINT , clean_exit_on_sig);
    signal(SIGABRT , clean_exit_on_sig);
    signal(SIGILL , clean_exit_on_sig);
    signal(SIGFPE , clean_exit_on_sig);
    signal(SIGSEGV, clean_exit_on_sig); // <-- this one is for segmentation fault
    signal(SIGTERM , clean_exit_on_sig);
    
    @try
    {
        //myHID.reset(SCSI2SD::HID::Open());
        //myBootloader.reset(SCSI2SD::Bootloader::Open());
        [self reset_hid];
    }
    @catch (NSException *e)
    {
        NSLog(@"Exception caught : %@\n",[e reason]);
    }
    
    deviceControllers = [[NSMutableArray alloc] initWithCapacity: 7];
    [deviceControllers addObject: _device1];
    [deviceControllers addObject: _device2];
    [deviceControllers addObject: _device3];
    [deviceControllers addObject: _device4];
    [deviceControllers addObject: _device5];
    [deviceControllers addObject: _device6];
    [deviceControllers addObject: _device7];
    
    [self.tabView selectTabViewItemAtIndex:0];
    [self.progress setMinValue: 0.0];
    [self.progress setMaxValue: 100.0];
    
    doScsiSelfTest = NO;
    shouldLogScsiData = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDFUNotification:)
                                                 name:dfuOutputNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDFUProgressNotification:)
                                                 name:dfuProgressNotification
                                               object:nil];
    
    // Order out...
    [self.dfuPanel orderOut: self];
    [self.logPanel orderOut: self];
    
    [self startTimer];
    aLock = [[NSLock alloc] init];
    [self loadDefaults: nil];
}

// Shutdown everything when termination happens...
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
    [pollDeviceTimer invalidate];
    [deviceControllers removeAllObjects];
}

- (void) dumpScsiData: (NSMutableData *) buffer
{
    NSString *msg = @"";
    uint8_t *buf = (uint8_t *)[buffer bytes];
    for (size_t i = 0; i < 32 && i < [buffer length]; ++i)
    {
        msg = [msg stringByAppendingFormat:@"%02x ", buf[i]];
    }
    [self logStringToPanel: msg];
    [self logStringToPanel: @"\n"];
}

- (void) logSCSI
{
    if ([[self scsiSelfTest] state] == NSControlStateValueOn ||
        !myHID)
    {
        return;
    }
    @try
    {
        NSMutableData *info = [NSMutableData data];
        if ([myHID readSCSIDebugInfo:info])
        {
            [self dumpScsiData: info];
        }
    }
    @catch (NSException *e)
    {
        [self logStringToPanel: @"%@", [e reason]];
        myHID = nil;
    }
}

- (void) runScsiSelfTest
{
    int errcode;
    [self logStringToPanel: @"SCSI Self-Test: "];
    if ([myHID scsiSelfTest: &errcode])
    {
        [self logStringToPanel: @"Passed"];
    }
    else
    {
        [self logStringToPanel: @"FAIL (%d)", errcode];
    }
    [self logStringToPanel: @"\n"];
}

// Periodically check to see if Device is present...
- (void) doTimer
{
    [self logScsiData];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now == myLastPollTime) return;
    myLastPollTime = now;

    // Check if we are connected to the HID device.
    @try
    {
        if (myHID && ![myHID ping])
        {
            // Verify the USB HID connection is valid
            // myHID.reset();
            myHID = nil;
        }

        if (!myHID)
        {
            myHID = [HID open];
            if (myHID)
            {
                [self logStringToLabel: @"SCSI2SD Ready, firmware version %@", [myHID getFirmwareVersionStr]];
                [self logStringToPanel: @"SCSI2SD Ready, firmware version %@\n", [myHID getFirmwareVersionStr]];
                [self logStringToPanel: @"Hardware version: %@\n", [myHID getHardwareVersion]];
                [self logStringToPanel: @"Serial Number: %@\n", [myHID getSerialNumber]];
                uint8_t *csd = [myHID getSD_CSD];
                uint8_t *cid = [myHID getSD_CID];
                [self logStringToPanel: @"SD Capacity (512-byte sectors): %d\n", [myHID getSDCapacity]];

                [self logStringToPanel: @"SD CSD Register: "];
                for (size_t i = 0; i < 16 /*csd.size()*/; ++i)
                {
                    [self logStringToPanel: @"%0X", (int)csd[i]];
                }
                [self logStringToPanel: @"\nSD CID Register: "];
                for (size_t i = 0; i < 16 /*cid.size()*/; ++i)
                {
                    [self logStringToPanel: @"%0X", (int)cid[i]];
                }
                [self logStringToPanel: @"\n"];

                if ([[self scsiSelfTest] state] == NSControlStateValueOn)
                {
                    [self runScsiSelfTest];
                }

                if (!myInitialConfig)
                {
/* This doesn't work properly, and causes crashes.
                    wxCommandEvent loadEvent(wxEVT_NULL, ID_BtnLoad);
                    GetEventHandler()->AddPendingEvent(loadEvent);
*/
                }

            }
            else
            {
                char ticks[] = {'/', '-', '\\', '|'};
                myTickCounter++;
                [self logStringToLabel:@"Searching for SCSI2SD device %c", ticks[myTickCounter % sizeof(ticks)]];
            }
        }
    }
    @catch (NSException *e)
    {
        [self logStringToPanel:@"%@", [e reason]];
    }
    [self evaluate];
}

// Save XML file
- (void)saveFileEnd: (NSOpenPanel *)panel
{
    NSString *filename = [[panel directory] stringByAppendingPathComponent: [[panel filename] lastPathComponent]];
    if([filename isEqualToString:@""] || filename == nil)
        return;

    NSString *outputString = @"";
    filename = [filename stringByAppendingPathExtension:@"xml"];
    outputString = [outputString stringByAppendingString: @"<SCSI2SD>\n"];
    outputString = [outputString stringByAppendingString: [self->_settings toXml]];
    
    DeviceController *dc = nil;
    NSEnumerator *en = [self->deviceControllers objectEnumerator];
    while((dc = [en nextObject]) != nil)
    {
        outputString = [outputString stringByAppendingString: [dc toXml]];
    }
    outputString = [outputString stringByAppendingString: @"</SCSI2SD>\n"];
    NSError *error = nil;
    BOOL success = [outputString writeToFile:filename atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (NO == success)
    {
        NSLog(@"Error writing file %@", error);
    }
}

- (IBAction)saveFile:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel beginSheetForDirectory:NSHomeDirectory()
                             file:nil
                   modalForWindow:[self mainWindow]
                    modalDelegate:self
                   didEndSelector:@selector(saveFileEnd:)
                      contextInfo:nil];
}

// Open XML file...
- (void) openFileEnd: (NSOpenPanel *)panel
{
    @try
    {
        NSArray *paths = [panel filenames];
        if([paths count] == 0)
            return;
        
        NSString *path = [paths objectAtIndex: 0];
        char *sPath = (char *)[path cStringUsingEncoding:NSUTF8StringEncoding];
        Pair *configs = [ConfigUtil fromXML: path];
        
        // myBoardPanel->setConfig(configs.first);
        [self.settings setConfig: [configs boardCfg]];
        size_t i;
        for (i = 0; i < [configs targetCount] && i < [self->deviceControllers count]; ++i)
        {
            DeviceController *devCon = [self->deviceControllers objectAtIndex:i];
            [devCon setTargetConfig: [configs targetCfgAtIndex:i]];
        }

        for (; i < [self->deviceControllers count]; ++i)
        {
            DeviceController *devCon = [self->deviceControllers objectAtIndex:i];
            [devCon setTargetConfig: [configs targetCfgAtIndex: i]];
        }
    }
    @catch (NSException *e)
    {
        NSArray *paths = [panel filenames];
        NSString *path = [paths objectAtIndex: 0];
        [self logStringToPanel:[NSString stringWithFormat: @
            "Cannot load settings from file '%@'.\n%@",
            path,
            [e reason]]];
    }
}

- (IBAction)openFile:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles: YES];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"xml"]];
    [panel beginSheetForDirectory:nil
                             file:nil
                            types:[NSArray arrayWithObject: @"xml"]
                   modalForWindow:[self mainWindow]
                    modalDelegate:self
                   didEndSelector:@selector(openFileEnd:)
                      contextInfo:NULL];
}

// Load defaults into all configs...
- (IBAction) loadDefaults: (id)sender
{
    // myBoardPanel->setConfig(ConfigUtil::DefaultBoardConfig());
    [self.settings setConfig: [ConfigUtil defaultBoardConfig]];
    for (size_t i = 0; i < [deviceControllers count]; ++i)
    {
        // myTargets[i]->setConfig(ConfigUtil::Default(i));
        DeviceController *devCon = [self->deviceControllers objectAtIndex:i];
        [devCon setTargetConfig: [ConfigUtil defaultTargetConfig:i]];
    }
}

// Load from device...
- (void) loadFromDeviceThread: (id)obj
{
    [aLock lock];
    [self performSelectorOnMainThread:@selector(stopTimer)
                           withObject:NULL
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:0.0]
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(showProgress:)
                           withObject:nil
                        waitUntilDone:NO];

    // myHID.reset(SCSI2SD::HID::Open()); // reopen hid
    if (!myHID) // goto out;
    {
        return;
    }
    
    [self logStringToPanel: @"\nLoad config settings"];

    int currentProgress = 0;
    int totalProgress = 2;

    std::vector<uint8_t> cfgData(S2S_CFG_SIZE);
    uint32_t sector = myHID->getSDCapacity() - 2;
    for (size_t i = 0; i < 2; ++i)
    {
        [self logStringToPanel:  @"\nReading sector %d", sector];
        currentProgress += 1;
        if (currentProgress == totalProgress)
        {
            [self logStringToPanel:  @"\nLoad Complete\n"];
        }

        std::vector<uint8_t> sdData;
        try
        {
            myHID->readSector(sector++, sdData);
        }
        catch (std::runtime_error& e)
        {
            [self logStringToPanel:@"\nException: %s", e.what()];
            goto err;
        }

        std::copy(
            sdData.begin(),
            sdData.end(),
            &cfgData[i * 512]);
    }

    [_settings setConfig: SCSI2SD::ConfigUtil::boardConfigFromBytes(&cfgData[0])];
    for (int i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        DeviceController *dc = [deviceControllers objectAtIndex: i];
        S2S_TargetCfg target = SCSI2SD::ConfigUtil::fromBytes(&cfgData[sizeof(S2S_BoardCfg) + i * sizeof(S2S_TargetCfg)]);
        [dc setTargetConfig: target];
    }

    myInitialConfig = true;
    goto out;

err:
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:(double)100.0]
                        waitUntilDone:NO];
    [self logStringToPanel: @"\nLoad Failed."];
    goto out;

out:
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:(double)100.0]
                        waitUntilDone:NO];
    [NSThread sleepForTimeInterval:1.0];
    [self performSelectorOnMainThread:@selector(hideProgress:)
                           withObject:nil
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(startTimer)
                           withObject:NULL
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(showReadCompletionPanel:)
                           withObject:nil
                        waitUntilDone:NO];
    
    [aLock unlock];
    return;
}

- (IBAction)loadFromDevice:(id)sender
{
    [NSThread detachNewThreadSelector:@selector(loadFromDeviceThread:) toTarget:self withObject:self];
}

// Save information to device on background thread....
- (void) saveToDeviceThread: (id)obj
{
    [aLock lock];
    [self performSelectorOnMainThread:@selector(stopTimer)
                           withObject:NULL
                        waitUntilDone:NO];

    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:0.0]
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(showProgress:)
                           withObject:nil
                        waitUntilDone:NO];
    if (!myHID) return;

    [self logStringToPanel:@"Saving configuration"];
    int currentProgress = 0;
    int totalProgress = 2; // (int)[deviceControllers count]; // * SCSI_CONFIG_ROWS + 1;

    // Write board config first.
    std::vector<uint8_t> cfgData (
        SCSI2SD::ConfigUtil::boardConfigToBytes([self.settings getConfig]));
    for (int i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        std::vector<uint8_t> raw(
            SCSI2SD::ConfigUtil::toBytes([[deviceControllers objectAtIndex:i] getTargetConfig])
            );
        cfgData.insert(cfgData.end(), raw.begin(), raw.end());
    }
    
    uint32_t sector = myHID->getSDCapacity() - 2;
    for (size_t i = 0; i < 2; ++i)
    {
        [self logStringToPanel: @"\nWriting SD Sector %zu",sector];
        currentProgress += 1;

        if (currentProgress == totalProgress)
        {
            [self logStringToPanel: @"\nSave Complete\n"];
        }

        try
        {
            std::vector<uint8_t> buf;
            buf.insert(buf.end(), &cfgData[i * 512], &cfgData[(i+1) * 512]);
            myHID->writeSector(sector++, buf);
        }
        catch (std::runtime_error& e)
        {
            [self logStringToPanel:  @"\nException %s",e.what()];
            goto err;
        }
    }

    // [self reset_hid];
    goto out;

err:
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble: (double)100.0]
                        waitUntilDone:NO];
    [self logStringToPanel: @"\nSave Failed"];
    goto out;

out:
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble: (double)100.0]
                        waitUntilDone:NO];
    [NSThread sleepForTimeInterval:1.0];
    [self performSelectorOnMainThread:@selector(hideProgress:)
                           withObject:nil
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(startTimer)
                           withObject:NULL
                        waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(showWriteCompletionPanel:)
                           withObject:nil
                        waitUntilDone:NO];
    [aLock unlock];
    return;
}

- (IBAction)saveToDevice:(id)sender
{
    [NSThread detachNewThreadSelector:@selector(saveToDeviceThread:) toTarget:self withObject:self];
}

- (BOOL) checkVersionMarker: (NSString *)firmware
{
    NSString *tmpFile = [NSHomeDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"SCSI_MARKER-%f",
                                                                                 [[NSDate date] timeIntervalSince1970]]];
    NSString *cmdString = [NSString stringWithFormat: @"dfu-util --alt 2 -s 0x1FFF7800:4 -U \"%@\"", tmpFile];
    NSArray *commandArray = [cmdString componentsSeparatedByString: @" "];
    char **array = convertNSArrayToCArray(commandArray);
    int count = (int)[commandArray count];
    unsigned char *buf = NULL;
    
    buf = (unsigned char *)calloc(0x4000, sizeof(unsigned char));
    // unsigned char buf[0x80000]; // alloc 512k
    if (dfu_util(count, array, buf) == 0)
    {
        free(buf);
        return NO;
    }
    
    // NSData *fileData = [NSData dataWithContentsOfFile:tmpFile];
    if (buf != NULL)
    {
        const uint8_t *data = (const uint8_t *)buf;
        uint32_t value =
            (((uint32_t)(data[0]))) |
            (((uint32_t)(data[1])) << 8) |
            (((uint32_t)(data[2])) << 16) |
            (((uint32_t)(data[3])) << 24);
        
        if (value == 0xFFFFFFFF)
        {
            // Not set, ignore.
            [self logStringToDFUPanel: @"OTP Hardware version not set. Ignoring."];
            return YES;
        }
        else if (value == 0x06002020)
        {
            [self logStringToDFUPanel: @"Found V6 2020 hardware marker"];
            return YES; //return firmware.rfind("firmware.V6.2020.dfu") != std::string::npos;
        }
        else if (value == 0x06002019)
        {
            [self logStringToDFUPanel: @"Found V6 revF hardware marker"];
            // return firmware.rfind("firmware.V6.revF.dfu") != std::string::npos ||
            //    firmware.rfind("firmware.dfu") != std::string::npos;
            return YES;
        }
        else
        {
            [self logStringToDFUPanel: @"Found unknown hardware marker: %u", value];
            return NO; // Some unknown version.
        }
    }
    
    free(buf);  // release the memory...
    return NO;
}

// Upgrade firmware...
- (void) upgradeFirmwareThread: (NSString *)filename
{
    if ([[filename pathExtension] isEqualToString: @"dfu"] == NO)
    {
        [self logStringToPanel: @"SCSI2SD-V6 requires .dfu extension"];
        return;
    }

    [self.dfuPanel performSelectorOnMainThread: @selector( orderFrontRegardless )
                                    withObject: nil
                                 waitUntilDone: YES];
    
    [self performSelectorOnMainThread:@selector(stopTimer)
                           withObject:nil
                        waitUntilDone:YES];
    
    BOOL versionChecked = NO;
    while (true)
    {
        try
        {
            if (!myHID)
            {
#ifndef GNUSTEP
                myHID.reset(SCSI2SD::HID::Open());      
#else
                myHID = SCSI2SD::HID::Open();      
#endif            
            }
            
            if (myHID)
            {
                std::string fn = std::string([filename cStringUsingEncoding:NSUTF8StringEncoding]);
                if (!myHID->isCorrectFirmware(fn))
                {
                    [self hideProgress:self];

                    [self performSelectorOnMainThread:@selector(showWrongFilenamePanel:)
                                           withObject:self
                                        waitUntilDone:YES];
                    [self logStringToPanel: @"Firmware does not match hardware"];
                    return;
                }
                versionChecked = true;
                // versionChecked = false; // for testing...
                [self logStringToPanel: @"Resetting SCSI2SD into bootloader\n"];
                myHID->enterBootloader();
#ifndef GNUSTEP
                myHID.reset(); 
#else
                myHID = NULL; 
#endif 
            }

            if (myDfu.hasDevice() && !versionChecked)
            {
                 [self logStringToPanel:@"STM DFU Bootloader found, checking compatibility"];
                // [self updateProgress:[NSNumber numberWithFloat:0.0]];
                if (![self checkVersionMarker: filename])
                {
                    [self performSelectorOnMainThread:@selector(showWrongFilenamePanel:)
                                           withObject:self
                                        waitUntilDone:YES];
                    [self logStringToPanel: @"Firmware does not match hardware"];
                    return;
                }
                versionChecked = true;
            }
            
            if (myDfu.hasDevice())
            {
                [self logStringToPanel: @"\n\nSTM DFU Bootloader found\n"];
                NSString *dfuPath = @"dfu-util"; // [[NSBundle mainBundle] pathForResource:@"dfu-util" ofType:@""];
                NSString *commandString = [NSString stringWithFormat:@"%@ -D %@ -a 0 -R", [dfuPath lastPathComponent], filename];
                NSArray *commandArray = [commandString componentsSeparatedByString: @" "];
                char **array = convertNSArrayToCArray(commandArray);
                int count = (int)[commandArray count];
                
                // Load firmware
                dfu_util(count, array, NULL);
                [self reset_hid];
                [self performSelectorOnMainThread:@selector(reset_hid)
                                       withObject:nil
                                    waitUntilDone:YES];
                break;
            }
        }
        catch (std::exception& e)
        {
            [self logStringToPanel: @"%s",e.what()];
#ifndef GNUSTEP
            myHID.reset(); 
#else
            myHID = NULL; 
#endif 
        }
    }
    
    [self performSelectorOnMainThread:@selector(startTimer)
                           withObject:nil
                        waitUntilDone:YES];
}

- (void) upgradeFirmwareEnd: (NSOpenPanel *)panel
{
    NSArray *paths = [panel filenames];
    if([paths count] == 0)
        return;
    [NSThread detachNewThreadSelector:@selector(upgradeFirmwareThread:)
                             toTarget:self
                           withObject:[paths objectAtIndex:0]];
}

- (IBAction)upgradeFirmware:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel beginSheetForDirectory:NULL
                             file:NULL
                            types:[NSArray arrayWithObject:@"dfu"]
                   modalForWindow:[self mainWindow]
                    modalDelegate:self
                   didEndSelector: @selector(upgradeFirmwareEnd:)
                      contextInfo:NULL];
}

- (void)bootloaderUpdateThread: (NSString *)filename
{
}

- (void) bootLoaderUpdateEnd: (NSOpenPanel *)panel
{
    NSArray *paths = [panel filenames];
    if([paths count] == 0)
        return;

    NSString *filename = [paths objectAtIndex: 0];
    [NSThread detachNewThreadSelector:@selector(bootloaderUpdateThread:)
                             toTarget:self
                           withObject:filename];
}

- (IBAction)bootloaderUpdate:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel beginSheetForDirectory:nil
                             file:nil
                            types:nil
                   modalForWindow:[self mainWindow]
                    modalDelegate:self
                   didEndSelector:@selector(bootLoaderUpdateEnd:)
                      contextInfo:nil];
}


- (IBAction)scsiSelfTest:(id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    if(item.state == NSControlStateValueOn)
    {
        item.state = NSControlStateValueOff;
    }
    else
    {
        item.state = NSControlStateValueOn;
    }
    doScsiSelfTest = (item.state == NSControlStateValueOn);
}

- (IBAction) shouldLogScsiData: (id)sender
{
    NSMenuItem *item = (NSMenuItem *)sender;
    if(item.state == NSControlStateValueOn)
    {
        item.state = NSControlStateValueOff;
        [self logStringToPanel:@"END Logging SCSI info \n"];
    }
    else
    {
        item.state = NSControlStateValueOn;
        [self logStringToPanel:@"START Logging SCSI info \n"];
    }
    shouldLogScsiData = (item.state == NSControlStateValueOn);
}

- (void)logScsiData
{
    BOOL checkSCSILog = shouldLogScsiData;   // replce this with checking the menu status
    if (!checkSCSILog ||
        !myHID)
    {
        return;
    }
    try
    {
        std::vector<uint8_t> info(SCSI2SD::HID::HID_PACKET_SIZE);
        if (myHID->readSCSIDebugInfo(info))
        {
            [self dumpScsiData: info];
        }
    }
    catch (std::exception& e)
    {
        NSString *warning = [NSString stringWithFormat: @"Warning: %s", e.what()];
        [self logStringToPanel: warning];
        // myHID = SCSI2SD::HID::Open();
        [self reset_hid]; // myHID->reset();
    }
}

- (IBAction) autoButton: (id)sender
{
    // recalculate...
    NSButton *but = sender;
    if(but.state == NSOnState)
    {
        NSUInteger index = [sender tag]; // [deviceControllers indexOfObject:sender];
        if(index > 0)
        {
            NSUInteger j = index - 1;
            DeviceController *dev = [deviceControllers objectAtIndex:j];
            NSRange sectorRange = [dev getSDSectorRange];
            NSUInteger len = sectorRange.length;
            NSUInteger secStart = len + 1;
            DeviceController *devToUpdate = [deviceControllers objectAtIndex:index];
            [devToUpdate setAutoStartSectorValue:secStart];
        }
    }
}

- (void) evaluate
{
    BOOL valid = YES;
    
    // Check for duplicate SCSI IDs
    std::vector<uint8_t> enabledID;

    // Check for overlapping SD sectors.
    std::vector<std::pair<uint32_t, uint64_t> > sdSectors;

    bool isTargetEnabled = false; // Need at least one enabled
    for (size_t i = 0; i < [deviceControllers count]; ++i)
    {
        DeviceController *target = [deviceControllers objectAtIndex: i];
        
        // [target setAutoStartSectorValue: autoStartSector];
        valid = [target evaluate] && valid;
        if ([target isEnabled])
        {
            isTargetEnabled = true;
            uint8_t scsiID = [target getSCSIId];
            for (size_t j = 0; j < [deviceControllers count]; ++j)
            {
                DeviceController *t2 = [deviceControllers objectAtIndex: j];
                if (![t2 isEnabled] || t2 == target)
                    continue;
                
                uint8_t sid2 = [t2 getSCSIId];
                if(sid2 == scsiID)
                {
                    [target setDuplicateID:YES];
                    valid = false;
                }
                else
                {
                    [target setDuplicateID:NO];
                    valid = true;
                }
            }

            NSRange sdSectorRange = [target getSDSectorRange];
            NSUInteger total = 0;

            for (size_t k = 0; k < [deviceControllers count]; ++k)
            {
                DeviceController *t3 = [deviceControllers objectAtIndex: k];
                if (![t3 isEnabled] || t3 == target)
                    continue;

                NSRange sdr = [t3 getSDSectorRange];
                if(RangesIntersect(sdSectorRange, sdr))
                {
                    valid = false;
                    [target setSDSectorOverlap: YES];
                }
                else
                {
                    valid = true;
                    [target setSDSectorOverlap: NO];
                }
                
                total += sdr.length;
            }
            
            if (valid)
            {
                if (myHID)
                {
                    NSUInteger size = myHID->getSDCapacity();  // get the number of sectors...
                    if (total > size - 2) // if total sectors invades the config area...
                    {
                        valid = false;
                        [self logStringToLabel: @"Sectors exceed device size"];
                    }
                }
            }
            // sdSectors.push_back(sdSectorRange);
            // autoStartSector = sdSectorRange.second;
        }
        else
        {
            [target setDuplicateID:NO];
            [target setSDSectorOverlap:NO];
        }
    }

    valid = valid && isTargetEnabled; // Need at least one.
    
    if(myHID)
    {
        self.saveMenu.enabled = valid && (myHID->getFirmwareVersion() >= MIN_FIRMWARE_VERSION);
        self.openMenu.enabled = valid && (myHID->getFirmwareVersion() >= MIN_FIRMWARE_VERSION);
    }
/*
    mySaveButton->Enable(
        valid &&
        myHID &&
        (myHID->getFirmwareVersion() >= MIN_FIRMWARE_VERSION));

    myLoadButton->Enable(
        myHID &&
        (myHID->getFirmwareVersion() >= MIN_FIRMWARE_VERSION));
 */
    
}
#pragma GCC diagnostic pop


- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBox *)comboBox
{
    return 8;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox
{
    return 8;
}

- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [NSString stringWithFormat:@"%ld", (long)index];
}

- (nullable id)comboBoxCall:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [NSString stringWithFormat:@"%ld", (long)index];
}
@end
