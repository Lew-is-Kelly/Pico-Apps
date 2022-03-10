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
//
// Main entry point into the ASM portion of the code
//
main_asm:
    bl    init_leds           // Same as previous labs
    bl    init_btns           // Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl    install_alrm_isr    // See below
    bl    install_gpio_isr    // See below
loop:
    bl    set_alarm           // Set a new alarm
    wfi                       // Wait here until any interrupt fires
    b     loop                // Always branch back to loop

//
// Enable alarm timer interrupts and set an alarm
//
set_alarm:
    // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    // Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    // Add the time delay you want to wait for to the current timer count
    // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    // Exit subroutine

//
// Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
//
install_alrm_isr:
    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    // Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    // Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    // Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    // Exit subroutine

//
// Service the pending interrupt from the ALARM0 TIMER
//
alrm_isr:
    // Perform required functionality (e.g. toggle the LED)
    // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    // Exit ISR

//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    // Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    // Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    // Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    // Exit subroutine

//
// Service the pending interrupt from the GPIO
//
gpio_isr:
    // Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    // Detect which button was pressed by comparing to GPIO_BTN_DN_MSK, GPIO_BTN_EN_MSK and GPIO_BTN_UP_MSK
    // Perform required functionality based on the button press event that was detected
    // Disable the pending interrupt from GPIO by writing the correct value to (IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    // Exit ISR

.align 4
msg:    .asciz "Hello World!\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME