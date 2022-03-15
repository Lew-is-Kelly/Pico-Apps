#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.

/**
 * @brief This function acts as the main entry-point for core #1.
 *        A function pointer is passed in via the FIFO with one
 *        incoming int32_t used as a parameter. The function will
 *        provide an int32_t return value by pushing it back on
 *        the FIFO, which also indicates that the result is ready.
 */
void core1_entry()
{
    while (1)
    {
        //
        int32_t (*func)() = (int32_t(*)())multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        int32_t result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

int32_t calc_pi_float(int32_t precision)
{
    // Start at 1.
    float pi = 1.0;

    // Loops until precision.
    for (int i = 1; i < precision; i++)
    {
        float tmp = 4.0 * i * i;
        pi *= tmp / (tmp - 1);
    }
    pi *= 2;

    // Prints result to console.
    printf("Float Pi for precision %d: %.9g\n", precision, pi);

    return pi;
}

int32_t calc_pi_double(int32_t precision)
{
    // Start at 1.
    double pi = 1.0;

    // Loops until precision.
    for (int i = 1; i < precision; i++)
    {
        double tmp = 4.0 * i * i;
        pi *= tmp / (tmp - 1);
    }

    pi *= 2;

    // Prints result to console.
    printf("Double Pi for precision %d: %.9g\n", precision, pi);

    return pi;
}

// Main code entry point for core0.
int main()
{

    const int ITER_MAX = 100000;

    float float_res;
    double double_res;

    stdio_init_all();
    multicore_launch_core1(core1_entry);

    printf("Running Sequential Tests:\n"); // Code for sequential run goes here…
    int32_t time_start = time_us_32();     //    Take snapshot of timer and store

    multicore_fifo_push_blocking((uintptr_t)&calc_pi_float); //    Run the single-precision Wallis approximation
    multicore_fifo_push_blocking(ITER_MAX);

    float_res = multicore_fifo_pop_blocking();

    multicore_fifo_push_blocking((uintptr_t)&calc_pi_double); //     Run the double-precision Wallis approximation
    multicore_fifo_push_blocking(ITER_MAX);

    double_res = multicore_fifo_pop_blocking();

    int32_t time_end = time_us_32();

    printf("Float Pi is: %.9g\n", float_res);
    printf("Double Pi is: %.9g\n", double_res);

    int32_t time = time_end - time_start;       //    Take snapshot of timer and store
    printf("Total Time Taken: %dms\n\n", time); //    Display time taken for application to run in sequential mode

    // Code for parallel run goes here…
    //    Take snapshot of timer and store
    //    Run the single-precision Wallis approximation on one core
    //    Run the double-precision Wallis approximation on the other core
    //    Take snapshot of timer and store
    //    Display time taken for application to run in parallel mode

    return 0;
}