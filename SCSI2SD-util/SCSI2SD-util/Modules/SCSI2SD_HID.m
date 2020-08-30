//	Copyright (C) 2014 Michael McMaster <michael@codesrc.com>
//
//	This file is part of SCSI2SD.
//
//	SCSI2SD is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	SCSI2SD is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with SCSI2SD.  If not, see <http://www.gnu.org/licenses/>.

#include "SCSI2SD_HID.h"
#include "scsi2sd.h"
#include "hidpacket.h"
#import "NSString+Extensions.h"

@implementation HID

- (instancetype) initWithHidInfo: (struct hid_device_info *) hidInfo
{
    self = [super init];
    if (self != nil)
    {
        myHidInfo = (struct hid_device_info *)hidInfo;
        myConfigHandle = NULL;
        myFirmwareVersion = 0;
        mySDCapacity = 0;
    
        @try {
            myConfigHandle = hid_open_path(myHidInfo->path);
            if (!myConfigHandle) [NSException raise: NSInternalInconsistencyException format: @"Unable to initialize config handle"];
            [self readNewDebugData];
        } @catch (NSException *exception) {
            [self destroy];
        } 
    }
    return self;
}

+ (HID *) open
{
    struct hid_device_info* dev = hid_enumerate(VENDOR_ID, PRODUCT_ID);
    if (dev)
    {
        return [HID hid: dev];
    }
    else
    {
        return nil;
    }
}

- (void) close
{
    
}

- (uint16_t) getFirmwareVersion
{
    return myFirmwareVersion;
}

- (NSString *) getFirmwareVersionStr
{
    NSString *ver = [NSString stringWithFormat: @"%d.%d", (myFirmwareVersion >> 8), ((myFirmwareVersion & 0xF0) >> 4)];
    int rev = myFirmwareVersion & 0xF;
    if (rev)
    {
        ver = [ver stringByAppendingFormat: @".%d", rev];
    }
    return ver;
}

- (uint32_t) getSDCapacity; //() const { return mySDCapacity; }
{
    return mySDCapacity;
}

- (uint8_t *) getSD_CSD
{
    uint8_t cmd[1] = { S2S_CMD_SDINFO };
    NSMutableData *output = [NSMutableData dataWithLength: 16];
    @try
    {
        [self sendHIDPacket:[NSMutableData dataWithBytes:cmd length:1]
                     output:output
                     length:16];
    }
    @catch (NSException *e)
    {
        return (uint8_t *)[output bytes];
    }

    return (uint8_t *)[[output subdataWithRange:NSMakeRange(0, 16)] bytes];
}

- (uint8_t *) getSD_CID
{
    uint8_t cmd[1] = { S2S_CMD_SDINFO };
    NSMutableData *outputData = [NSMutableData dataWithLength: 16];
    @try
    {
        [self sendHIDPacket:[NSMutableData dataWithBytes:cmd length:1]
                     output:outputData
                     length:16];
    }
    @catch (NSException *e)
    {
        return (uint8_t *)[outputData bytes];
    }
    
    uint8_t *result = (uint8_t *)calloc(16, sizeof(uint8_t));
    uint8_t *output = (uint8_t *)[outputData bytes];
    size_t i = 0;
    for (i = 0; i < 16; ++i) result[i] = output[16 + i];
    return result;
}

- (BOOL) scsiSelfTest: (int*)code
{
    uint8_t cmd[1] = { S2S_CMD_SCSITEST };
    NSMutableData *outputData = [NSMutableData data];
    @try
    {
        [self sendHIDPacket:[NSMutableData dataWithBytes:cmd length:1]
                     output:outputData
                     length:16];
    }
    @catch (NSException *e)
    {
        return NO;
    }
    
    *code = [outputData length] >= 2 ? ((uint8_t *)[outputData bytes])[1] : -1;
    return ([outputData length] >= 1) && (((uint8_t *)[outputData bytes])[1] == S2S_CFG_STATUS_GOOD);
}

- (void) enterBootloader
{
    uint8_t cmd[1] = { S2S_CMD_REBOOT };
    [self sendHIDPacket: [NSMutableData dataWithBytes:cmd length: 1]
                 output: [NSMutableData data]
                 length: 1];
}

- (void) readSector: (uint32_t)sector output: (NSMutableData *)output
{
    uint8_t cmd[5] =
    {
        S2S_CMD_SD_READ,
        (uint8_t)(sector >> 24),
        (uint8_t)(sector >> 16),
        (uint8_t)(sector >> 8),
        (uint8_t)(sector)
    };
    
    // output = (uint8_t *)calloc((HIDPACKET_MAX_LEN / 62), sizeof(uint8_t));
    [self sendHIDPacket: [NSMutableData dataWithBytes:cmd length: 5]
                 output: output
                 length: (HIDPACKET_MAX_LEN / 62)];
}

- (void) writeSector: (uint32_t)sector input: (NSData *)input
{
    uint8_t cmds[5] =
    {
        S2S_CMD_SD_WRITE,
        (uint8_t)(sector >> 24),
        (uint8_t)(sector >> 16),
        (uint8_t)(sector >> 8),
        (uint8_t)(sector)
    };
    // add input to commands...
    NSMutableData *cmdData = [NSMutableData dataWithCapacity: 1024];
    [cmdData appendBytes: cmds length: 5];
    [cmdData appendData: input];
    
    NSMutableData *output = [NSMutableData data];
    [self sendHIDPacket: cmdData
                 output: output
                 length: 1];
    
    if ([output length] < 1)
    {
        [NSException raise:NSInternalInconsistencyException format:@"Could not write sector"];
    }
    
    if (((int *)[output bytes])[0] != S2S_CFG_STATUS_GOOD)
    {
        [NSException raise:NSInternalInconsistencyException format:@"Could not write sector, got bad status"];
    }
}

- (BOOL) ping
{
    uint8_t cmd[1] = { S2S_CMD_PING };
    NSMutableData *output = [NSMutableData data];
    @try
    {
        [self sendHIDPacket:[NSMutableData dataWithBytes:cmd length:1]
                     output:output
                     length:1];
    }
    @catch (NSException *e)
    {
        return NO;
    }

    return ([output length] >= 1 && ((uint8_t *)[output bytes])[0] == S2S_CFG_STATUS_GOOD);
}

- (BOOL) readSCSIDebugInfo: (NSMutableData *) buf
{
    uint8_t cmd[1] = { S2S_CMD_DEBUG };
    [self sendHIDPacket:[NSMutableData dataWithBytes:cmd length:1] output:buf length:1];
    return [buf length] > 0;
}
    
- (NSString *) getSerialNumber
{
    const size_t maxUsbString = 255;
    wchar_t wstr[maxUsbString];
    int res = hid_get_serial_number_string(myConfigHandle, wstr, maxUsbString);
    if (res == 0)
    {
        NSString *string = [NSString stringFromWchar:wstr];
        return string;
    }

    return [NSString string];
}

- (NSString *) getHardwareVersion
{
    if (myFirmwareVersion < 0x0630)
    {
        // Definitely the 2020c or newer hardware.
        return @"V6, Rev F or older";
    }
    else if (myFirmwareVersion == 0x0630)
    {
        return @"V6, unknown.";
    }
    else
    {
        const size_t maxUsbString = 255;
        wchar_t wstr[maxUsbString];
        int res = hid_get_product_string(myConfigHandle, wstr, maxUsbString);
        if (res == 0)
        {
            NSString *prodStr = [NSString stringFromWchar:wstr];
            if ([prodStr rangeOfString:@"2020"].location != NSNotFound)
            {
                // Definitely the 2020c or newer hardware.
                return @"V6, 2020c or newer";
            }
            else
            {
                return @"V6, Rev F or older";
            }
        }
    }

    return @"Unknown";
}

- (BOOL) isCorrectFirmware: (NSString *) path
{
    if (myFirmwareVersion < 0x0630)
    {
        // Definitely the 2020c or newer hardware.
        return [path rangeOfString: @"firmware.V6.revF.dfu"].location != NSNotFound ||
            [path rangeOfString: @"firmware.dfu"].location != NSNotFound;
    }
    else if (myFirmwareVersion == 0x0630)
    {
        // We don't know which. :-( Initial batch of 2020 boards loaded with
        // v6.3.0
        // So for now we CANNOT bundle ? User will need to selet the correct
        // file.
        return YES;
    }
    else
    {
        const size_t maxUsbString = 255;
        wchar_t wstr[maxUsbString];
        int res = hid_get_product_string(myConfigHandle, wstr, maxUsbString);
        if (res == 0)
        {
            NSString *prodStr = [NSString stringFromWchar:wstr];
            if ([prodStr rangeOfString:@"2020"].location != NSNotFound)
            {
                // Definitely the 2020c or newer hardware.
                return [prodStr rangeOfString:@"firmware.V6.2020.dfu"].location != NSNotFound;
            }
            else
            {
                return [prodStr rangeOfString:@"firmware.V6.revF.dfu"].location != NSNotFound ||
                    [prodStr rangeOfString:@"firmware.dfu"].location != NSNotFound;
            }
        }
    }

    return NO;
}

