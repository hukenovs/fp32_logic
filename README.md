# fp32_logic
Floating point FP32 (same as IEEE-754 w/ some diffs) core HDL. For Xilinx FPGAs. Include base converters and some math functions.
Supported families: **Xilinx 6/7 series, Ultrascale, US+**.
Source files: **VHDL**

FP WORD 32-bit vector:

EXPONENT - 8-bits.
SIGN - 1-bit
MANTISSA - 24+1 bits.
'1' means hidden one for normalized floating-point values;

Math: 
**A = (-1)^sign(A) * 2^(exp(A)-63) * mant(A)**

Component list:
  * _fp32_fix2float_ - convert data from INT32 to FP32.
  * _fp32_float2fix_ - convert data from FP32  to INT32.
  * _fp32_addsub_    - floating point adder.
  * _fp32_mult_      - floating point multiplier.
