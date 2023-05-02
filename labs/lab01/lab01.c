/**
 * @file lab01.c
 * @author Tanuj Sood (soodt@tcd.ie)
 * @brief 
 * @version 0.1
 * @date 2023-02-12
 * 
 * @copyright Copyright (c) 2023
 * 
 */

#include "pico/stdlib.h"

/**
 * @brief EXAMPLE - BLINK_C
 *        Simple example to initialise the built-in LED on
 *        the Raspberry Pi Pico and then flash it forever. 
 * 
 * @return int  Application return code (zero for success).
 */
 
 /**
  * @brief checks if the given LED pin is on or off and toggles its and executes a delay.
  * 
  * @param LED_PIN 
  * @param LED_DELAY 
  */
void blinkS( uint LED_PIN, uint LED_DELAY){

    // Check if  the LED PIN is on
        if (gpio_get(LED_PIN)){
        // if yes Toggle the LED off
        gpio_put(LED_PIN, 0);
        }
        else{
        // else Toggle the LED on
        gpio_put(LED_PIN, 1);
        }
        sleep_ms(LED_DELAY);

}
/**
 * @brief executing the function in main to toggle the light pin
 * 
 * @return int 
 */

int main() {

    // Specify the PIN number and sleep delay
    const uint LED_PIN   =  25;
    const uint LED_DELAY = 500;

    // Setup the LED pin as an output.
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // Do forever...
    while (true) {

        // calling the subroutine blinkS
        blinkS(LED_PIN,LED_DELAY);           
    }

    // Should never get here due to infinite while-loop.
    return 0;

}


