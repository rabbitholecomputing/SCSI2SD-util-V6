//
//  clock_gettime.c
//  SCSI2SD-util-v6
//
//  Created by Gregory Casamento on 6/30/20.
//  Copyright © 2020 RabbitHole Computing, LLC. All rights reserved.
//

#include "clock_gettime.h"

#include <mach/mach_time.h>
#define ORWL_NANO (+1.0E-9)
#define ORWL_GIGA UINT64_C(1000000000)

static double orwl_timebase = 0.0;
static uint64_t orwl_timestart = 0;

int clk_gettime( long clock_id, struct timespec *tp )
{
    // be more careful in a multithreaded environement
    if (!orwl_timestart) {
        mach_timebase_info_data_t tb = { 0 };
        mach_timebase_info(&tb);
        orwl_timebase = tb.numer;
        orwl_timebase /= tb.denom;
        orwl_timestart = mach_absolute_time();
    }
    struct timespec t;
    double diff = (mach_absolute_time() - orwl_timestart) * orwl_timebase;
    t.tv_sec = diff * ORWL_NANO;
    t.tv_nsec = diff - (t.tv_sec * ORWL_GIGA);
    
    return (int)t.tv_nsec;
}
