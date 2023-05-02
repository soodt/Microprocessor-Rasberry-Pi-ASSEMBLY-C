.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment


@ Entry point to the ASM portion of the program
main_asm:
    movs r0, #0
    ldr  r2, =variable  
loop:
    cmp r0, #100
    bge end
    adds r0, r0, #1
    b loop
end:
    str  r0, [r2]            
.data
variable: .word 
@ Set data alignment
.data
    .align 4
