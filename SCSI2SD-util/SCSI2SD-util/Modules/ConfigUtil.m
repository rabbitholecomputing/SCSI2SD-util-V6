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

#include "ConfigUtil.h"

#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSException.h>
#import <AppKit/NSPanel.h>

#import "MF_Base64Additions.h"

// #include <wx/wxprec.h>
// #ifndef WX_PRECOMP
// #include <wx/wx.h>
// #endif
// #include <wx/base64.h>
// #include <wx/buffer.h>
// #include <wx/xml/xml.h>

bool isHostLE()
{
    union
    {
        int i;
        char c[sizeof(int)];
    } x;
    x.i = 1;
    return (x.c[0] == 1);
}

uint16_t toLE16(uint16_t in)
{
    if (isHostLE())
    {
        return in;
    }
    else
    {
        return (in >> 8) | (in << 8);
    }
}

uint16_t fromLE16(uint16_t in)
{
    return toLE16(in);
}

uint32_t toLE32(uint32_t in)
{
    if (isHostLE())
    {
        return in;
    }
    else
    {
        return (in >> 24) |
            ((in >> 8) & 0xff00) |
            ((in << 8) & 0xff0000) |
            (in << 24);
    }
}
uint32_t fromLE32(uint32_t in)
{
    return toLE32(in);
}

@implementation Pair

- (instancetype) init
{
    self = [super init];
    if (self != nil)
    {
        _targets = [[NSMutableArray alloc] initWithCapacity: 10];
    }
    return self;
}

- (instancetype) initWithBoardCfg: (S2S_BoardCfg)boardCfg
                     targetConfig: (S2S_TargetCfg *)targetCfgs
                            count: (NSUInteger)c
{
    self = [super init];
    if (self != nil)
    {
        int i = 0;
        _targets = [[NSMutableArray alloc] initWithCapacity: c];
        for (i = 0; i < c; i++)
        {
            [self addTargetConfig: targetCfgs[i]];
        }
        [self setBoardConfig: boardCfg];
    }
    return self;
}

- (S2S_BoardCfg) boardCfg
{
    return _boardCfg;
}

- (S2S_TargetCfg) targetCfgAtIndex: (NSUInteger)indx
{
    NSData *d = [_targets objectAtIndex: indx];
    S2S_TargetCfg c;
    memcpy(&c, [d bytes], sizeof(S2S_TargetCfg));
    return c;
}

- (void) setBoardConfig: (S2S_BoardCfg)boardCfg
{
    _boardCfg = boardCfg;
}

- (void) addTargetConfig: (S2S_TargetCfg)targetCfg
{
    NSData *d = [NSData dataWithBytes:&targetCfg length:sizeof(S2S_TargetCfg)];
    [_targets addObject: d];
}

- (NSUInteger) targetCount
{
    return [_targets count];
}

@end

@implementation ConfigUtil

+ (S2S_BoardCfg) defaultBoardConfig
{
    S2S_BoardCfg config;
    memset(&config, 0, sizeof(config));

    memcpy(config.magic, "BCFG", 4);


    // Default to maximum fail-safe options.
    config.flags6 = S2S_CFG_ENABLE_TERMINATOR;
    config.selectionDelay = 255; // auto

    return config;
}

+ (S2S_TargetCfg) defaultTargetConfig: (size_t) targetIdx
{
    S2S_TargetCfg config;
    memset(&config, 0, sizeof(config));

    config.scsiId = targetIdx;
    if (targetIdx == 0)
    {
        config.scsiId = config.scsiId | S2S_CFG_TARGET_ENABLED;
    }
    config.deviceType = S2S_CFG_FIXED;

    // Default to maximum fail-safe options.
    config.flagsDEPRECATED = 0;
    config.deviceTypeModifier = 0;
    config.sdSectorStart = 0;

    // Default to 2GB. Many systems have trouble with > 2GB disks, and
    // a few start to complain at 1GB.
    config.scsiSectors = 4194303; // 2GB - 1 sector
    config.bytesPerSector = 512;
    config.sectorsPerTrack = 63;
    config.headsPerCylinder = 255;
    memcpy(config.vendor, " codesrc", 8);
    memcpy(config.prodId, "         SCSI2SD", 16);
    memcpy(config.revision, " 6.0", 4);
    memcpy(config.serial, "1234567812345678", 16);

    return config;
}

