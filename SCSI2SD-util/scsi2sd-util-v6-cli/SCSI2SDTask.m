//
//  SCSI2SDTask.m
//  scsi2sd-util-cli
//
//  Created by Gregory Casamento on 1/10/20.
//  Copyright © 2020 RabbitHole Computing, LLC. All rights reserved.
//

#import "SCSI2SDTask.h"

#define MIN_FIRMWARE_VERSION 0x0400
#define MIN_FIRMWARE_VERSION 0x0400

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

@implementation SCSI2SDTask

+ (void) initialize
{
    if (self == [SCSI2SDTask class])
    {
        // nothing...
    }
}

+ (instancetype) task
{
    SCSI2SDTask *task = [[SCSI2SDTask alloc] init];
    return task;
}

- (void) handleDFUProgressNotification: (NSNotification *)note
{
    // NSNumber *n = (NSNumber *)[note object];
    // printf("%s percent \r",[[n stringValue] cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void) handleDFUNotification: (NSNotification *)note
{
    NSString *s = (NSString *)[note object];
    printf("%s",[s cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (instancetype) init
{
    self = [super init];
    if(self)
    {
        self.repeatMode = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDFUNotification:)
                                                     name:dfuOutputNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDFUProgressNotification:)
                                                     name:dfuProgressNotification
                                                   object:nil];
        myDFU = [[DeviceFirmwareUpdate alloc] init];
    }
    return self;
}


- (void) logStringToPanel: (NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
    printf("%s",[formatString cStringUsingEncoding:NSUTF8StringEncoding]);
    va_end(args);
}

- (void) updateProgress: (NSNumber *)n
{
    const char *string = [[n stringValue] cStringUsingEncoding:NSUTF8StringEncoding];
    printf("%s",string);
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
            [self logStringToPanel:msg];
        }
        
        myDFU = [[DeviceFirmwareUpdate alloc] init];
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

- (BOOL) getHid
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now == myLastPollTime) return NO;
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
                [self runScsiSelfTest];
            }
            else
            {
                char ticks[] = {'/', '-', '\\', '|'};
                myTickCounter++;
                [self logStringToPanel:@"Searching for SCSI2SD device %c", ticks[myTickCounter % sizeof(ticks)]];
            }
        }
    }
    @catch (NSException *e)
    {
        [self logStringToPanel:@"%@", [e reason]];
        return NO;
    }
    return YES;
}

