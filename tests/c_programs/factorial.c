#define INPUT_VALUE 5 // Change this to test different numbers
#define EXIT_REG_ADDR                                                          \
  0x40000000 // Common memory-mapped address for testbench exit/pass/fail

// Simple iterative factorial function
unsigned int __mulsi3(unsigned int a, unsigned int b) {
  unsigned int result = 0;
  while (b) {
    if (b & 1)
      result += a;
    a <<= 1;
    b >>= 1;
  }
  return result;
}

unsigned int calculate_factorial(unsigned int n) {
  unsigned int result = 1;
  for (unsigned int i = 1; i <= n; i++) {
    result *= i;
  }
  return result;
}

void main(void) {
  // Compute factorial
  unsigned int result = calculate_factorial(INPUT_VALUE);

  // Expected result for 5! is 120 (0x78)
  volatile int *exit_reg = (volatile int *)EXIT_REG_ADDR;

  if (result == 120) {
    *exit_reg = 0x5555; // Pass signature for testbench
  } else {
    *exit_reg = 0xDEAD; // Fail signature
  }

  // Infinite loop to halt the processor if no explicit trap/exit mechanism
  // exists
  while (1) {
    // Wait for simulation termination
  }
}