+ (S2S_TargetCfg) targetCfgFromBytes: (NSData *) data
{
    S2S_TargetCfg result;
    memcpy(&result, [data bytes], sizeof(S2S_TargetCfg));
    result.sdSectorStart = toLE32(result.sdSectorStart);
    result.scsiSectors = toLE32(result.scsiSectors);
    result.bytesPerSector = toLE16(result.bytesPerSector);
    result.sectorsPerTrack = (result.sectorsPerTrack == 0 ? 63 : toLE16(result.sectorsPerTrack));  // some devices ignore this.
    result.headsPerCylinder = toLE16(result.headsPerCylinder);
    return result;
}

+ (NSData *) targetCfgToBytes: (const S2S_TargetCfg) _config
{
    S2S_TargetCfg config = (S2S_TargetCfg)_config;
    config.sdSectorStart = fromLE32(_config.sdSectorStart);
    config.scsiSectors = fromLE32(_config.scsiSectors);
    config.bytesPerSector = fromLE16(_config.bytesPerSector);
    config.sectorsPerTrack = fromLE16(_config.sectorsPerTrack);
    config.headsPerCylinder = fromLE16(_config.headsPerCylinder);

    NSData *result = [NSData dataWithBytes: &config
                                    length: sizeof(S2S_TargetCfg)];
    return result;
}

+ (S2S_BoardCfg) boardConfigFromBytes: (NSData *) data
{
    S2S_BoardCfg result;
    memcpy(&result, [data bytes], sizeof(S2S_BoardCfg));

    if (memcmp("BCFG", result.magic, 4))
    {
        return [self defaultBoardConfig];
    }

    return result;
}

+ (NSData *) boardConfigToBytes: (const S2S_BoardCfg) cfg
{
    S2S_BoardCfg config = (S2S_BoardCfg)cfg;
    memcpy(&config.magic, "BCFG", 4);
    // const uint8_t* begin = reinterpret_cast<const uint8_t*>(&config);
    // return std::vector<uint8_t>(begin, begin + sizeof(config));
    NSData *data = [NSData dataWithBytes: &config length: sizeof(S2S_BoardCfg)];
    return data;
}

