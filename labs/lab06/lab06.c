#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <inttypes.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.

#define __STDC_FORMAT_MACROS

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

float calc_pi_float(int precision)
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

double calc_pi_double(int precision)
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

    stdio_init_all();

    printf("----------------------------------------------------\n");

    printf("Running functions on core0 sequentially:\n"); //    Code for sequential run goes here…
    uint64_t time_start = time_us_64();                   //    Take snapshot of timer and store

    calc_pi_float(ITER_MAX); //    Run the single-precision Wallis approximation

    uint64_t time_mid = time_us_64();

    calc_pi_double(ITER_MAX); //    Run the double-precision Wallis approximation

    uint64_t time_end = time_us_64(); //    Take snapshot of timer and store

    printf("Time taken for single precision on core0: %" PRIu64 "us\n", (time_mid - time_start));
    printf("Time taken for double presicion on core0: %" PRIu64 "us\n", (time_end - time_mid));
    printf("Time taken for both sequentially on core0: %" PRIu64 "us\n", (time_end - time_start)); //    Display time taken for application to run in sequential mode

    printf("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");

    printf("Running In Parallel on Two Cores:\n"); //    Code for parallel run goes here…

    multicore_launch_core1(core1_entry);

    time_start = time_us_64(); //    Take snapshot of timer and store

    multicore_fifo_push_blocking((uintptr_t)&calc_pi_double); //    Run the single-precision Wallis approximation on one core
    multicore_fifo_push_blocking(ITER_MAX);

    calc_pi_float(ITER_MAX); //    Run the double-precision Wallis approximation on the other core

    multicore_fifo_pop_blocking();

    time_end = time_us_64(); //    Take snapshot of timer and store

    printf("Time taken for both cores in parallel: %" PRIu64 "us\n", (time_end - time_start)); //    Display time taken for application to run in parallel mode

    printf("----------------------------------------------------\n");
    return 0;
}