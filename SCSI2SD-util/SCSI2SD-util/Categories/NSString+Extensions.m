//
//  NSString+Extensions.m
//  SCSI2SD-util
//
//  Created by Gregory Casamento on 12/14/19.
//  Copyright © 2019 RabbitHole Computing, LLC. All rights reserved.
//

#import "NSString+Extensions.h"
#import <AppKit/AppKit.h>
#import <wchar.h>

@implementation NSString (Extensions)

+ (NSString *) stringWithCString: (char *)cstring length: (NSUInteger)length
{
    NSData *data = [NSData dataWithBytes:cstring length:length];
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return result;
}

+(NSString *)stringFromChar:(const char *)charText
{
    return [NSString stringWithUTF8String:charText];
}

+ (const char *)charFromString:(NSString *)string
{
    return [string cStringUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *)stringFromWchar:(const wchar_t *)charText
{
    //used ARC
    if (charText == NULL)
    {
        return nil;
    }
    return [[NSString alloc] initWithBytes:charText length:wcslen(charText)*sizeof(*charText) encoding:NSUTF32LittleEndianStringEncoding];
}

+ (const char /*wchar_t*/ *)wcharFromString:(NSString *)string
{
    return  [string cStringUsingEncoding:NSUTF8StringEncoding];
}

@end