+ (NSString *) targetCfgToXML: (const S2S_TargetCfg) config
{
    NSString *s = nil;

    s =
        @"<SCSITarget id=\"%d\">\n"
        @"    <enabled>%s</enabled>\n"
        @"\n"
        @"    <!-- ********************************************************\n"
        @"    Space separated list. Available options:\n"
        @"    apple\t\tReturns Apple-specific mode pages\n"
        @"    omti\t\tOMTI host non-standard link control\n"
        @"    xebec\t\tXEBEC ignore step options in control byte\n"
        @"    ********************************************************* -->\n"
        @"    <quirks>";
    if (config.quirks == S2S_CFG_QUIRKS_APPLE)
    {
        s = [s stringByAppendingString: @"apple "];
    }
    else if (config.quirks == S2S_CFG_QUIRKS_OMTI)
    {
        s = [s stringByAppendingString: @"omti "];
    }
    else if (config.quirks == S2S_CFG_QUIRKS_XEBEC)
    {
        s = [s stringByAppendingString: @"xebec "];
    }
    else if (config.quirks == S2S_CFG_QUIRKS_VMS)
    {
        s = [s stringByAppendingString: @"vms "];
    }

    s = [s stringByAppendingString:
            @"</quirks>\n"
        @"\n\n"
        @"    <!-- ********************************************************\n"
        @"    0x0    Fixed hard drive.\n"
        @"    0x1    Removable drive.\n"
        @"    0x2    Optical drive  (ie. CD drive).\n"
        @"    0x3    1.44MB Floppy Drive.\n"
        @"    ********************************************************* -->\n"
        @"    <deviceType>%x</deviceType>\n"
        @"\n\n"
        @"    <!-- ********************************************************\n"
        @"    Device type modifier is usually 0x00. Only change this if your\n"
        @"    OS requires some special value.\n"
        @"\n"
        @"    0x4C    Data General Micropolis disk\n"
        @"    ********************************************************* -->\n"
        @"    <deviceTypeModifier>%x</deviceTypeModifier>\n"
        @"\n\n"
        @"    <!-- ********************************************************\n"
        @"    SD card offset, as a sector number (always 512 bytes).\n"
        @"    ********************************************************* -->\n"
        @"    <sdSectorStart>%d</sdSectorStart>\n"
        @"\n\n"
        @"    <!-- ********************************************************\n"
        @"    Drive geometry settings.\n"
        @"    ********************************************************* -->\n"
        @"\n"
        @"    <scsiSectors>%d</scsiSectors>\n"
        @"    <bytesPerSector>%d</bytesPerSector>\n"
        @"    <sectorsPerTrack>%d</sectorsPerTrack>\n"
        @"    <headsPerCylinder>%d</headsPerCylinder>\n"
        @"\n\n"
        @"    <!-- ********************************************************\n"
        @"    Drive identification information. The SCSI2SD doesn't\n"
        @"    care what these are set to. Use these strings to trick a OS\n"
        @"    thinking a specific hard drive model is attached.\n"
        @"    ********************************************************* -->\n"
        @"\n"
        @"    <!-- 8 character vendor string -->\n"
        @"    <!-- For Apple HD SC Setup/Drive Setup, use ' SEAGATE' -->\n"
        @"    <vendor>%@</vendor>\n"
        @"\n"
        @"    <!-- 16 character produce identifier -->\n"
        @"    <!-- For Apple HD SC Setup/Drive Setup, use '          ST225N' -->\n"
        @"    <prodId>%@</prodId>\n"
        @"\n"
        @"    <!-- 4 character product revision number -->\n"
        @"    <!-- For Apple HD SC Setup/Drive Setup, use '1.0 ' -->\n"
        @"    <revision>%@</revision>\n"
        @"\n"
        @"    <!-- 16 character serial number -->\n"
        @"    <serial>%@</serial>\n"
        @"\n"
        @"</SCSITarget>\n"];
        
    char vendor[9] =    "        \0";
    char prodId[17] =   "                \0";
    char revision[5] =  "    \0";
    char serial[17] =   "                \0";
    memcpy(vendor, config.vendor, 8);
    memcpy(prodId, config.prodId, 16);
    memcpy(revision, config.revision, 4);
    memcpy(serial, config.serial, 8);
    NSString *str = [NSString stringWithFormat:s,
                     (int)config.scsiId, // & S2S_CFG_TARGET_ID_BITS,
                     config.scsiId & S2S_CFG_TARGET_ENABLED ? "true" : "false",
                     config.deviceType,
                     config.deviceTypeModifier,
                     config.sdSectorStart,
                     config.scsiSectors,
                     config.bytesPerSector,
                     config.sectorsPerTrack,
                     config.headsPerCylinder,
                     [[NSString stringWithCString: vendor encoding:NSUTF8StringEncoding] substringToIndex:8],
                     [[NSString stringWithCString: prodId encoding:NSUTF8StringEncoding] substringToIndex:16],
                     [[NSString stringWithCString: revision encoding:NSUTF8StringEncoding] substringToIndex:4],
                     [[NSString stringWithCString: serial encoding:NSUTF8StringEncoding] substringToIndex:16]
                     ];
    
    return str;
}

