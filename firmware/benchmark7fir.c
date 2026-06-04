#include <stdint.h>

#define reg_leds (*(volatile uint8_t*)0x03000000)
#define reg_7seg (*(volatile uint8_t*)0x03000001)

//use any matrix hardware otherwise normal multiplication.
static inline int fast_mul(int a, int b) {
#ifdef USE_MACC
    int result;
    __asm__ volatile (
        "mv a0, %1\n"
        "mv a1, %2\n"
        ".word 0x00B5052B\n"
        "mv %0, a0\n"
        : "=r"(result) : "r"(a), "r"(b) : "a0", "a1"
    );
    return result;
#else
    return a * b;
#endif
}

#define TAPS    16
#define SAMPLES 64

//traingle wave data for FIR filter (taps)
static const int coeffs[TAPS] = {
    1, 2, 3, 4, 5, 6, 7, 8,
    8, 7, 6, 5, 4, 3, 2, 1
};
//data for FIR filter (inputs)
static const int signal[SAMPLES + TAPS] = {
    14, 21, 28, 35, 42, 49, 56, 63,
    70, 77, 84, 91, 98,  5, 12, 19,
    26, 33, 40, 47, 54, 61, 68, 75,
    82, 89, 96,  3, 10, 17, 24, 31,
    38, 45, 52, 59, 66, 73, 80, 87,
    94,  1,  8, 15, 22, 29, 36, 43,
    50, 57, 64, 71, 78, 85, 92, 99,
     6, 13, 20, 27, 34, 41, 48, 55,
    62, 69, 76, 83, 90, 97,  4, 11,
    18, 25, 32, 39, 46, 53, 60, 67,
};

unsigned char run_workload(void) {
    int out[SAMPLES];
    int i, k;

    for (i = 0; i < SAMPLES; i++) {
        int sum = 0;
        for (k = 0; k < TAPS; k++)
            sum += fast_mul(coeffs[k], signal[i + k]);
        out[i] = sum >> 7;
    }

    unsigned char res = 0;
    for (i = 0; i < SAMPLES; i++)
        res ^= (unsigned char)(out[i] & 0xFF);

    return res;  // expected: 0x05
}

void main(void) {
    unsigned char leds_value = 0x02;
    while (1) {
        reg_7seg = run_workload();
        reg_leds = leds_value;
        leds_value = leds_value ^ 0x02;
    }
}