- (void) waitForHidConnection
{
    puts("\nWaiting for HID connect...");
    while(![self getHid])
    {
        // nothing to do...
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

- (void)saveConfigs: (Pair *)configs
             toFile: (NSString *)filename
{
    if([filename isEqualToString:@""] || filename == nil)
        return;

    NSString *outputString = @"";
    outputString = [outputString stringByAppendingString: @"<SCSI2SD>\n"];
    NSString *string = [ConfigUtil boardCfgToXML: [configs boardCfg]];
    outputString = [outputString stringByAppendingString:string];

    NSUInteger i = 0;
    for(i = 0; i < [configs targetCount]; i++)
    {
        NSString *string = [ConfigUtil targetCfgToXML:[configs targetCfgAtIndex:i]];
        outputString = [outputString stringByAppendingString:string];
    }
    outputString = [outputString stringByAppendingString: @"</SCSI2SD>\n"];
    [outputString writeToFile:filename atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void) saveFromDeviceToFilename: (NSString *)filename
{
    BOOL gotHID = [self getHid];
    if(gotHID == NO)
    {
        [self logStringToPanel:@"Couldn't initialize HID configuration"];
        return;
    }
    
    if (!myHID) // goto out;
    {
        [self reset_hid];
    }
    
    if(!myHID)
    {
        [self logStringToPanel: @"Couldn't initialize HID configuration"];
    }

    [self logStringToPanel: @"\nSave config settings from device to file %@", filename];

    int currentProgress = 0;
    int totalProgress = 2;

    NSMutableData *cfgData = [NSMutableData dataWithLength: S2S_CFG_SIZE];
    uint32_t sector = [myHID getSDCapacity] - 2;
    for (size_t i = 0; i < 2; ++i)
    {
        [self logStringToPanel:  @"\nReading sector %d", sector];
        currentProgress += 1;
        if (currentProgress == totalProgress)
        {
            [self logStringToPanel:  @"\nSave from device Complete\n"];
        }

        NSMutableData *sdData = [NSMutableData data];
        @try
        {
            [myHID readSector:sector++ output:sdData];
        }
        @catch (NSException *e)
        {
            [self logStringToPanel:@"\nException: %@", [e reason]];
            return;
        }
        [cfgData appendData:sdData];
        /*
        std::copy(
            sdData.begin(),
            sdData.end(),
            &cfgData[i * 512]);*/
    }

    // Create structures...
    Pair *p = [[Pair alloc] init];
    for (int i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        NSRange dataRange = NSMakeRange(sizeof(S2S_BoardCfg) + i * sizeof(S2S_TargetCfg), sizeof(S2S_TargetCfg));
        NSData *subData = [cfgData subdataWithRange: dataRange];
        S2S_TargetCfg target = [ConfigUtil targetCfgFromBytes: subData]; // SCSI2SD::ConfigUtil::fromBytes(&cfgData[sizeof(S2S_BoardCfg) + i * sizeof(S2S_TargetCfg)]);
        [p addTargetConfig: target];
    }
    [p setBoardConfig:[ConfigUtil boardConfigFromBytes:cfgData]];
    
    // Build file...
    NSString *outputString = @"";
    outputString = [outputString stringByAppendingString: @"<SCSI2SD>\n"];
    outputString = [outputString stringByAppendingString:[ConfigUtil boardCfgToXML:[p boardCfg]]];
    for (int i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        NSString *deviceXML = [ConfigUtil targetCfgToXML: [p targetCfgAtIndex:i]];
        outputString = [outputString stringByAppendingString: deviceXML];
    }
    outputString = [outputString stringByAppendingString: @"</SCSI2SD>\n"];
    [outputString writeToFile:filename atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    
    // Complete progress...
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithDouble:(double)100.0]
                        waitUntilDone:NO];
    [NSThread sleepForTimeInterval:1.0];
    
    return;
}

- (void) saveToDeviceFromFilename: (NSString *)filename
{
    if(filename == nil || [filename isEqualToString:@""])
    {
        return;
    }
 
    [self getHid];

    if (!myHID) return;

    [self logStringToPanel:@"\nSaving configuration to Device from %@\n", filename];
    int currentProgress = 0;
    int totalProgress = 2; // (int)[deviceControllers count]; // * SCSI_CONFIG_ROWS + 1;

    // Write board config first.
    Pair *configs = [ConfigUtil fromXML: filename];
    NSMutableData *cfgData = [[ConfigUtil boardConfigToBytes:[configs boardCfg]] mutableCopy];
    for (int i = 0; i < S2S_MAX_TARGETS; ++i)
    {
        NSMutableData *raw = [[ConfigUtil targetCfgToBytes:[configs targetCfgAtIndex:i]] mutableCopy];
        [cfgData appendData: raw];
    }
    
    uint32_t sector = [myHID getSDCapacity] - 2; // myHID->getSDCapacity() - 2;
    for (size_t i = 0; i < 2; ++i)
    {
        [self logStringToPanel: @"\nWriting SD Sector %zu",sector];
        currentProgress += 1;

        if (currentProgress == totalProgress)
        {
            [self logStringToPanel: @"\nSave Complete\n"];
        }

        @try
        {
            NSRange range = NSMakeRange(i * 512, 512); // starting at sector i, get one sector of info...
            NSData *buf = [cfgData subdataWithRange:range];
            [myHID writeSector:sector++ input:  buf];
        }
        @catch (NSException *e)
        {
            [self logStringToPanel:  @"\nException %@",[e reason]];
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
 
    return;
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
    // unsigned char buf[0x80000]; // alloc 512k@@
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
            [self logStringToPanel: @"OTP Hardware version not set. Ignoring."];
            return YES;
        }
        else if (value == 0x06002020)
        {
            [self logStringToPanel: @"Found V6 2020 hardware marker"];
            return YES; //return firmware.rfind("firmware.V6.2020.dfu") != std::string::npos;
        }
        else if (value == 0x06002019)
        {
            [self logStringToPanel: @"Found V6 revF hardware marker"];
            // return firmware.rfind("firmware.V6.revF.dfu") != std::string::npos ||
            //    firmware.rfind("firmware.dfu") != std::string::npos;
            return YES;
        }
        else
        {
            [self logStringToPanel: @"Found unknown hardware marker: %u", value];
            return NO; // Some unknown version.
        }
    }
    
    free(buf);  // release the memory...
    return NO;
}


// Upgrade firmware...
- (void) upgradeFirmwareDeviceFromFilename: (NSString *)filename
{
    if ([[filename pathExtension] isEqualToString: @"dfu"] == NO)
    {
        [self logStringToPanel: @"SCSI2SD-V6 requires .dfu extension"];
        return;
    }
    
    BOOL versionChecked = NO;

    while (true)
    {
        @try
        {
            NSString *serial = nil;
            if (!myHID)
            {
                myHID = [HID open];
            }
            
            if (myHID)
            {
                serial = [myHID getSerialNumber];// myHID->getSerialNumber().c_str();
                [self runScsiSelfTest];  // run the scsi self test when updating the firmware.
                if (![myHID isCorrectFirmware:filename]) //  myHID->isCorrectFirmware(fn))
                {
                    [self logStringToPanel: @"Wrong filename!"];
                    [self logStringToPanel: @"Firmware does not match device hardware!"];
                    return;
                }
                versionChecked = YES;
                // versionChecked = false; // for testing...
                [self logStringToPanel: @"Resetting SCSI2SD into bootloader\n"];
                [myHID enterBootloader];
                myHID = nil;
            }

            if ([myDFU hasDevice] && !versionChecked) //  myDfu.hasDevice() && !versionChecked)
            {
                [self logStringToPanel:@"STM DFU Bootloader found, checking compatibility"];
                // [self updateProgress:[NSNumber numberWithFloat:0.0]];
                if (![self checkVersionMarker: filename])
                {
                    [self logStringToPanel: @"Wrong filename!"];
                    [self logStringToPanel: @"Firmware does not match device hardware!"];
                    return;
                }
                versionChecked = YES;
            }
            
            if ([myDFU hasDevice]) //  myDfu.hasDevice())
            {
                [self logStringToPanel: @"\n\nSTM DFU Bootloader found\n"];
                NSString *dfuPath = @"dfu-util"; // [[NSBundle mainBundle] pathForResource:@"dfu-util" ofType:@""];
                NSString *commandString = [NSString stringWithFormat:@"%@ -D %@ -a 0 -R", [dfuPath lastPathComponent], filename];
                NSArray *commandArray = [commandString componentsSeparatedByString: @" "];
                char **array = convertNSArrayToCArray(commandArray);
                int count = (int)[commandArray count];
                
                // Load firmware...
                dfu_util(count, array, NULL);

                // Detach...
                // commandString = [NSString stringWithFormat:@"%@ -e -a 0", [dfuPath lastPathComponent]];
                /*
                commandString = [NSString stringWithFormat:@"%@ -e -E 2 -a 0", [dfuPath lastPathComponent]];
                commandArray = [commandString componentsSeparatedByString:@" "];
                array = convertNSArrayToCArray(commandArray);
                count = (int)[commandArray count];
                dfu_util(count, array, NULL);
                */
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
}

@end