+ (NSString *) boardCfgToXML: (const S2S_BoardCfg) config
{
    NSString *s = nil;

    s = @"<S2S_BoardCfg>\n"
        @"    <!-- ********************************************************\n"
        @"    Enable the onboard active terminator.\n"
        @"    Both ends of the SCSI chain should be terminated. Disable\n"
        @"    only if the SCSI2SD is in the middle of a chain with other\n"
        @"    devices.\n"
        @"    ********************************************************* -->\n"
        @"    <enableTerminator>%s</enableTerminator>\n"
        @"    <unitAttention>%s</unitAttention>\n"
        @"    <parity>%s</parity>\n"
        @"    <!-- ********************************************************\n"
        @"    Only set to true when using with a fast SCSI2 host\n "
        @"    controller. This can cause problems with older/slower\n"
        @"    hardware.\n"
        @"    ********************************************************* -->\n"
        @"    <enableScsi2>%s</enableScsi2>\n"
        @"    <!-- ********************************************************\n"
        @"    Respond to very short duration selection attempts. This supports\n"
        @"    non-standard hardware, but is generally safe to enable.\n"
        @"    Required for Philips P2000C.\n"
        @"    ********************************************************* -->\n"
        @"    <selLatch>%s</selLatch>\n"
        @"    <!-- ********************************************************\n"
        @"    Convert luns to IDs. The unit must already be configured to respond\n"
        @"    on the ID. Allows dual drives to be accessed from a \n"
        @"    XEBEC S1410 SASI bridge.\n"
        @"    eg. Configured for dual drives as IDs 0 and 1, but the XEBEC will\n"
        @"    access the second disk as ID0, lun 1.\n"
        @"    See ttp://bitsavers.trailing-edge.com/pdf/xebec/104524C_S1410Man_Aug83.pdf\n"
        @"    ********************************************************* -->\n"
        @"    <mapLunsToIds>%s</mapLunsToIds>\n"
        @"    <!-- ********************************************************\n"
        @"    Delay (in milliseconds) before responding to a SCSI selection.\n"
        @"    255 (auto) sets it to 0 for SCSI2 hosts and 1ms otherwise.\n"
        @"    Some samplers need this set to 1 manually.\n"
        @"    ********************************************************* -->\n"
        @"    <selectionDelay>%d</selectionDelay>\n"
        @"    <!-- ********************************************************\n"
        @"    Startup delay (in seconds) before responding to the SCSI bus \n"
        @"    after power on. Default = 0.\n"
        @"    ********************************************************* -->\n"
        @"    <startupDelay>%d</startupDelay>\n"
        @"    <!-- ********************************************************\n"
        @"    Speed limit the SCSI interface. This is the -max- speed the \n"
        @"    device will run at. The actual spee depends on the capability\n"
        @"    of the host controller.\n"
        @"    0    No limit\n"
        @"    1    Async 1.5MB/s\n"
        @"    2    Async 3.3MB/s\n"
        @"    3    Async 5MB/s\n"
        @"    4    Sync 5MB/s\n"
        @"    5    Sync 10MB/s\n"
        @"    ********************************************************* -->\n"
        @"    <scsiSpeed>%d</scsiSpeed>\n"
        @"    <!-- ********************************************************"
        @"    Enable SD card blind writes, which starts writing to the SD"
        @"    card before all the SCSI data has been received. Can cause problems"
        @"    with some SCSI hosts"
        @"    ********************************************************* -->"
        @"    <blindWrites>%d</blindWrites>"
        @"</S2S_BoardCfg>\n";
    
    NSString *str = [NSString stringWithFormat:s,
                     (config.flags6 & S2S_CFG_ENABLE_TERMINATOR ? "true" : "false"),
                     (config.flags & S2S_CFG_ENABLE_UNIT_ATTENTION ? "true" : "false"),
                     (config.flags & S2S_CFG_ENABLE_PARITY ? "true" : "false"),
                     (config.flags & S2S_CFG_ENABLE_SCSI2 ? "true" : "false"),
                     (config.flags & S2S_CFG_ENABLE_SEL_LATCH? "true" : "false"),
                     (config.flags & S2S_CFG_MAP_LUNS_TO_IDS ? "true" : "false"),
                     config.selectionDelay,
                     config.startupDelay,
                     config.scsiSpeed,
                     config.flags6 & S2S_CFG_ENABLE_BLIND_WRITES];
    
    return str;
}

+ (uint64_t) parseInt: (NSXMLNode *)node limit: (uint64_t) limit
{
    NSString *str = [node stringValue];
    // std::string str([[node stringValue] cStringUsingEncoding:NSUTF8StringEncoding]);
    if ([str isEqualToString:@""])
    {
        [NSException raise:NSInternalInconsistencyException format:@"Empty XML Node"];
    }

    NSString *s = nil;
    if ([str rangeOfString:@"0x" options:0].location != NSNotFound)
    {
        s = [NSString stringWithFormat: @"%@",[str substringToIndex:2]];
    }
    else
    {
        s = [NSString stringWithFormat: @"%@",str];
    }

    uint64_t result;
    result = [s doubleValue];
    if (!s)
    {
        // throw std::runtime_error("Invalid value");
        NSString *msg = [NSString stringWithFormat: @"Invalid value, setting to limit %llu",limit];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DFUOutputNotification" object:msg userInfo:nil];
        result = limit;
    }

    if (result > limit)
    {
        // std::stringstream msg;
        // msg << "Invalid value";
        // throw std::runtime_error(msg.str());
        // dfu_print("%s\n",msg);
        NSString *msg = [NSString stringWithFormat: @"Invalid value, setting to limit %llu",limit];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DFUOutputNotification" object:msg userInfo:nil];
        result = limit;
    }
    return result;
}

