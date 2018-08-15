# fp32_logic
Floating point FP32 (same as IEEE-754 w/ some diffs) core HDL. For Xilinx FPGAs. Include base converters and some math functions.
Supported families: 6/7 series, Ultrascale, US+.
Source files: VHDL

FP WORD:
 ___________________
| exp | sign | mant |
|___________________|

  [8]   [1]   [24+1]

Math: 
A = (-1)^sign(A) * 2^(exp(A)-63) * mant(A)

Component list:
  > fp32_fix2float - convert data from INT32 to FP32.
  > fp32_float2fix - convert data from FP32  to INT32.
  > fp32_addsub    - floating point adder.
  > fp32_mult      - floating point multiplier.
