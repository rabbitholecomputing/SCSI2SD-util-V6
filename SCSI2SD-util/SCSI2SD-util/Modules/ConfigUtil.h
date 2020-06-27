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
#ifndef ConfigUtil_hh
#define ConfigUtil_hh

#import <Foundation/Foundation.h>
#include "scsi2sd.h"

@interface Pair : NSObject
{
    NSMutableArray *_targets;
    S2S_BoardCfg _boardCfg;
}
- (instancetype) initWithBoardCfg: (S2S_BoardCfg)boardCfg
                     targetConfig: (S2S_TargetCfg *)targetCfgs
                            count: (NSUInteger)c;
- (S2S_BoardCfg) boardCfg;
- (S2S_TargetCfg) targetCfgAtIndex: (NSUInteger)indx;

- (void) setBoardConfig: (S2S_BoardCfg)boardCfg;
- (void) addTargetConfig: (S2S_TargetCfg)targetCfg;
- (NSUInteger) targetCount;

@end

@interface ConfigUtil : NSObject

+ (S2S_BoardCfg) defaultBoardConfig;
+ (S2S_TargetCfg) defaultTargetConfig: (size_t) targetIdx;

+ (S2S_TargetCfg) targetCfgFromBytes: (NSData *) data;
+ (NSData *) targetCfgToBytes: (const S2S_TargetCfg) config;

+ (S2S_BoardCfg) boardConfigFromBytes: (NSData *) data;
+ (NSData *) boardConfigToBytes: (const S2S_BoardCfg) config;

+ (NSString *) targetCfgToXML: (const S2S_TargetCfg) config;
+ (NSString *) boardCfgToXML: (const S2S_BoardCfg) config;

+ (uint64_t) parseInt: (NSXMLNode *)node limit: (uint64_t) limit;
+ (S2S_TargetCfg) parseTarget: (NSXMLElement*) node;

+ (Pair *) fromXML: (NSString *)filename;

@end

#endif

