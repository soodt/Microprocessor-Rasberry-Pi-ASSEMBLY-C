#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h" // Required for using single-precision variables.
#include "pico/double.h" // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.
/**
 * @brief Fixed constant value of PI
 * 
 */
#define PI 3.14159265359
#define XIP_CTRL_BASE 0x14000000 
/**
* @brief This function acts as the main entry-point for core #1.
* A function pointer is passed in via the FIFO with one
* incoming int32_t used as a parameter. The function will
* provide an int32_t return value by pushing it back on
* the FIFO, which also indicates that the result is ready.
*/
void core1_entry() {
 while (1) {
 //
 int32_t (*func)() = (int32_t(*)()) multicore_fifo_pop_blocking();
 int32_t p = multicore_fifo_pop_blocking();
 int32_t result = (*func)(p);
 multicore_fifo_push_blocking(result);
 }
}
/**
 * @brief calculates the float value of PI using wallis product
 * 
 * @return float 
 */

float Pi_float(int iterations){
    float result =1;
    for (float i = 1; i <= iterations ; i++)
    {   
       float temp = ((i*2.0)/((i*2.0)-1)) * ((i*2.0)/ ((i*2.0)+1))  ;
       result *= temp;
    }
    result *= 2;
    return result;
}

/**
 * @brief calculates the double value of PI using wallis product.
 * 
 * @return double 
 */

double Pi_double(int iterations){
    double result =1;
    for (double i = 1; i <= iterations ; i++)
    {   
       double temp = ((i*2.0)/((i*2.0)-1)) * ((i*2.0)/ ((i*2.0)+1))  ;
       result *= temp;
    }
    result *= 2;
    return result;
}
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



/**
 * @brief works as the entry point for the program. Uses various functions and pico sdk timer to compare run time of the above 
 *        functions while using single and multiple cores to execute the same.
 * @return 0 to display everything is working properly
 */
int main() {

    const int ITER_MAX = 100000;
    stdio_init_all();
    multicore_launch_core1(core1_entry);
    // using while loop to to run the program twice with cache enable and disabled
    int i = 0;
    while (i<2){
        bool cache_staus = get_xip_cache_en();
        if (cache_staus && i ==1){
            // Disabling cache  
          set_xip_cache_en(false);
          cache_staus = get_xip_cache_en();
          printf("cache status set to %d\n",cache_staus);
        }
    // Code for sequential run goes here…
        // Take snapshot of timer and store for the single-precision Wallis approximation
        if (cache_staus)
            printf("WITH CACHE ENABLED: \n");
        else 
            printf("WITH CACHE DISABLED: \n");
        
        absolute_time_t sStartTimeSP = get_absolute_time();

        // Run the single-precision Wallis approximation
        Pi_float(ITER_MAX);

        // Take snapshot of timer and store for the single-precision Wallis approximation
        absolute_time_t sEndTimeSP = get_absolute_time();

        // Display time taken for the single-precision approximation function to run and print
        int sTimeTakenSP =  absolute_time_diff_us (sStartTimeSP, sEndTimeSP);
        printf("The Time taken to run and print the single-precision approximation function on single core is  %dms\n:",sTimeTakenSP);

        // Take snapshot of timer and store for the double-precision Wallis approximation
        absolute_time_t sStartTimeDP = get_absolute_time();

        // Run the double-precision Wallis approximation
        Pi_double(ITER_MAX); 

        // Take snapshot of timer and store for the double-precision Wallis approximation
        absolute_time_t sEndTimeDP = get_absolute_time();   

        // Display time taken for the double-precision approximation function to run and print
        int sTimeTakenDP =  absolute_time_diff_us (sStartTimeDP, sEndTimeDP);
        printf("The Time taken to run  and print the double-precision approximation function on single core is %dms\n:",sTimeTakenDP);

        //print the total runtime for the application when running on a single CPU core
        int sTimeTakenTotal =  absolute_time_diff_us (sStartTimeSP, sEndTimeDP);
        if (cache_staus){
            printf("Hence the total runtime for the application when running on a single CPU core with cache enabled is %dms\n:",sTimeTakenTotal);
        }
        else {
            printf("Hence the total runtime for the application when running on a single CPU core with cache disabled is %dms\n:",sTimeTakenTotal);
        }


    // Code for parallel run goes here…

        // Take snapshot of timer and store for the total multi core runtime
        absolute_time_t mStartTimeParallel = get_absolute_time();

        // Take snapshot of timer and store for the single-precision Wallis approximation
        absolute_time_t mStartTimeSP = get_absolute_time();
        
        // Run the single-precision Wallis approximation on one core
        multicore_fifo_push_blocking((uintptr_t) &Pi_float);
        multicore_fifo_push_blocking(ITER_MAX);

        // Take snapshot of timer and store for the double-precision Wallis approximation
        absolute_time_t mStartTimeDP = get_absolute_time();

        // Run the double-precision Wallis approximation on the other core
        Pi_double(ITER_MAX);

        // Take snapshot of timer and store
        absolute_time_t mEndTimeDP = get_absolute_time();

        // Get the single-precision Wallis approximation
        multicore_fifo_pop_blocking();

        // Take snapshot of timer and store for the single-precision Wallis approximation
        absolute_time_t mEndTimeSP = get_absolute_time();

        // Take snapshot of timer and store for the total multi core runtime
        absolute_time_t mEndTimeParallel = get_absolute_time();

        // Display time taken for the double-precision approximation function to run and print
        int mTimeTakenDP =  absolute_time_diff_us (mStartTimeDP, mEndTimeDP);
        printf("The Time taken to run  and print the double-precision approximation function on multi core is %dms\n:",mTimeTakenDP);

        // Display time taken for the single-precision approximation function to run and print
        int mTimeTakenSP =  absolute_time_diff_us (mStartTimeSP, mEndTimeSP);
        printf("The Time taken to run and print the single-precision approximation function on multi core is %dms\n:",mTimeTakenSP);

        // Display time taken for application to run in parallel mode
        int mTimeTakenTotal  = absolute_time_diff_us (mStartTimeParallel, mEndTimeParallel);
        
        if (cache_staus){
            printf("Hence the total runtime for the application when running on parallel CPU cores with cache enabled is %dms\n:",mTimeTakenTotal);
        }
        else {
            printf("Hence the total runtime for the application when running on parallel CPU cores with cache disabled is %dms\n:",mTimeTakenTotal);
        }
        printf("\n");
        i++;
    }
    // Returning zero indicates everything went okay.
    return 0;
}