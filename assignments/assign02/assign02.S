#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.global interruptHandler2
.global word_input
.global sleeper
.align 4                                                        @ Specify code alignment

.equ    DFLT_STATE_STRT, 1                                      @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0                                      @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1500000                               @ Specify the default alarm timeout
.equ    SLEEP_TIME, 5000

.equ    GPIO_BTN_RISE_MSK, 0x00400000                           @ Bit-22 for RISING-edge event on GP21
.equ    GPIO_BTN_FALL_MSK, 0x00800000                           @ Bit-23 for falling-edge event on GP21


.equ    DOT, 255                                                @ Input time for a dot is between 0 and 255 ms 
.equ    DASH, 1000                                                                @ Input time for a dash is 255 ms and greater
.equ    ENTER, 2000

.equ    GPIO_BTN,  21                                          @ Specify pin for the button
.equ    GPIO_LED_PIN, 25                                        @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0                                        @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1                                        @ Specify output direction for a GPIO pin


.equ    GPIO_ISR_OFFSET, 0x74                                   @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40                                   @ ALARM0 is int #0 (vector table entry 16)



@ Entry point to the ASM portion of the program

main_asm:
   // ldr r6, =0
    bl      init_btns                                           @ Use asm_gpio_set_irq C function to setup rising and falling-edge interrupts
    bl      install_gpio_isr                                    @ initialise buttons
    bl      install_alrm_isr    
    b      game

interruptHandler2:
    push    {lr}
    bl      level_input                              @ loop back up to start   \                               @ loop back up to start
    pop     {pc}




@ Get level input
level_input:
    push    {lr}                                                    @ Store the link register to the stack as we will call the init_btns subroutine
    movs    r4, #3                                              @ r4 shows whether a dot (0) or dash (1) has been pressed
    //bl      get_time_in_ms
    movs    r5, r0                                              @ Store the start time in r7
looop:
    bl      set_alarm
    wfi                                                         @ wait for alarm/gpio interrupt
    bl      user_input                                          @ insert the user input into the input array

    cmp     r4, #3                                              @ check if input sequence has been started, ie, the button was pressed
    bne     skip3                                               @ if not pressed, skip next instructions 

@   bl      get_time_in_ms
@   movs    r1, r5                                              @ Load the start time
@   bl      get_time_difference
@
@   movs    r5, #0  
@   ldr     r1, =ENTER
@   cmp     r0, r1
@   blt     looop
@   ldr     r0, =4                                              @ 4 = "enter"
@   bl      get_type                                         @ delete last space in input & set input to complete 
@   cmp     r0, #4
@   beq     skips
skip4:
    ldr    r0, =0
    bl      get_type    
skip3:
    movs    r4, #0                                              @ reset r4, which shows whether a dot (0) or dash (1) has been pressed

skips:
    pop     {pc}                                                @ Pop the link register from the stack to the program counter


user_input:          @ Store the link register to the stack as we will call the init_btns subroutine
    push    {lr}
    cmp     r4, #1                                              @ if gpio interrupt returns a 1
    beq     dot                                                 @ add dot to input
    cmp     r4, #2                                              @ if gpio interrupt returns a 2
    beq     dash                                                @ add dash to input
    cmp     r4, #4
    beq     enter
    b       input_entered                                       @ input entered
dot:
    ldr     r0, =1                                              @ 1 = "."
    bl      get_type                                         @ add dot to input sequence
    b       input_entered                                       @ input entered

dash:
    ldr     r0, =2                                              @ 2 = "-"
    bl      get_type                                         @ add dash to input sequence 
    b       input_entered                                       @ input entered

add_space:
    ldr     r0, =3                                              @ 3 = " "
    bl      get_type                                         @ add space to input sequence 
    b       input_entered                                       @ input entered 

enter:
    ldr     r0, =4                                              @ 4 = "enter"
    bl      get_type                                         @ delete last space in input & set input to complete 
   // movs    r6, #0                                              @ r6 shows whether there's a current question or not
input_entered:

    pop      {pc}                                               @ Pop the link register from the stack to the program counter






@LEVEL 3,4 IMPLEMENTATION STARTS HERE:
word_input:

    push    {lr}                                                    @ Store the link register to the stack as we will call the init_btns subroutine
    ldr  r5,=1
    ldr  r6, =0

repeat:

    movs    r4, #3                                              @ r4 shows whether a dot (0) or dash (1) has been pressed
    bl      set_alarm
    wfi                                                         @ wait for alarm/gpio interrupt
    bl      array_input                                          @ insert the user input into the input array
    cmp     r0, #4
    beq     exit2
    cmp     r4, #3                                              @ check if input sequence has been started, ie, the button was pressed
    beq     label1                                             @ if not pressed, skip next instructions 
    movs    r4, #0                                              @ reset r4, which shows whether a dot (0) or dash (1) has been pressed
label1:
    cmp  r6,#2
    bne  repeat
exit2:
    pop     {pc}                                                @ Pop the link register from the stack to the program counter



array_input:          @ Store the link register to the stack as we will call the init_btns subroutine
    push    {lr}
    cmp     r6, #1
    beq     add_space2
    cmp     r6, #10
    beq     enter2
    cmp     r4, #1                                              @ if gpio interrupt returns a 1
    beq     dot2                                                 @ add dot to input
    cmp     r4, #2                                              @ if gpio interrupt returns a 2
    beq     dash2                                                @ add dash to input
    b       input_entered2                                       @ input entered