+ (S2S_TargetCfg) parseTarget: (NSXMLElement*) node
{
    int i;
    {
        NSString *s = [[node attributeForName:@"id"] stringValue];
        i = [s intValue];
        if (!s)
        {
            [NSException raise: NSInternalInconsistencyException format: @"Could not parse SCSITarget id attr"];
        }
    }
    S2S_TargetCfg result = [ConfigUtil defaultTargetConfig: (i & 0x7)];

    NSArray *children = [node children];
    NSEnumerator *en = [children objectEnumerator];
    NSXMLNode *child = [en nextObject];
    while (child)
    {
        #pragma GCC diagnostic push
        #pragma GCC diagnostic ignored "-Wconversion"
        if ([[child name] isEqualToString: @"enabled"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.scsiId |= S2S_CFG_TARGET_ENABLED;
            }
            else
            {
                result.scsiId = result.scsiId & ~S2S_CFG_TARGET_ENABLED;
            }
        }
        else if ([[child name] isEqualToString: @"quirks"])
        {
            NSString *s = [child stringValue];
            NSString *quirk = nil;
            NSArray *quirks = [s componentsSeparatedByString:@"\n"];
            NSEnumerator *en = [quirks objectEnumerator];
            
            while ((quirk = [en nextObject]) != nil)
            {
                if ([quirk isEqualToString: @"apple"])
                {
                    result.quirks |= S2S_CFG_QUIRKS_APPLE;
                }
                else if ([quirk isEqualToString: @"omti"])
                {
                    result.quirks |= S2S_CFG_QUIRKS_OMTI;
                }
                else if ([quirk isEqualToString: @"xebec"])
                {
                    result.quirks |= S2S_CFG_QUIRKS_XEBEC;
                }
                else if ([quirk isEqualToString: @"vms"])
                {
                    result.quirks |= S2S_CFG_QUIRKS_VMS;
                }
            }
        }
        else if ([[child name] isEqualToString: @"deviceType"])
        {
            result.deviceType = [self parseInt:child limit:0xFF];
        }
        else if ([[child name] isEqualToString: @"deviceTypeModifier"])
        {
            result.deviceTypeModifier = [self parseInt:child limit:0xFF];
        }
        else if ([[child name] isEqualToString: @"sdSectorStart"])
        {
            result.sdSectorStart = [self parseInt:child limit:0xFFFFFFFF];
        }
        else if ([[child name] isEqualToString: @"scsiSectors"])
        {
            result.scsiSectors = [self parseInt:child limit:0xFFFFFFFF];
        }
        else if ([[child name] isEqualToString: @"bytesPerSector"])
        {
            result.bytesPerSector = [self parseInt:child limit:8192];
        }
        else if ([[child name] isEqualToString: @"sectorsPerTrack"])
        {
            result.sectorsPerTrack = [self parseInt:child limit:0xFF];
        }
        else if ([[child name] isEqualToString: @"headsPerCylinder"])
        {
            result.headsPerCylinder = [self parseInt:child limit:0xFF];
        }
        else if ([[child name] isEqualToString: @"vendor"])
        {
            @try {
                NSString *s = [child stringValue];
                s = [s substringToIndex:sizeof(result.vendor)];
                memset(result.vendor, ' ', sizeof(result.vendor));
                memcpy(result.vendor, [s cStringUsingEncoding:NSUTF8StringEncoding], [s length]);
            } @catch (NSException *exception) {
                NSLog(@"%@", [exception reason]);
            } @finally {
                // Code that gets executed whether or not an Exception is thrown....
            }
        }
        else if ([[child name] isEqualToString: @"prodId"])
        {
            @try {
                NSString *s = [child stringValue];
                s = [s substringToIndex:sizeof(result.prodId)];
                memset(result.prodId, ' ', sizeof(result.prodId));
                memcpy(result.prodId, [s cStringUsingEncoding:NSUTF8StringEncoding], [s length]);
            } @catch (NSException *exception) {
                NSLog(@"%@", [exception reason]);
            } @finally {
                // Code that gets executed whether or not an Exception is thrown....
            }
        }
        else if ([[child name] isEqualToString: @"revision"])
        {
            @try {
                NSString *s = [child stringValue];
                s = [s substringToIndex:sizeof(result.revision)];
                memset(result.revision, ' ', sizeof(result.revision));
                memcpy(result.revision, [s cStringUsingEncoding:NSUTF8StringEncoding], [s length]);
            } @catch (NSException *exception) {
               NSLog(@"%@", [exception reason]);
            } @finally {
               // Code that gets executed whether or not an Exception is thrown....
            }
        }
        else if ([[child name] isEqualToString: @"serial"])
        {
            @try {
                NSString *s = [child stringValue];
                s = [s substringToIndex:sizeof(result.serial)];
                memset(result.serial, ' ', sizeof(result.serial));
                memcpy(result.serial, [s cStringUsingEncoding:NSUTF8StringEncoding], [s length]);
            } @catch (NSException *exception) {
               NSLog(@"%@", [exception reason]);
            } @finally {
               // Code that gets executed whether or not an Exception is thrown....
            }
        }

        child = [en nextObject];
        #pragma GCC diagnostic pop
    }
    return result;
}