+ (HID *) hid: (struct hid_device_info*) hidInfo
{
    return  [[HID alloc] initWithHidInfo:hidInfo];
}

- (void) destroy
{
    if (myConfigHandle)
    {
        hid_close(myConfigHandle);
        myConfigHandle = NULL;
    }

    hid_free_enumeration(myHidInfo);
    myHidInfo = NULL;
}

- (void) readNewDebugData
{
    // Newer devices only have a single HID interface, and present
    // a command to obtain the data
    uint8_t cmd[5] = { S2S_CMD_DEVINFO, 0xDE, 0xAD, 0xBE, 0xEF };
    NSMutableData *cmdData = [NSMutableData dataWithBytes:cmd length:5];
    NSMutableData *outData = [NSMutableData data];
    @try
    {
        [self sendHIDPacket:cmdData output:outData length:6];
    }
    @catch (NSException *ex)
    {
        myFirmwareVersion = 0;
        mySDCapacity = 0;
        return;
    }

    uint8_t *output = (uint8_t *)[outData bytes]; //.resize(6);
    myFirmwareVersion = (output[0] << 8) | output[1];
    mySDCapacity =
        (((uint32_t)output[2]) << 24) |
        (((uint32_t)output[3]) << 16) |
        (((uint32_t)output[4]) << 8) |
        ((uint32_t)output[5]);
}

- (void) readHID: (uint8_t*)buffer length: (size_t)len
{
    NSAssert(len >= 0, @"readHID length should be >= 0");
    buffer[0] = 0; // report id

    int result = -1;
    int retry = 0;
    for (retry = 0; retry < 3 && result <= 0; ++retry)
    {
        result = hid_read_timeout(myConfigHandle, buffer, len, HID_TIMEOUT_MS);
    }

    if (result < 0)
    {
        const wchar_t* err = hid_error(myConfigHandle);
        [NSException raise:NSInternalInconsistencyException format:@"USB HID Read Failure: %@", [NSString stringFromWchar:err]];
    }
}

- (void) sendHIDPacket: (NSMutableData *)cmdData
                output: (NSMutableData *)outputData
                length: (size_t)responseLength
{
    NSAssert([cmdData length] <= HIDPACKET_MAX_LEN, @"Packet length too long");
    uint8_t *cmd = (uint8_t *)[cmdData bytes];
    hidPacket_send(&cmd[0], [cmdData length]);

    uint8_t hidBuf[HID_PACKET_SIZE];
    const uint8_t* chunk = hidPacket_getHIDBytes(hidBuf);

    while (chunk)
    {
#ifndef __MINGW32__
        uint8_t reportBuf[HID_PACKET_SIZE + 1] = { 0x00 }; // Report ID
#else
        uint8_t reportBuf[HID_PACKET_SIZE + 1]; //  = { 0x00 }; // Report ID
	memset(reportBuf, 0, HID_PACKET_SIZE + 1);
#endif
        memcpy(&reportBuf[1], chunk, HID_PACKET_SIZE);
        int result = -1;
	int retry = 0;
        for (retry = 0; retry < 10 && result <= 0; ++retry)
        {
            result = hid_write(myConfigHandle, reportBuf, sizeof(reportBuf));
        }

        if (result <= 0)
        {
            const wchar_t* err = hid_error(myConfigHandle);
            [NSException raise:NSInternalInconsistencyException format:@"USB HID write failure: %@", [NSString stringFromWchar:err]];
        }
        chunk = hidPacket_getHIDBytes(hidBuf);
    }

    const uint8_t* resp = NULL;
    size_t respLen;
    resp = hidPacket_getPacket(&respLen);

    unsigned int retry = 0;
    for (retry = 0; retry < responseLength * 2 && !resp; ++retry)
    {
        [self readHID: hidBuf length:sizeof(hidBuf)];
        hidPacket_recv(hidBuf, HID_PACKET_SIZE);
        resp = hidPacket_getPacket(&respLen);
    }

    if (!resp)
    {
        [NSException raise:NSInternalInconsistencyException format:@"SCSI2SD config protocol error"];
    }

    // Append to the response...
    [outputData appendBytes:resp length: respLen];
}

- (void) dealloc
{ 
    [self destroy];
    [super dealloc];
}

@end