dot2:
    ldr     r0, =1                                              @ 1 = "."
    ldr     r6, =0
    bl      make_sequence                                       @ add dot to input sequence
    b       input_entered2                                       @ input entered

dash2:
    ldr     r0, =2                                              @ 2 = "-"
    ldr     r6, =0
    bl      make_sequence       @ add dash to input sequence
    b       input_entered2                                       @ input entered

add_space2:
    cmp     r6, #9
    beq     enter2
    //ldr   r6,=0
    ldr     r0, =3                                              @ 3 = " "
    bl      make_sequence                                        @ add space to input sequence 
    ldr     r6, =9
    b       input_entered2                                       @ input entered 

enter2:
    ldr     r0, =4                                              @ 4 = "enter"
    bl      make_sequence                                         @ delete last space in input & set input to complete 
    //movs    r6, #0                                              @ r6 shows whether there's a current question or not
input_entered2:

    pop      {pc}                                               @ Pop the link register from the stack to the program counter








@ Subroutine used to setup falling-edge interrupts
init_btns:
    push    {lr}                                                @ Store the link register to the stack as we will call the init_btns subroutine   

    movs    r0, #GPIO_BTN                                       @ This value is the button pin on the PI PICO board
    bl      asm_gpio_init                                       @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #GPIO_BTN                                       @ This value is the "enter button" pin on the PI PICO board
    movs    r1, #GPIO_DIR_IN                                    @ We want this GPIO pin to be setup as an input pin
    bl      asm_gpio_set_dir                                    @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    movs    r0, #GPIO_BTN                                       @ This value is the button pin on the PI PICO board
    bl      asm_gpio_set_irq                                    @ Call this subroutine to enable rising and falling-edge interrupt on the pin specified by r0

    pop     {pc}                                                @ Pop the link register from the stack to the program counter


@ Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)                @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                            
    movs    r2, #GPIO_ISR_OFFSET                                @ Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    add     r2, r1
    ldr     r0, =gpio_isr                           
    str     r0, [r2]                                

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)           @ Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r1, =8192           
    str     r1, [r2]            

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)           @ Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r1, =8192           
    str     r1, [r2]

    bx      lr                                                  @ Exit subroutine

set_alarm:
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    movs    r1, #1
    str     r1, [r2]

    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET) @ Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r3, [r2]
    ldr     r1, =DFLT_ALARM_TIME
    add     r1, r3                                  @ Add the time delay you want to wait for to the current timer count
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET) @ Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    str     r1, [r2]
    bx      lr                                      @ Exit subroutine

install_alrm_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                
    movs    r2, #ALRM_ISR_OFFSET                    @ Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    add     r2, r1
    ldr     r0, =alrm_isr                           
    str     r0, [r2]                                

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    movs    r1, #1 
    str     r1, [r2]

    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    movs    r1, #1 
    str     r1, [r2]

    bx      lr                                        @ Exit subroutine

.thumb_func 
alrm_isr:
    push    {lr}                        @ Store the link register to the stack as we will call nested subroutines

    @ Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    ldr     r2, =(TIMER_BASE + TIMER_INTR_OFFSET)
    movs    r1, #1
    str     r1, [r2]
   
 

    @ Load the value 4 into register r4
    cmp     r4, #3
    bne     over
    cmp     r5,#1
    beq     out
    movs    r4, #4
    b       over
out: 
    ldr r1, =1
    add r6,r6,r1
over:
    pop     {pc}                        @ Pop the link register from the stack to the program counter
 

@ Service the pending interrupt from the GPIO
@ Returns the time difference between rising and falling edge in ms in r4
.thumb_func                                                     @ Required for all interrupt service routines
gpio_isr:
    push    {lr}                                                @ Store the link register to the stack as we will call the svc_isr routine

  //  ldr     r5, =0                                              @ Reset the interrupt count

    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)  @ Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr     r1, [r2]
    ldr     r0, =8192
    str     r0, [r2]

    ldr     r2, =GPIO_BTN_FALL_MSK
    CMP     r1, r2                                              @ Detect if it is a falling edge
    beq     falling_edge

    ldr     r2,=GPIO_BTN_RISE_MSK
    CMP     r1, r2                                              @ Detect if it is a rising edge
    beq     rising_edge
    b       end_input



rising_edge: 
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr     r1, =GPIO_BTN_RISE_MSK
    str     r1, [r2]

    bl      get_time_in_ms
    movs    r7, r0                                              @ Store the start time in r7

    b       end_input

falling_edge:
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr     r1, =GPIO_BTN_FALL_MSK
    str     r1, [r2]
    
    bl      get_time_in_ms
    movs    r1, r7                                              @ Load the start time
    bl      get_time_difference

    movs    r7, #0                                              @ Clear the time stored in r7
    cmp     r0, #DOT                                            @ If(time < 255ms
    blt     input_dot                                                 @   input = dot
    cmp     r0, #DOT
    bge     input_dash
    b       end_input                                           @   input = dash
input_dot:
    ldr     r4, =1                                           @ 1 = "."
    b       end_input

input_dash:
    ldr     r4, =2                                             @ 2 = "-"
    b       end_input

end_input:


    pop     {pc}                                                @ Exit ISR   

sleeper:
    push {lr}
    ldr r0,=1000
    bl   sleep_ms
    pop  {pc}
@ Set data alignment
.data

    .align 4