+ (S2S_BoardCfg) parseBoardConfig: (NSXMLElement*) node
{
    S2S_BoardCfg result = [ConfigUtil defaultBoardConfig];

    NSArray *children = [node children];
    NSEnumerator *en = [children objectEnumerator];
    NSXMLNode *child = [en nextObject];
    while (child)
    {
        if ([[child name] isEqualToString: @"selectionDelay"])
        {
            result.selectionDelay = [self parseInt: child limit: 255];
        }
        else if ([[child name] isEqualToString: @"startupDelay"])
        {
            result.startupDelay = [self parseInt: child limit: 255];
        }
        else if ([[child name] isEqualToString: @"unitAttention"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.flags |= S2S_CFG_ENABLE_UNIT_ATTENTION;
            }
            else
            {
                result.flags = result.flags & ~S2S_CFG_ENABLE_UNIT_ATTENTION;
            }
        }
        else if ([[child name] isEqualToString: @"parity"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.flags |= S2S_CFG_ENABLE_PARITY;
            }
            else
            {
                result.flags = result.flags & ~S2S_CFG_ENABLE_PARITY;
            }
        }
        else if ([[child name] isEqualToString: @"enableScsi2"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.flags |= S2S_CFG_ENABLE_SCSI2;
            }
            else
            {
                result.flags = result.flags & ~S2S_CFG_ENABLE_SCSI2;
            }
        }
        else if ([[child name] isEqualToString: @"enableTerminator"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.flags6 |= S2S_CFG_ENABLE_TERMINATOR;
            }
            else
            {
                result.flags6 = result.flags & ~S2S_CFG_ENABLE_TERMINATOR;
            }
        }
        else if ([[child name] isEqualToString: @"selLatch"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.flags |= S2S_CFG_ENABLE_SEL_LATCH;
            }
            else
            {
                result.flags = result.flags & ~S2S_CFG_ENABLE_SEL_LATCH;
            }
        }
        else if ([[child name] isEqualToString: @"mapLunsToIds"])
        {
            NSString *s = [child stringValue];
            if ([s isEqualToString: @"true"])
            {
                result.flags |= S2S_CFG_MAP_LUNS_TO_IDS;
            }
            else
            {
                result.flags = result.flags & ~S2S_CFG_MAP_LUNS_TO_IDS;
            }
        }
        else if ([[child name] isEqualToString: @"scsiSpeed"])
        {
            result.scsiSpeed = [self parseInt:child limit:S2S_CFG_SPEED_SYNC_10]; //parseInt(child, S2S_CFG_SPEED_SYNC_10);
        }
        child = [en nextObject];
    }
    return result;
}

// + (void *) /* static std::pair<S2S_BoardCfg, std::vector<S2S_TargetCfg>> */ fromXML: (NSString *) filename;
+ (Pair *) fromXML: (NSString *)filename
{
    NSData *data = [NSData dataWithContentsOfFile: filename];
    if(data == nil)
    {
        puts("Could not read file.");
        NSRunAlertPanel(@"Error Reading File",[NSString stringWithFormat:@"Cannot read file %@", filename], @"OK", nil, nil);
        return nil;
    }
    
    NSError *error = nil;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData: data
                                                     options: NSXMLNodeOptionsNone
                                                       error: &error];
    if (error != nil)
    {
        NSLog(@"%@", error);
    }
    
    Pair *p = [[Pair alloc] init];
    if (doc == nil)
    {
        [NSException raise: NSInternalInconsistencyException format: @"Could not load XML file"];
    }

    // start processing the XML file
    if ([[[doc rootElement] name] isEqualToString: @"SCSI2SD"] == NO)
    {
        [NSException raise: NSInternalInconsistencyException format: @"Invalid root node, expected <SCSI2SD>"];
    }

    S2S_BoardCfg boardConfig = [self defaultBoardConfig];
    int boardConfigFound = 0;

    NSArray *children = [[doc rootElement] children]; // doc.GetRoot()->GetChildren();
    NSEnumerator *en = [children objectEnumerator];
    NSXMLElement *child = [en nextObject];
    
    while (child)
    {
        if ([[child name] isEqualToString: @"SCSITarget"])
        {
            S2S_TargetCfg t = [self parseTarget: child];
            [p addTargetConfig: t];
        }
        else if ([[child name] isEqualToString: @"S2S_BoardCfg"])
        {
            boardConfig = [self parseBoardConfig: child];
            [p setBoardConfig: boardConfig];
            boardConfigFound = 1;
        }
        child = [en nextObject];
    }

    if (!boardConfigFound && [p targetCount] > 0)
    {
        S2S_TargetCfg target = [p targetCfgAtIndex: 0];
        boardConfig.flags = target.flagsDEPRECATED;
    }
    
    return p;
}

@end
