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
    int i = 0;
    for (i = 0; i < [array count]; i++)
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

@implementation AppDelegate

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
// Update progress...
- (void) updateProgress: (NSNumber *)prog
{
    [progress setDoubleValue: [prog doubleValue]];
}

- (void) showProgress: (id)sender
{
    [progress setHidden:NO];
}

- (void) hideProgress: (id)sender
{
    [progress setHidden:YES];
}

- (IBAction)handleAboutPanel:(id)sender
{
    [customAboutWindow orderFrontRegardless];
}

- (IBAction)handleLogPanel:(id)sender {
    if ([logPanel isVisible])
    {
        [logPanel setIsVisible: NO];
    }
    else
    {
        [logPanel setIsVisible: YES];
        [logPanel orderFrontRegardless];
    }
}

- (IBAction)handleDFUPanel:(id)sender {
    if ([dfuPanel isVisible])
    {
        [dfuPanel setIsVisible: NO];
    }
    else
    {
        [dfuPanel setIsVisible: YES];
        [dfuPanel orderFrontRegardless];
    }
}

- (void) outputToPanel: (NSString* )formatString
{
    NSString *string = [logTextView string];
    string = [string stringByAppendingString: formatString];
    [logTextView setString: string];
    [logTextView scrollToEndOfDocument:self];
}

- (void) outputToDFUPanel: (NSString* )formatString
{
    NSString *string = [dfuTextView string];
    string = [string stringByAppendingString: formatString];
    [dfuTextView setString: string];
    [dfuTextView scrollToEndOfDocument:self];
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
    [infoLabel performSelectorOnMainThread:@selector(setStringValue:)
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

- (void) showReadErrorPanel: (id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];

    [self hideProgress:self];
    alert.messageText = @"Operation not Completed!!";
    alert.informativeText = @"Configuration was NOT read from device!!!";
    [alert runModal];
}

- (void) showWriteCompletionPanel: (id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];

    [self hideProgress:self];
    alert.messageText = @"Operation Completed!!";
    alert.informativeText = @"Configuration was written to device";
    [alert runModal];
}

- (void) showWriteErrorPanel: (id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];

    [self hideProgress:self];
    alert.messageText = @"Operation not Complete!!";
    alert.informativeText = @"Configuration was NOT written to device";
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
        
        myDFU = [[DeviceFirmwareUpdate alloc] init];
        NSLog(@"Allocated DFU");
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
        myDFU = [[DeviceFirmwareUpdate alloc] init];

    }
    @catch (NSException *e)
    {
        NSLog(@"Exception caught : %@\n",[e reason]);
    }
    
    deviceControllers = [[NSMutableArray alloc] initWithCapacity: 7];
    [deviceControllers addObject: device1];
    [deviceControllers addObject: device2];
    [deviceControllers addObject: device3];
    [deviceControllers addObject: device4];
    [deviceControllers addObject: device5];
    [deviceControllers addObject: device6];
    [deviceControllers addObject: device7];
    
    [tabView selectTabViewItemAtIndex:0];
    [progress setMinValue: 0.0];
    [progress setMaxValue: 100.0];
    
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
    [dfuPanel orderOut: self];
    [logPanel orderOut: self];
    
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
    size_t i = 0;
    for (i = 0; i < 32 && i < [buffer length]; ++i)
    {
        msg = [msg stringByAppendingFormat:@"%02x ", buf[i]];
    }
    [self logStringToPanel: msg];
    [self logStringToPanel: @"\n"];
}

- (void) logSCSI
{
    if ([scsiSelfTest state] == NSControlStateValueOn ||
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
		size_t i = 0;
                for (i = 0; i < 16 /*csd.size()*/; ++i)
                {
                    [self logStringToPanel: @"%0X", (int)csd[i]];
                }
                [self logStringToPanel: @"\nSD CID Register: "];
                for (i = 0; i < 16 /*cid.size()*/; ++i)
                {
                    [self logStringToPanel: @"%0X", (int)cid[i]];
                }
                [self logStringToPanel: @"\n"];

                if ([scsiSelfTest state] == NSControlStateValueOn)
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
    outputString = [outputString stringByAppendingString: [settings toXml]];
    
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
                   modalForWindow:[NSApp mainWindow]
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
        Pair *configs = [ConfigUtil fromXML: path];
        
        // myBoardPanel->setConfig(configs.first);
        [settings setConfig: [configs boardCfg]];
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
                   modalForWindow:[NSApp mainWindow]
                    modalDelegate:self
                   didEndSelector:@selector(openFileEnd:)
                      contextInfo:NULL];
}

// Load defaults into all configs...
- (IBAction) loadDefaults: (id)sender
{
    // myBoardPanel->setConfig(ConfigUtil::DefaultBoardConfig());
    [settings setConfig: [ConfigUtil defaultBoardConfig]];
    size_t i = 0;
    for (i = 0; i < [deviceControllers count]; ++i)
    {
        // myTargets[i]->setConfig(ConfigUtil::Default(i));
        DeviceController *devCon = [self->deviceControllers objectAtIndex:i];
        [devCon setTargetConfig: [ConfigUtil defaultTargetConfig:i]];
    }
}

// Load from device...
- (void) loadFromDeviceThread: (id)obj
{
    NSAutoreleasePool *my_pool = [[NSAutoreleasePool alloc] init];
    BOOL error = NO;
    
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
        error = YES;
        goto err;
    }
    
    [self logStringToPanel: @"\nLoad config settings"];

    int currentProgress = 0;
    int totalProgress = 2;

    NSMutableData *cfgData = [NSMutableData dataWithCapacity:S2S_CFG_SIZE];
    uint32_t sector = [myHID getSDCapacity] - 2;
    size_t i = 0;
    for (i = 0; i < 2; ++i)
    {
        [self logStringToPanel:  @"\nReading sector %d", sector];
        currentProgress += 1;
        if (currentProgress == totalProgress)
        {
            [self logStringToPanel:  @"\nLoad Complete\n"];
        }

        NSMutableData *sdData = [NSMutableData data];
        @try
        {
            [myHID readSector:sector++ output:sdData];
            // myHID->readSector(sector++, sdData);
        }
        @catch (NSException *e)
        {
            [self logStringToPanel:@"\nException: %@", [e reason]];
            goto err;
        }

        [cfgData appendData:sdData];
        /* std::copy(
            sdData.begin(),
            sdData.end(),
            &cfgData[i * 512]); */
    }

    [settings setConfig: [ConfigUtil boardConfigFromBytes: cfgData]];  //SCSI2SD::ConfigUtil::boardConfigFromBytes(&cfgData[0])];
    // int i = 0;
    for (i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        DeviceController *dc = [deviceControllers objectAtIndex: i];
        NSRange dataRange = NSMakeRange(sizeof(S2S_BoardCfg) + i * sizeof(S2S_TargetCfg), sizeof(S2S_TargetCfg));
        NSData *subData = [cfgData subdataWithRange: dataRange];
        S2S_TargetCfg target = [ConfigUtil targetCfgFromBytes: subData]; // SCSI2SD::ConfigUtil::fromBytes(&cfgData[sizeof(S2S_BoardCfg) + i * sizeof(S2S_TargetCfg)]);
        [dc setTargetConfig: target];
    }

    myInitialConfig = true;
    goto out;

err:
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:(double)100.0]
                        waitUntilDone:NO];
    [self logStringToPanel: @"\nLoad Failed."];
    [self reset_hid];
    error = YES;
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
    if (error)
    {
        [self performSelectorOnMainThread:@selector(showReadErrorPanel:)
                               withObject:nil
                            waitUntilDone:NO];
    }
    else
    {
      [self showReadCompletionPanel: self];
      /*
        [self performSelectorOnMainThread:@selector(showReadCompletionPanel:)
                               withObject:nil
                            waitUntilDone:NO]; */
    }
    
    [my_pool release];
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
    NSAutoreleasePool *my_pool = [[NSAutoreleasePool alloc] init];
    BOOL error = NO;
    
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
    if (!myHID)
    {
        error = YES;
        goto err;
    }

    [self logStringToPanel:@"Saving configuration"];
    int currentProgress = 0;
    int totalProgress = 2; // (int)[deviceControllers count]; // * SCSI_CONFIG_ROWS + 1;

    // Write board config first.

    NSMutableData *cfgData = [[ConfigUtil boardConfigToBytes:[settings getConfig]] mutableCopy];
    int i = 0;
    for (i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        NSData *raw = [ConfigUtil targetCfgToBytes:[[deviceControllers objectAtIndex:i] getTargetConfig]];
        [cfgData appendData:raw];
    }
    
    uint32_t sector = [myHID getSDCapacity]; //  myHID->getSDCapacity() - 2;
    // size_t i = 0;
    for (i = 0; i < 2; ++i)
    {
        [self logStringToPanel: @"\nWriting SD Sector %zu",sector];
        currentProgress += 1;

        if (currentProgress == totalProgress)
        {
            [self logStringToPanel: @"\nSave Complete\n"];
        }

        @try
        {
            NSRange r = NSMakeRange(i * 512, 512);
            NSData *sd = [cfgData subdataWithRange:r];
            [myHID writeSector:sector++ input: sd];
            /*
            std::vector<uint8_t> buf;
            buf.insert(buf.end(), &cfgData[i * 512], &cfgData[(i+1) * 512]);
            myHID->writeSector(sector++, buf);
             */
        }
        @catch (NSException *e)
        {
            [self logStringToPanel:  @"\nException %@",[e reason]];
            error = YES;
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
    [self reset_hid];
    error = YES;
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
    if (error)
    {
        [self performSelectorOnMainThread:@selector(showWriteErrorPanel:)
                               withObject:nil
                            waitUntilDone:NO];
    }
    else
    {
        [self performSelectorOnMainThread:@selector(showWriteCompletionPanel:)
                               withObject:nil
                            waitUntilDone:NO];
    }
    [my_pool release];
    [aLock unlock];
    return;

}

- (IBAction)saveToDevice:(id)sender
{
    [NSThread detachNewThreadSelector:@selector(saveToDeviceThread:) toTarget:self withObject:self];
}

- (BOOL) checkVersionMarker: (NSString *)firmware
{
    @try {
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
                [self logStringToDFUPanel: @"OTP Hardware version not set. Ignoring.\n"];
                return YES;
            }
            else if (value == 0x06002020)
            {
                [self logStringToDFUPanel: @"Found V6 2020 hardware marker\n"];
                return YES; //return firmware.rfind("firmware.V6.2020.dfu") != std::string::npos;
            }
            else if (value == 0x06002019)
            {
                [self logStringToDFUPanel: @"Found V6 revF hardware marker\n"];
                // return firmware.rfind("firmware.V6.revF.dfu") != std::string::npos ||
                //    firmware.rfind("firmware.dfu") != std::string::npos;
                return YES;
            }
            else
            {
                [self logStringToDFUPanel: @"Found unknown hardware marker: %u\n", value];
                return NO; // Some unknown version.
            }
        }
        
        free(buf);  // release the memory...

    }
    @catch (NSException *exception) {
        [self logStringToPanel: [exception reason]];
    }
    
    return NO;
}

