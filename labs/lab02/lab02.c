//#define WOKWI  
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
//#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.

/**
 * @brief Fixed constant value of PI
 * 
 */
#define PI 3.14159265359

/**
 * @brief LAB #02 - TEMPLATE
 *        Main entry point for the code.
 * 
 * @return int      Returns exit-status zero on completion.
 */

/**
 * @brief calculates the float value of PI using wallis product
 * 
 * @return float 
 */

float Pi_float(){
    float result =1;
    for (float i = 1; i <= 100000 ; i++)
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

double Pi_double(){
    double result =1;
    for (double i = 1; i <= 100000 ; i++)
    {   
       double temp = ((i*2.0)/((i*2.0)-1)) * ((i*2.0)/ ((i*2.0)+1))  ;
       result *= temp;
    }
    result *= 2;
    return result;
}

/**
 * @brief executing the functions to calculate the value of PI using floats and double and calculating the error in the PI calculated.
 * 
 * @return int 
 */
int main() {


#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi  
#endif

    // Print a console message to inform user what's going on.
    printf("calculated value for PI (using single-precision): %.11f\n",Pi_float());
    printf("approximation error for the single-precision:  %.11f\n",PI-Pi_float());
    printf("calculated value for PI (using double-precision): %.11f\n",Pi_double());
    printf("approximation error for the single-precision:  %.11f\n",PI-Pi_double());

    // Returning zero indicates everything went okay.
    return 0;
}

