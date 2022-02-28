#include "hardware/regs/addressmap.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    SLEEP_TIME, 500         @ Specify the sleep time (in ms)
.equ    LED_GPIO_PIN, 25        @ Specify the pin that the LED is connected to
.equ    LED_GPIO_OUT, 1         @ Specify the direction of the GPIO pin
.equ    LED_VALUE_ON, 1         @ Specify the value that turns the LED "on"
.equ    LED_VALUE_OFF, 0        @ Specify the value that turns the LED "off"
.equ    SVC_ISR_OFFSET, 0x2C    @ The SVC is entry 11 in the vector table
.equ    SVC_MAX_INSTRS, 0x01    @ Maximum allowed SVC subroutines

@ Entry point to the ASM portion of the program
main_asm:
    bl      init_gpio_led       @ Initialise the GPIO LED pin
    bl      install_svc_isr     @ Install the SVC interrupt service routine
loop:
    svc     #0                  @ Call the SVC ISR with value 0 (turns on LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Short pause before proceeding
    svc     #1                  @ Call the SVC ISR with value 1 (turns off LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Add a short pause before proceeding
    b       loop                @ Always jump back to the start of the loop

@ Subroutine used to introduce a short delay in the application
do_sleep:
    push    {lr}                        @ Store the link register to the stack as we will call nested subroutines
    ldr     r0, =SLEEP_TIME             @ Set the value of SLEEP_TIME we want to wait for
    bl      sleep_ms                    @ Sleep until SLEEP_TIME has elapsed then toggle the LED GPIO pin
    pop     {pc}                        @ Pop the link register from the stack to the program counter

@ Subroutine used to initialise the PI Pico built-in LED
init_gpio_led:
    push    {lr}
    movs    r0, #LED_GPIO_PIN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #LED_GPIO_PIN           @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #LED_GPIO_OUT           @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}

@ Subroutine used to install the SVC interrupt service handler
install_svc_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Load r2 with the value of PPB_BASE + M0PLUS_VTOR_OFFSET
    ldr     r1, [r2]                                @ Load r1 with the value at the adress of r2
    movs    r2, #SVC_ISR_OFFSET                     @ Move the SVC entry into r2
    add     r2, r1                                  @ Add r1 to r2 and store the value in r2
    ldr     r0, =svc_isr                            @ Load r0 with the adress of svc_isr
    str     r0, [r2]                                @ Store the value at address r2 into r0
    bx      lr                                      @ Return from the function

@ SVC interrupt service handler routine
.thumb_func                     @ Required for all interrupt service routines
svc_isr:
    push    {lr}                @ Push the return address from the link register into the stack
    ldr     r0, [sp, #0x1C]     @ Load r0 with stack pointer offset by 28
    subs    r0, #0x2            @ Subtract 2 from r0 and store the result in r0
    ldr     r0, [r0]            @ Load r0  with the value at the address in r0
    ldr     r1, =#0xFF          @ Load r1 with the imediate value of 255
    ands    r0, r1              @ And the value in r0 with the value in r1 and store result in r0 then update flags.
    cmp     r0, #SVC_MAX_INSTRS @ Compare r0 to the maximum allowed subroutines
    bgt     svc_done            @ Branch to svc_done if there are more than the allowed SVC subroutines
    adr     r1, svc_jmptbl      @ Get the address for svc_jmptbl and store it in r1
    lsls    r0, #2              @ Shift r0 left by two bits and update flags.
    ldr     r1, [r1, r0]        @ Load r1 with the value at the address of r1, offset by r0
    mov     pc, r1              @ Move the value in r1 to the program counter
svc_done:
    pop     {pc}                @ Pop the link register from the stack to the program counter

@ First function of SVC subroutine - turn on the LED
svc_num0:
    movs    r0, #LED_GPIO_PIN   @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #LED_VALUE_ON   @ Move in the on value to r1
    bl      asm_gpio_put        @ Update the the value of the LED GPIO pin (based on value in r1)
    b       svc_done            @ Branch back to the main ISR when done

@ Second function of SVC subroutine - turn off the LED
svc_num1:
    movs    r0, #LED_GPIO_PIN   @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #LED_VALUE_OFF  @ Move in the off value to r0
    bl      asm_gpio_put        @ Update the the value of the LED GPIO pin (based on value in r1)
    b       svc_done            @ Branch back to the main ISR when done

@ SVC function entry jump table.
.align 2
svc_jmptbl:
    .word svc_num0              @ Entry zero goes to SVC function #0.
    .word svc_num1              @ Entry one goes to SVC function #1.
    .word 0                     @ Null termination of the jump table.

@ Set data alignment
.data
    .align 4