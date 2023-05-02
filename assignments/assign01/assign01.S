#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
        bl      init_gpio_led         @ Initialise the GPIO LED pin
        bl      init_gpio_button      @ Initialise the GPIO buttons pin
        bl      install_alarm_isr     @ Install the alarm interrupt service routine
        bl      install_gpio_isr      @ Install the GPIO interrupt service routine
        bl      set_alarm             @ Setting up alarm interrupt
main_loop:
        b       main_loop             @ infinite loop

@ Subroutine to Initialize the LED pin
init_gpio_led:
     push    {lr}                     @ pushing the link register to the stack
     movs    r0, #GPIO_LED_PIN        @ This value is the GPIO LED pin on the PI PICO board
     bl      asm_gpio_init            @ Call the subroutine to initialise the GPIO pin specified by r0
     movs    r0, #GPIO_LED_PIN        @ This value is the GPIO LED pin on the PI PICO board
     movs    r1, #GPIO_DIR_OUT        @ We want this GPIO pin to be setup as an output pin
     bl      asm_gpio_set_dir         @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
     pop     {pc}                     @ Pop the link register from the stack to the program counter
     
@ Subroutine to Initialize the GPIO buttons
init_gpio_button:
     push    {lr}                    @ pushing the link register to the stack
     movs    r0, #GPIO_BTN_EN        @ This value is the GPIO pin for the "enter" button on the PI PICO board
     bl      asm_gpio_init           @ Call the subroutine to initialise the GPIO pin specified by r0
     movs    r0, #GPIO_BTN_EN        @ This value is the GPIO pin for the "enter" button on the PI PICO board
     movs    r1, #GPIO_DIR_IN        @ We want this GPIO pin to be setup as an input pin
     bl      asm_gpio_set_dir        @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
     movs    r0, #GPIO_BTN_EN        @ This value is the GPIO pin for the "down" button on the PI PICO board    
     bl      asm_gpio_set_irq        @ Setting up the button to cause interrupts when pressed

     movs    r0, #GPIO_BTN_DN        @ This value is the GPIO pin for the "down" button on the PI PICO board
     bl      asm_gpio_init           @ Call the subroutine to initialise the GPIO pin specified by r0
     movs    r0, #GPIO_BTN_DN        @ This value is the GPIO pin for the "down" button on the PI PICO board
     movs    r1, #GPIO_DIR_IN        @ We want this GPIO pin to be setup as an input pin
     bl      asm_gpio_set_dir        @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
     movs    r0, #GPIO_BTN_DN        @ This value is the GPIO pin for the "down" button on the PI PICO board
     bl      asm_gpio_set_irq        @ Setting up the button to cause interrupts when pressed

     movs    r0, #GPIO_BTN_UP        @ This value is the GPIO pin for the "up" button on the PI PICO board
     bl      asm_gpio_init           @ Call the subroutine to initialise the GPIO pin specified by r0
     movs    r0, #GPIO_BTN_UP        @ This value is the GPIO pin for the "up" button on the PI PICO board
     movs    r1, #GPIO_DIR_IN        @ We want this GPIO pin to be setup as an input pin
     bl      asm_gpio_set_dir        @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
     movs    r0, #GPIO_BTN_UP        @ This value is the GPIO pin for the "up" button on the PI PICO board
     bl      asm_gpio_set_irq        @ Setting up the button to cause interrupts when pressed
     pop     {pc}                    @ Pop the link register from the stack to the program counter

