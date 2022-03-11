#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1                              @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0                              @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000                        @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000                     @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000                     @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000                     @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20                                @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21                                @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22                                @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25                                @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0                                @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1                                @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1                                @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0                                @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74                           @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40                           @ ALARM0 is int #0 (vector table entry 16)

.equ    IRQ0, 1                                         @ Alarm 0

@ Entry point to the ASM portion of the program
//
// Main entry point into the ASM portion of the code
//
main_asm:
    bl    init_leds                                     @ Same as previous labs
    bl    init_btns                                     @ Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl    install_alrm_isr                              @ See below
    bl    install_gpio_isr                              @ See below
loop:
    bl    set_alarm                                     @ Set a new alarm
    wfi                                                 @ Wait here until any interrupt fires
    b     loop                                          @ Always branch back to loop

//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    ldr     r0, =ltimer                                 @ Get the time duration address
    ldr     r0, [r0]                                    @ Get the time duration at address
    ldr     r2, timerbase                               @ Get the timerbase
    ldr     r1, =IRQ0                                   @ for alarm 0
    str     r1, [r2, #TIMER_INTE_OFFSET]                @ Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    ldr     r1, [r2, #TIMER_TIMELR_OFFSET]              @ Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    add     r1, r0                                      @ Add the time delay you want to wait for to the current timer count
    str     r1, [r2, #TIMER_ALARM0_OFFSET]              @ Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    bx      lr                                          @ Exit subroutine

//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                    @ Load r1 with the value at the adress of r2
    movs    r2, #ALRM_ISR_OFFSET                        @ Move the SVC entry into r2
    add     r2, r1                                      @ Add r1 to r2 and store the value in r2
    ldr     r0, =alrm_isr                               @ Load r0 with the adress of svc_isr
    str     r0, [r2]                                    @ Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    ldr     r0, =IRQ0                                   @ alarm 0 is IRQ0
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ clearint
    str     r0, [r1]                                    @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ setint
    str     r0, [r1]                                    @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    bx      lr                                          @ Exit subroutine

//
// Service the pending interrupt from the ALARM0 TIMER
//
.thumb_func                                             @ necessary for interrupt handlers
alrm_isr:
    push    {lr}                                        @ Push the return address from the link register into the stack
    ldr     r0, =lstate                                 @ Get the address of whether the light is blinking or not blinking
    ldr     r0, [r0]                                    @ Get whether the light is blinking or not blinking
    cmp     r0, #DFLT_STATE_STOP                        @ Compare the current state to the not blinking state
    beq     do_nothing                                  @ If the current state is the not blinking state, branch to the do_nothing label
    movs    r0, #GPIO_LED_PIN                           @ Put the pin number in r0
    bl      asm_gpio_get                                @ Return the state of the light
    cmp     r0, #LED_VAL_OFF                            @ Compare to the off state of the light
    beq     toggle_on                                   @ If the light is off, branch to the toggle_on label
    movs    r1, #LED_VAL_OFF                            @ Otherwise, put the off state of the light in r1
    b       set                                         @ Branch to the set label
toggle_on:                                              @ toggle_on label
    movs    r1, #LED_VAL_ON                             @ Put the on state of the light in r1
set:                                                    @ set label
    movs    r0, #GPIO_LED_PIN                           @ Put the pin number of the light into r0
    bl      asm_gpio_put                                @ Perform required functionality (e.g. toggle the LED)light
do_nothing:                                             @ do_nothing label
    bl      set_alarm                                   @ Set the alarm
    ldr     r2, timerbase                               @ Get timerbase
    movs    r1, IRQ0                                    @ Put #1 into r1
    str     r1, [r2, #TIMER_INTR_OFFSET]                @ Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    pop     {pc}                                        @ Exit ISR

//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                    @ Get the value at the address in r2 into r1
    movs    r2, #GPIO_ISR_OFFSET                        @ Put the GPIO_ISR_OFFSET into r2
    add     r2, r1                                      @ Add r2 and r1
    ldr     r0, =gpio_isr                               @ Get the gpio_isr into r0
    str     r0, [r2]                                    @ Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    ldr     r0, =IRQ0                                   @ Get #1 into r0
    lsls    r0, #13                                     @ Logic shift left #1 13 times (1 * 2^13)
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Get the address of PPB_BASE offset by M0PLUS_MVIC_ICPR_OFFSET
    str     r0, [r1]                                    @ Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Get the address of PPB_BASE offset by M0PLUS_NVIC_ISER_OFFSET
    str     r0, [r1]                                    @ Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    bx      lr                                          @ Exit subroutine

//
// Service the pending interrupt from the GPIO
//
.thumb_func                                             @ necessary for interrupt handlers
gpio_isr:
    push    {lr}
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr     r0, [r2]                                    @ Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    ldr     r1, =GPIO_BTN_DN_MSK
    ands    r0, r1
    cmp     r0, r1                                      @ Detect which button was pressed by comparing to GPIO_BTN_DN_MSK, GPIO_BTN_EN_MSK and GPIO_BTN_UP_MSK
    beq     half
    ldr     r1, =GPIO_BTN_UP_MSK
    ldr     r0, [r2]
    ands    r0, r1
    cmp     r0, r1
    beq     double
    ldr     r1, =GPIO_BTN_EN_MSK
    ldr     r0, [r2]
    ands    r0, r1
    cmp     r0, r1
    beq     toggle
    b       dont_toggle

half:                                                       @ Perform required functionality based on the button press event that was detected
    ldr     r0, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr     r1, =GPIO_BTN_DN_MSK
    str     r1, [r0]                                        @ Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)

    ldr     r0, =lstate
    ldr     r0, [r0]
    cmp     r0, #DFLT_STATE_STOP                            @ If the LED is not flashing, reset the speed
    beq     reset

    ldr     r0, =ltimer
    ldr     r0, [r0]
    lsrs    r1, r0, #1                                      @ time / 2^1
    ldr     r0, =ltimer
    str     r1, [r0]

    ldr     r0, =ltimer
    ldr     r0, [r0]

    b       dont_toggle

    @ldr     r0, =halfmsg                                   @ Attempted message functionality. Broke the program because of printf.
    @bl      printf

double:
    ldr     r0, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr     r1, =GPIO_BTN_UP_MSK
    str     r1, [r0]                                        @ Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)

    ldr     r0, =lstate
    ldr     r0, [r0]
    cmp     r0, #DFLT_STATE_STOP
    beq     reset

    ldr     r0, =ltimer
    ldr     r0, [r0]
    lsls    r1, r0, #1                                      @ time * 2^1
    ldr     r0, =ltimer
    str     r1, [r0]
    b       dont_toggle

    @ldr     r0, =doublemsg
    @bl      printf

reset:
    ldr     r0, =ltimer
    ldr     r1, =1000000                                    @ reset to 1 second
    str     r1, [r0]
    b       dont_toggle

toggle:
    ldr     r0, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    ldr     r1, =GPIO_BTN_EN_MSK
    str     r1, [r0]                                        @ Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)

    ldr     r0, =lstate
    ldr     r0, [r0]
    cmp     r0, #DFLT_STATE_STRT                            @ If the light is flashing stop it, if it is not flashing start.
    beq     toggle_off
    ldr     r0, =DFLT_STATE_STRT
    b       flip
