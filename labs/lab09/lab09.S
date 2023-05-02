#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)
.equ    GPIO_LED_PIN, 25              @ pin for the built-in LED is set
.equ    GPIO_DIR_OUT,  1              @ output direction for a GPIO pinA
.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)


@ Entry point to the ASM portion of the program
main_asm:
    bl      install_alarm_isr     @ Install the alarm interrupt service routine
    bl      set_alarm             @ Setting up alarm interrupt
    movs    r0, #4                @ set the ADC input to 4 which corresponds to the 5th ADC channel to read temp
    bl      adc_initialization    @ initializing ADC by calling the adc_initialization function
loop:
    bl       set_alarm            @ Setting up alarm interrupt
    wfi                           @ wait for interrupt
    ldr     r1, =temp             @ loading the address of temp variable
    ldr     r0,  [r1]             @ loading the value in the address into r0
    bl      adc_To_Float          @ calling function adc_To_Float with parameter var temp to convert and print readings
    b       loop            @ Infinite loop

set_alarm:

    /*  To set an alarm we need to enable interrupts in the timer block and set the delay
     • Enable the interrupt by writing 0x1 to (TIMER_BASE + TIMER_INTE_OFFSET)
     • Set the desired delay value in (TIMER_BASE + TIMER_ALARM0_OFFSET)
    */
      
     ldr R2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)      @ Loading the address of TIMER_BASE + TIMER_TIMELR_OFFSET INTO R2
     LDR R1, [R2]                                     @ Loading the value in the address into R1
     LDR R2, =DFLT_ALARM_TIME        
     ADD R1, R1, R2                                   @ Adding the length of the next timer to R1
     ldr R2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)      @ Loading the address of TIMER_BASE + TIMER_ALARM0_OFFSET INTO R2
     STR R1, [R2]                                     @ Storing the value/length of the next timer into the address                                                
     ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)       @ Loading the address of TIMER_BASE + TIMER_INTE_OFFSET INTO R2
     MOVS R1, #1                                      @ Loading the value #1 into r1
     STR R1, [R2]                                     @ Enabling the interrupt by writing 0x1 to (TIMER_BASE + TIMER_INTE_OFFSET)   
     bx lr   

install_alarm_isr:

     ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Loading the address of PPB_BASE + M0PLUS_VTOR_OFFSET INTO to reach the vector table R2
     ldr     r1, [r2]                                @ Loading the value in the address into r1
     movs    r2, #ALRM_ISR_OFFSET                    @ Loading the the value of ALRM_ISR_OFFSET into r2
     add     r2, r1                                  @ Adding the offset to address of the base of the vector table
     ldr     r0, =alarm_isr                          @ Loading the address of the subroutine alarm_isr into r0
     str     r0, [r2]                                @ storing the address of alarm_isr in the address in the vector table

     ldr     r2, =PPB_BASE                                @ Loading the base address of the RP2040 into to r2
     ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)    @ Adding the offset for  M0PLUS_NVIC_ICPR_OFFSET to PPB_bASE and storing it in r2 
     movs    r1, #0x1                                     @ Loading the value #1 into r1
     str     r1, [r2]                                     @ Disabling the interrupt by writing 0x1 to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)

     ldr     r2, =PPB_BASE                                @ Loading the base address of the RP2040 into to r2
     ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)    @ Adding the offset for M0PLUS_NVIC_ISER_OFFSET to PPB_bASE and storing it in r2                                     @ Loading the value in the address into r1  
     movs    r1, #0x1                                     @ Loading the value #1 into r1
     str     r1, [r2]                                     @ Enabling the interrupt by writing 0x1 to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
     bx      lr                                           @ Exit the subroutine


.thumb_func 
alarm_isr:
     push    {lr}                                         @ pushing the link register to the stack
     ldr     r1, =temp                                    @ loading the address of temp variable
     bl      read_Temperature                             @ reading the raw value of ADC by calling the function read_Temperature
     str     r0, [r1]                                     @ storing the result in variable temp
     ldr     r1, =(TIMER_BASE + TIMER_INTR_OFFSET)        @ Loading the address of TIMER_BASE + TIMER_INTR_OFFSET INTO R2
     ldr     r2, =#0x1                                    @ Loading the value #1 into r2 
     str     r2, [r1]                                     @ Storing the value in the address to reset the timer
     pop     {pc}                                         @ Pop the link register from the stack to the program counter

@ Set data alignment
.data
    .align 4

.data
temp: .word                                              @ variable to store the reading.
