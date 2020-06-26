//	Copyright (C) 2016 Michael McMaster <michael@codesrc.com>
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

#include "Dfu.h"
#import <Foundation/Foundation.h>

@implementation Dfu

- (instancetype) init
{
    self = [super init];
    if (self != nil)
    {
        libusb_init(&m_usbctx);
    }
    return self;
}

- (void) dealloc
{
    if (m_usbctx)
    {
        libusb_exit(m_usbctx);
        m_usbctx = NULL;
    }
}

+ (Dfu *) dfu
{
    return [[self alloc] init];
}

- (BOOL) hasDevice
{
    bool found = NO;

    libusb_device **list;
    ssize_t cnt = libusb_get_device_list(m_usbctx, &list);
    ssize_t i = 0;
    if (cnt < 0) return false;

    for (i = 0; i < cnt; i++) {
        libusb_device *device = list[i];
        struct libusb_device_descriptor desc;
        libusb_get_device_descriptor(device, &desc);
        if (desc.idVendor == Vendor && desc.idProduct == Product )
        {
            found = YES;
            break;
        }
    }

    libusb_free_device_list(list, 1);
    return found;
}

@end