toggle_off:
    ldr     r0, =DFLT_STATE_STOP
flip:
    ldr     r1, =lstate
    str     r0, [r1]

dont_toggle:
    pop     {pc}                                            @ Exit ISR

init_leds:                                                  @ LED Initilisation
    push    {lr}
    movs    r0, #GPIO_LED_PIN
    bl      asm_gpio_init
    movs    r0, #GPIO_LED_PIN
    movs    r1, #GPIO_DIR_OUT
    bl      asm_gpio_set_dir
    pop     {pc}

init_btns:                                                  @ Button Initilisation
    push    {lr}
    ldr     r0, =GPIO_BTN_DN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_DN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_DN
    bl      asm_gpio_set_irq

    movs    r0, #GPIO_BTN_UP
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_UP
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_UP
    bl      asm_gpio_set_irq

    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN_EN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_EN
    bl      asm_gpio_set_irq
    pop     {pc}

.align 4
timerbase: .word TIMER_BASE
ppbbase: .word PPB_BASE
clearint: .word M0PLUS_NVIC_ICPR_OFFSET
setint: .word M0PLUS_NVIC_ISER_OFFSET
doublemsg: .asciz "Doubled Flash Rate."
halfmsg: .asciz "Halfed Flash Rate."
resetmsg: .asciz "Reset Flash Rate."
toggleonmsg: .asciz "Flashing!"
toggleoffmsg: .asciz "Not Flashing."
alarmmsg: .asciz "Alarm!"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME