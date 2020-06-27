//	Copyright (C) 2014 Michael McMaster <michael@codesrc.com>
//  Copyright (C) 2020 Rabbit Hole Computing, LLC
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

#import <Foundation/Foundation.h>
#import "hidapi.h"

static const uint16_t VENDOR_ID = 0x16D0; // MCS
static const uint16_t PRODUCT_ID = 0x0BD4; // SCSI2SD
static const int CONFIG_INTERFACE = 0;
static const int DEBUG_INTERFACE = 1;
static const size_t HID_PACKET_SIZE = 64;

// HID intervals for 4.0.3 firmware: <= 128ms
// > 4.0.3 = 32ms.
static const size_t HID_TIMEOUT_MS = 256; // 2x HID Interval.

@interface HID : NSObject
{
    struct hid_device_info* myHidInfo;
    hid_device* myConfigHandle;

    // Read-only data from the debug interface.
    uint16_t myFirmwareVersion;
    uint32_t mySDCapacity;
}

- (instancetype) initWithHidInfo: (struct hid_device_info *) hidInfo;

+ (HID *) open;
- (void) close;

- (uint16_t) getFirmwareVersion; // uint16_t getFirmwareVersion() const { return myFirmwareVersion; }
- (NSString *) getFirmwareVersionStr; // () const;
- (uint32_t) getSDCapacity; //() const { return mySDCapacity; }
- (uint8_t *) getSD_CSD;
- (uint8_t *) getSD_CID;

- (BOOL) scsiSelfTest: (int*)code;
- (void) enterBootloader;

- (void) readSector: (uint32_t)sector output: (NSMutableData *)output;
- (void) writeSector: (uint32_t)sector input: (NSData *)input;
- (BOOL) ping;

- (BOOL) readSCSIDebugInfo: (NSMutableData *) buf;

- (NSString *) getSerialNumber;
- (NSString *) getHardwareVersion;
- (BOOL) isCorrectFirmware: (NSString *) path;

+ (HID *) hid: (struct hid_device_info *) hidInfo;
- (void) destroy;
- (void) readNewDebugData;
- (void) readHID: (uint8_t*)buffer length: (size_t)len;

- (void) sendHIDPacket: (NSMutableData *)cmdData
                output: (NSMutableData *)outputData
                length: (size_t)responseLength;

@end