@ Subroutine to set up new alarm interrupts
set_alarm:

    /*  To set an alarm we need to enable interrupts in the timer block and set the delay
     • Enable the interrupt by writing 0x1 to (TIMER_BASE + TIMER_INTE_OFFSET)
     • Set the desired delay value in (TIMER_BASE + TIMER_ALARM0_OFFSET)
    */
      
     push    {lr}                                     @ pushing the link register to the stack
     ldr r0, =lstate                                  @ Loading the address of lstate into r0
     ldr r1, [r0]                                     @ Loading the current state of toggle from the address into r1
     movs r0, #0                                      @ Storing value 0/'off' in r0
     cmp r1, r0                                       @ Checking if the LED is currently toggled off
     beq skip                                         @ skipping/not setting a new alarm if LED is toggled off
     ldr R2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)      @ Loading the address of TIMER_BASE + TIMER_TIMELR_OFFSET INTO R2
     LDR R1, [R2]                                     @ Loading the value in the address into R1
     ldr r0, =ltimer                                  @ Loading the address of ltimer into r0
     ldr r2, [r0]                                     @ Loading the value of how long the timer should be from the address into r2
     ADD R1, R1, R2                                   @ Adding the length of the next timer to R1
     ldr R2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)      @ Loading the address of TIMER_BASE + TIMER_ALARM0_OFFSET INTO R2
     STR R1, [R2]                                     @ Storing the value/length of the next timer into the address
     ldr     r0, =msg7
     bl      printf
     skip:                                                               
     ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)    @ Loading the address of TIMER_BASE + TIMER_INTE_OFFSET INTO R2
     MOVS R1, #1                                      @ Loading the value #1 into r1
     STR R1, [R2]                                     @ Enabling the interrupt by writing 0x1 to (TIMER_BASE + TIMER_INTE_OFFSET)
     pop     {pc}                                     @ Pop the link register from the stack to the program counter       
   
@Initializing the alarm interrupt service routine
install_alarm_isr:

/*
TIMER_IRQ_0 is IRQ #0, which is the 16th entry in the Cortex M0+ vector table so the
address of the interrupt service routine for the ALARM timer is written to
• PPB_BASE + M0PLUS_VTOR_OFFSET + (16 * 4)  each entry is 4*bytes
 */

     ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Loading the address of PPB_BASE + M0PLUS_VTOR_OFFSET INTO to reach the vector table R2
     ldr     r1, [r2]                                @ Loading the value in the address into r1
     movs    r2, #ALRM_ISR_OFFSET                    @ Loading the the value of ALRM_ISR_OFFSET into r2
     add     r2, r1                                  @ Adding the offset to address of the base of the vector table
     ldr     r0, =alarm_isr                          @ Loading the address of the subroutine alarm_isr into r0
     str     r0, [r2]                                @ storing the address of alarm_isr in the address in the vector table

/*
The IRQ0 now needs to be enabled so to do that we need to disable then enable the
correct interrupt (IRQ0)
• Disable the interrupt by writing 0x1 to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
• Enable the interrupt by writing 0x1 to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)

 */
    
     ldr     r2, =PPB_BASE                                @ Loading the base address of the RP2040 into to r2
     ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)    @ Adding the offset for  M0PLUS_NVIC_ICPR_OFFSET to PPB_bASE and storing it in r2 
     movs    r1, #0x1                                     @ Loading the value #1 into r1
     str     r1, [r2]                                     @ Disabling the interrupt by writing 0x1 to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)

     ldr     r2, =PPB_BASE                                @ Loading the base address of the RP2040 into to r2
     ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)    @ Adding the offset for M0PLUS_NVIC_ISER_OFFSET to PPB_bASE and storing it in r2                                     @ Loading the value in the address into r1  
     movs    r1, #0x1                                     @ Loading the value #1 into r1
     str     r1, [r2]                                     @ Enabling the interrupt by writing 0x1 to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
     bx      lr                                           @ Exit the subroutine


@ Subroutine to handle the alarm interrupt appropriately
.thumb_func 
alarm_isr:
     push    {lr}                                         @ pushing the link register to the stack
     ldr r0, =lstate                                  @ Loading the address of lstate into r0
     ldr r1, [r0]                                     @ Loading the current state of toggle from the address into r1
     movs r0, #0                                      @ Storing value 0/'off' in r0
     cmp r1, r0                                       @ Checking if the LED is currently toggled off
     beq skip2                                         @ skipping/not setting a new alarm if LED is toggled off
     ldr     r0, =msg8
     bl      printf
     movs    r0, #GPIO_LED_PIN                            @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
     bl      asm_gpio_get                                 @ Get current the value of the LED GPIO pin (returns to r0)
     cmp     r0, #LED_VAL_OFF                             @ Check if the LED GPIO pin value is "off"
     beq     led_set_on                                   @ If it is "off" then then jump code to to turn it on
led_set_off:
     movs    r1, #LED_VAL_OFF                             @ The LED is currently "on" so we want to turn it "off"
     b       led_set_state                                @ Jump to portion of code where we set the state of the LED
led_set_on:
     movs    r1, #LED_VAL_ON                              @ The LED is currently "off" so we want to turn it "on"
