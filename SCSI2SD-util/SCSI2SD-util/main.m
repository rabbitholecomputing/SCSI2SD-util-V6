//
//  main.m
//  SCSI2SD-util
//
//  Created by Gregory Casamento on 12/3/19.
//  Copyright © 2019 RabbitHole Computing, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
#ifndef __MINGW32__
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }
#else
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSUserDefaults standardUserDefaults] setObject: @"WinUXTheme"
					      forKey: @"GSTheme"]; 
    RELEASE(pool);
#endif
    return NSApplicationMain(argc, argv);
}
