//
//  NSString+Extensions.h
//  SCSI2SD-util
//
//  Created by Gregory Casamento on 12/14/19.
//  Copyright © 2019 RabbitHole Computing, LLC. All rights reserved.
//

#import <AppKit/AppKit.h>


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Extensions)

+ (NSString *) stringWithCString: (char *)cstring length: (NSUInteger)length;
+ (NSString *)stringFromChar:(const char *)charText;
+ (const char *)charFromString:(NSString *)string;
+ (NSString *)stringFromWchar:(const wchar_t *)charText;
+ (const char /*wchar_t*/ *)wcharFromString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
