//
//  main.m
//  scsi2sd-util-cli
//
//  Created by Gregory Casamento on 1/10/20.
//  Copyright © 2020 RabbitHole Computing, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCSI2SDTask.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSProcessInfo *info = [NSProcessInfo processInfo];
        SCSI2SDTask *task = [SCSI2SDTask task];
        NSMutableArray *arguments = [[NSMutableArray alloc] initWithArray:info.arguments];
        // NSMutableArray *arguments = [[NSMutableArray alloc] initWithObjects:
             // @"dfu-util", @"-r", @"-f", @"/Users/heron/Downloads/firmware.dfu", nil]; // test dfu
        // NSMutableArray *arguments = @[@"", @"-l", @"config.xml"]; // test loading
        // NSMutableArray *arguments = [[NSMutableArray alloc] initWithObjects: @"", @"-s", @"config.xml", nil]; // test saving
        BOOL parseSuccessful = NO;
        BOOL repeatMode = NO;

        puts("=== SCSI2SD-util-V6-cli utility v1.0 ===");

        // NSLog(@"count == %ld", [arguments count]);
        if([arguments count] == 4)
        {
            // NSLog(@"In here %@", arguments);
            NSUInteger indx = [arguments indexOfObject: @"-r"];
            if(indx != NSNotFound)
            {
                [arguments removeObjectAtIndex:indx];
                repeatMode = YES;
                task.repeatMode = YES;
            }
        }
        else
        {
            repeatMode = NO;
            task.repeatMode = NO;
        }
        
        if([arguments count] == 3) // arguments includes the command...
        {
            do
            {
                NSString *filename = [arguments objectAtIndex: 2];
                const char *f = (const char *)[filename cStringUsingEncoding:NSUTF8StringEncoding];
                if([[arguments objectAtIndex:1] isEqualToString:@"-s"])
                {
                    printf("Saving file to filesystem from device: %s\n", f);
                    parseSuccessful = YES;
                    [task saveFromDeviceToFilename:filename];
                }
                else if([[arguments objectAtIndex:1] isEqualToString:@"-l"])
                {
                    printf("Loading file from filesystem to device: %s\n", f);
                    parseSuccessful = YES;
                    [task saveToDeviceFromFilename:filename];

                }
                else if([[arguments objectAtIndex:1] isEqualToString:@"-f"])
                {
                    printf("Loading firmware from filesystem to device: %s\n", f);
                    parseSuccessful = YES;
                    [task upgradeFirmwareDeviceFromFilename:filename];
                }
                
                puts("\n=== Operation completed.");
                if(repeatMode == YES)
                {
                    puts("\n**** Sleep for 5 seconds to allow disconnect...");
                    [NSThread sleepForTimeInterval:5.0];
                    [task waitForHidConnection];
                }
            } while (repeatMode);
        }
        
        if(parseSuccessful == NO)
        {
            // insert code here...
            puts("Usage: ");
            puts("\t-s save_file.xml -- save file from scsi2sd device");
            puts("\t-l load_file.xml -- save file to scsi2sd device");
            puts("\t-f firmware-file.dfu -- update firmware from file");
            puts("\t-r repeat operation.  This will cause the tool to loop and search for a connection and repeat the operation.");
        }
    }
    return 0;
}
