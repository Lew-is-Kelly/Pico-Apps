// #define WOKWI // Uncomment if running on Wokwi RP2040 emulator.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"  // Required for using single-precision variables.
#include "pico/double.h" // Required for using double-precision variables.

/**
 * @brief EXAMPLE - HELLO_C
 *        Simple example to initialise the IOs and then
 *        print a "Hello World!" message to the console.
 *
 * @return int  Application return code (zero for success).
 */
float calc_pi_float(int precision);

double calc_pi_double(int precision);

int main()
{

#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif

    float float_actual_pi = 3.14159265359;

    float float_pi = calc_pi_float(10000);

    float float_error = float_actual_pi - float_pi;

    printf("Error to actual Pi for float: %.9g\n", float_error);

    double double_pi = calc_pi_double(10000);

    double double_actual_pi = 3.14159265359;

    double double_error = double_actual_pi - double_pi;

    printf("Error to actual Pi for double: %.17g\n", double_error);

    // Returning zero indicates everything went okay.
    return 0;
}

float calc_pi_float(int precision)
{
    float pi = 1.0;

    for (int i = 1; i < precision; i++)
    {
        float tmp = 4.0 * i * i;
        pi *= tmp / (tmp - 1);
    }

    pi *= 2;

    printf("Float Pi for precision %d: %.9g\n", precision, pi);

    return pi;
}

double calc_pi_double(int precision)
{
    double pi = 1.0;

    for (int i = 1; i < precision; i++)
    {
        double tmp = 4.0 * i * i;
        pi *= tmp / (tmp - 1);
    }

    pi *= 2;

    printf("Double Pi for precision %d: %.9g\n", precision, pi);

    return pi;
}