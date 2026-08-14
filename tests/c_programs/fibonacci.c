#define FIB_INDEX 10
#define EXIT_REG_ADDR 0x40000000

unsigned int fibonacci(unsigned int n) {
  if (n == 0)
    return 0;
  if (n == 1)
    return 1;

  unsigned int prev = 0;
  unsigned int current = 1;
  unsigned int next;

  for (unsigned int i = 2; i <= n; i++) {
    next = prev + current;
    prev = current;
    current = next;
  }

  return current;
}

void main(void) {
  unsigned int result = fibonacci(FIB_INDEX);
  volatile int *exit_reg = (volatile int *)EXIT_REG_ADDR;

  if (result == 55) {
    *exit_reg = 0x5555; // Pass
  } else {
    *exit_reg = 0xDEAD; // Fail
  }

  while (1) {
    // Wait
  }
}