// Upgrade firmware...
- (void) upgradeFirmwareThread: (NSString *)filename
{
    NSAutoreleasePool *my_pool = [[NSAutoreleasePool alloc] init];
    if ([[filename pathExtension] isEqualToString: @"dfu"] == NO)
    {
        [self logStringToPanel: @"SCSI2SD-V6 requires .dfu extension"];
        return;
    }

    [dfuPanel performSelectorOnMainThread: @selector( orderFrontRegardless )
                                    withObject: nil
                                 waitUntilDone: YES];
    
    [self performSelectorOnMainThread:@selector(stopTimer)
                           withObject:nil
                        waitUntilDone:YES];
    
    BOOL versionChecked = NO;
    while (YES)
    {
        @try
        {
            if (!myHID)
            {
                myHID = [HID open];
            }
            
            if (myHID)
            {
                if (![myHID isCorrectFirmware:filename])//!myHID->isCorrectFirmware(fn))
                {
                    [self hideProgress:self];

                    [self performSelectorOnMainThread:@selector(showWrongFilenamePanel:)
                                           withObject:self
                                        waitUntilDone:YES];
                    [self logStringToPanel: @"Firmware does not match hardware"];
                    return;
                }
                versionChecked = YES;
                // versionChecked = false; // for testing...
                [self logStringToPanel: @"Resetting SCSI2SD into bootloader\n"];
                [myHID enterBootloader];
                myHID = nil;
            }

            if ([myDFU hasDevice] && !versionChecked)
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
                versionChecked = YES;
            }
            
            if ([myDFU hasDevice])
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
        @catch (NSException *e)
        {
            [self logStringToPanel: @"%@",[e reason]];
            myHID = nil;
        }
    }
    
    [self performSelectorOnMainThread:@selector(startTimer)
                           withObject:nil
                        waitUntilDone:YES];
    [my_pool release];
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
                   modalForWindow:[NSApp mainWindow]
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
                   modalForWindow:[NSApp mainWindow]
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
    @try
    {
        // std::vector<uint8_t> info(SCSI2SD::HID::HID_PACKET_SIZE);
        NSMutableData *info = [NSMutableData dataWithCapacity:HID_PACKET_SIZE];
        if ([myHID readSCSIDebugInfo:info]) //myHID->readSCSIDebugInfo(info))
        {
            [self dumpScsiData: info];
        }
    }
    @catch (NSException *e)
    {
        NSString *warning = [NSString stringWithFormat: @"Warning: %@", [e reason]];
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

    // Check for overlapping SD sectors.

    bool isTargetEnabled = false; // Need at least one enabled
    size_t i = 0;
    for (i = 0; i < [deviceControllers count]; ++i)
    {
        DeviceController *target = [deviceControllers objectAtIndex: i];
        
        // [target setAutoStartSectorValue: autoStartSector];
        valid = [target evaluate] && valid;
        if ([target isEnabled])
        {
            isTargetEnabled = true;
            uint8_t scsiID = [target getSCSIId];
	    size_t j = 0;
            for (j = 0; j < [deviceControllers count]; ++j)
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

	    size_t k = 0;
            for (k = 0; k < [deviceControllers count]; ++k)
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
                    NSUInteger size = [myHID getSDCapacity];  // get the number of sectors...
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
        saveMenu.enabled = valid && ([myHID getFirmwareVersion] >= MIN_FIRMWARE_VERSION);
        openMenu.enabled = valid && ([myHID getFirmwareVersion] >= MIN_FIRMWARE_VERSION);
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

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [NSString stringWithFormat:@"%ld", (long)index];
}

- (id)comboBoxCall:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [NSString stringWithFormat:@"%ld", (long)index];
}
@end
