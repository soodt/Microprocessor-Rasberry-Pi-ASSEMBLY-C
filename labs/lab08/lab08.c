#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#define XIP_CTRL_BASE 0x14000000
// Must declare the main assembly entry point before use.
void main_asm();

/**
 * @brief Function to get the enable status of the XIP cache
 * 
 * @return true if cache is enabled or false if diasbled
 */

bool get_xip_cache_en(){
    int* result =(int*) (XIP_CTRL_BASE);
    return result[0];
}
/**
 * @brief Function to set the enable status of the XIP cache
 * 
 * @param boolean cache_en 
 * @return true or false depending upon the status set
 */
bool set_xip_cache_en(bool cache_en){
    int* result =(int*) (XIP_CTRL_BASE);
    if (cache_en){
        result[0] = 1;
        return cache_en;
    }
    else {
        result[0] = 0;
        return cache_en;
    }
}

void flush(){
    int* result =(int*) (XIP_CTRL_BASE + 0x04);
    result[0] = 1;
}


/**
 * @brief LAB #08 - TEMPLATE
 *        Main entry point for the code - calls the main assembly
 *        function where the body of the code is implemented.
 * 
 * @return int      Returns exit-status zero on completion.
 */
int main() {

    // Running the ARM program with an initial cold cache
    set_xip_cache_en(false);
     absolute_time_t startTime = get_absolute_time();
     main_asm();
     absolute_time_t endTime = get_absolute_time();
     int timeTaken =  absolute_time_diff_us (startTime, endTime);
     printf("The Time taken to run the arm program with a cold cache  %dms\n:",timeTaken);

    // Jump into the main assembly code subroutine.

    // Returning zero indicates everything went okay.
    return 0;
}
