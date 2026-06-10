#include "firmware.h"

#define N 4

static inline int macc_mul(int a, int b) {
    int result;
    __asm__ volatile (
        "mv a0, %1\n"
        "mv a1, %2\n"
        ".word 0x00B5052B\n"
        "mv %0, a0\n"
        : "=r"(result) : "r"(a), "r"(b) : "a0", "a1"
    );
    return result;
}
static void matmul_sw(int A[N][N], int B[N][N], int C[N][N]) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            C[i][j] = 0;
            for (int k = 0; k < N; k++)
                C[i][j] += A[i][k] * B[k][j];
        }
}
static void matmul_hw(int A[N][N], int B[N][N], int C[N][N]) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            C[i][j] = 0;
            for (int k = 0; k < N; k++)
                C[i][j] += macc_mul(A[i][k], B[k][j]);
        }
}

void matmul(void) {
    int A[N][N], B[N][N], C_sw[N][N], C_hw[N][N];

    //A = sequential values,B = scaled identity matrix
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            A[i][j] = i * N + j + 1;
            B[i][j] = (i == j) ? (i + 1) : 0;
        }
    uint32_t t0, t1;
    __asm__ volatile ("rdcycle %0" : "=r"(t0));
    matmul_sw(A, B, C_sw);
    __asm__ volatile ("rdcycle %0" : "=r"(t1));
    uint32_t cycles_sw = t1 - t0;
    __asm__ volatile ("rdcycle %0" : "=r"(t0));
    matmul_hw(A, B, C_hw);
    __asm__ volatile ("rdcycle %0" : "=r"(t1));
    uint32_t cycles_hw = t1 - t0;
    print_str("base cycles: ");
    print_dec(cycles_sw);
    print_str("\noptimised cycles: ");
    print_dec(cycles_hw);
    print_str("\n");
    int ok = 1;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            if (C_sw[i][j] != C_hw[i][j]) ok = 0;
    print_str(ok ? "ok\n" : "fail\n");
}