led_set_state:
     movs    r0, #GPIO_LED_PIN                            @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    
     bl      asm_gpio_put                                 @ Update the the value of the LED GPIO pin (based on value in r1)
     skip2:
     ldr     r1, =(TIMER_BASE + TIMER_INTR_OFFSET)        @ Loading the address of TIMER_BASE + TIMER_INTR_OFFSET INTO R2
     ldr     r2, =#0x1                                    @ Loading the value #1 into r2 
     str     r2, [r1]                                     @ Storing the value in the address to reset the timer
     bl      set_alarm                                    @ Setting up a new alarm
     pop     {pc}                                         @ Pop the link register from the stack to the program counter

@ Subroutine to initialize GPIO isr
install_gpio_isr:
    ldr      r0, =(PPB_BASE+M0PLUS_VTOR_OFFSET)          @ Loading the address of PPB_BASE + M0PLUS_VTOR_OFFSET INTO to reach the vector table R2
    ldr      r1, [r0]                                    @ Loading the value in the address into r1
    ldr      r0, =GPIO_ISR_OFFSET                        @ Loading the GPIO_ISR_OFFSET into r0
    adds     r0, r0, r1                                  @ Adding the offset to the address
    ldr      r1, =gpio_isr                               @ Loading the addrees of the gpio_isr subroutine into r1
    str      r1, [r0]                                    @ Storing the addrees of the gpio_isr subroutine in the the address in the vector table

    ldr     r2, =PPB_BASE                                @ Loading the base address of the RP2040 into to r2
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)    @ Adding the offset for the vector table to PPB_bASE and storing it in r2 
    ldr     r1, =0x2000                                  @ Loading the value 0x2000/2^13 into r1
    str     r1, [r2]                                     @ Storing the value into PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET address

    ldr     r2, =PPB_BASE                                @ Loading the base address of the RP2040 into to r2
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)    @ Adding the offset for the vector table to PPB_bASE and storing it in r2          
    ldr     r1, =0x2000                                  @ Loading the value 0x2000/2^13 into r1
    str     r1, [r2]                                     @ Storing the value into PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET address
    bx      lr                                           @ Exit the subroutine


@ Subroutine to handle the gpio/button interrupt appropriately
.thumb_func 
gpio_isr:
     push    {lr}                                                   @ pushing the link register to the stack
     ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)     @ Loading the the address of IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET to r2
     ldr     r1, [r2]                                               @ Loading the value in the address into r1
     ldr     r0, =0x2000                                            @ Loading the value 0x2000/2^13 into r0
     str     r0, [r2]                                               @ Storing the value into  address IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET to set the enable bit processor instruction of the vector table
     ldr     r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)     @ Loading the the address of IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET to r2
     ldr     r1, [r0]                                               @ Loading the value in the address into r1 to check the specific bit changed to see the button pressed
     ldr     r0, = GPIO_BTN_EN_MSK                                  @ Loading the mask for ENTER GPIO pin into r0
     cmp     r0, r1                                                 @ Comparing the mask with the status register to see if ENTER button is pressed
     beq     enter                                                  @ Go to subroutine to handle enter button
     ldr     r0, = GPIO_BTN_DN_MSK                                  @ Loading the mask for DOWN GPIO pin into r0
     cmp     r0, r1                                                 @ Comparing the mask with the status register to see if DOWN button is pressed
     beq     down                                                   @ Go to subroutine to handle DOWN button
     ldr     r0, = GPIO_BTN_UP_MSK                                  @ Loading the mask for UP GPIO pin into r0
     cmp     r0, r1                                                 @ Comparing the mask with the status register to see if UP button is pressed
     beq     UP                                                     @ Go to subroutine to handle UP button
     continue:
     pop     {pc}                                                   @ Pop the link register from the stack to the program counter


