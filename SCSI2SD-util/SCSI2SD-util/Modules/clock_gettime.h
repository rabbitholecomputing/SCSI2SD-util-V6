//
//  clock_gettime.h
//  SCSI2SD-util-v6
//
//  Created by Gregory Casamento on 6/30/20.
//  Copyright © 2020 RabbitHole Computing, LLC. All rights reserved.
//

#ifndef clock_gettime_h
#define clock_gettime_h

#include <stdio.h>

int clk_gettime( long clock_id, struct timespec *tp );

#endif /* clock_gettime_h */