@ Subroutine to handle ENTER button
enter:
     ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Loading the the address of IO_BANK0_BASE + IO_BANK0_PROC0_INTR2_OFFSET to r2
     ldr     r1,=GPIO_BTN_EN_MSK                                    @ Loading the mask for ENTER GPIO pin into r1
     str     r1,[r2]                                                @ Storing the mask in the address to reset the interrupt
     ldr     r0, =lstate                                            @ Loading the address of lstate into r0
     ldr     r1, [r0]                                               @ Loading the current state of toggle from the address into r1
     movs    r2, #0                                                 @ Moving the value 0 into r2
     cmp     r1, r2                                                 @ Checking if the button is toggled off
     beq     setOn                                                  @ branch to subroutine to handle if it toggled off
     str     r2, [r0]                                               @ Storing 0 as lstate status to indicate LED being turned off
     bl      set_alarm                                              @ Set a new alarm
     ldr     r0, =msg2
     bl      printf
     b continue                                                     @ Exit
     setOn:                                                         @ Subroutine to handle turning on status
     movs    r2, #1                                                 @ Moving the value 1 to r2
     str     r2, [r0]                                               @ Storing 1 as lstate status to indicate LED being turned off
     bl      set_alarm                                              @ Set a new alarm
     ldr     r0, =msg9
     bl      printf
     b       continue                                               @ Exit

@Subroutine to handle the up button
UP:
     ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Loading the the address of IO_BANK0_BASE + IO_BANK0_PROC0_INTR2_OFFSET to r2
     ldr     r1,=GPIO_BTN_UP_MSK                                    @ Loading the mask for UP GPIO pin into r1
     str     r1,[r2]                                                @ Storing the mask in the address to reset the interrupt
     ldr     r0, =lstate                                            @ Loading the address of lstate into r0
     ldr     r1, [r0]                                               @ Loading the current state of toggle from the address into r1
     movs    r2, #0                                                 @ Moving the value 0 into r2
     cmp     r1, r2                                                 @ Checking if the button is toggled off
     beq     reset                                                  @ Branch to subroutine to handle reset
     ldr     r0, =msg3
     bl      printf
     ldr     r0, =ltimer                                            @ Load the address of ltimer
     ldr     r1, [r0]                                               @ Load the value of current timer length into r1
     lsrs    r1, #1                                                 @ Halving the value by shifting the value right by 1
     str     r1, [r0]                                               @ Storing the updated value back in the ltimer address
     bl      set_alarm                                              @ Set a new alarm
     b continue                                                     @ Exit

@Subroutine to handle the down button
down:
     ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Loading the the address of IO_BANK0_BASE + IO_BANK0_PROC0_INTR2_OFFSET to r2
     ldr     r1,=GPIO_BTN_DN_MSK                                    @ Loading the mask for DOWN GPIO pin into r1
     str     r1,[r2]                                                @ Storing the mask in the address to reset the interrupt
     ldr     r0, =lstate                                            @ Loading the address of lstate into r0
     ldr     r1, [r0]                                               @ Loading the current state of toggle from the address into r1
     movs    r2, #0                                                 @ Moving the value 0 into r2
     cmp     r1, r2                                                 @ Checking if the button is toggled off
     beq     reset                                                  @ Branch to subroutine to handle reset
     ldr     r0, =msg4
     bl      printf
     ldr     r0, =ltimer                                            @ Load the address of ltimer
     ldr     r1, [r0]                                               @ Load the value of current timer length into r1
     movs    r2, #2                                                 @ Moving the value 2 into r2
     MULS    r1, r2                                                 @ Doubling the timer length by multiplying by 2
     str     r1, [r0]                                               @ Storing the updated value back in the ltimer address
     bl      set_alarm                                              @ Set a new alarm
     b continue                                                     @ Exit

@    SUbroutine to handle UP or DOWN button pressed while LED is toggled off
     reset:
     ldr     r0, =msg5
     bl      printf
     ldr     r0, =ltimer                                            @ Load the address of ltimer
     ldr     r1, =DFLT_ALARM_TIME                                   @ Load the value of default alarm time into r1
     str     r1, [r0]                                               @ Storing the default value into ltimer 
     bl      set_alarm                                              @ Set a new alarm
     b continue                                                     @ Exit

.align 4
msg2:    .asciz "ENTER button pressed.\n Toggling Off.\n"
msg3:    .asciz "UP button pressed.\n Doubling the flash rate.\n"
msg4:    .asciz "Down button pressed.\n Halving the flash rate.\n"
msg5:    .asciz "UP/Down button pressed while toggled Off.\n Resetting timer to default value.\n"
msg7:    .asciz "Alarm Set.\n"
msg8:    .asciz "Alarm over.\n"
msg9:    .asciz "ENTER button pressed.\n Toggling On.\n"

.data
lstate: .word   DFLT_STATE_STRT              @ lstate keeps track of whether the blinking is toggled on or off
ltimer: .word   DFLT_ALARM_TIME              @ ltimer keeps track of the length of timer