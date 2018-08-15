-------------------------------------------------------------------------------
--
-- Title       : fp_m1_pkg
-- Design      : fpfftk
-- Author      : Kapitanov
-- Company     :
--
-- Description : FP useful package
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	The MIT License (MIT)
--	Copyright (c) 2016 Kapitanov Alexander 													 
--		                                          				 
-- Permission is hereby granted, free of charge, to any person obtaining a copy 
-- of this software and associated documentation files (the "Software"), 
-- to deal in the Software without restriction, including without limitation 
-- the rights to use, copy, modify, merge, publish, distribute, sublicense, 
-- and/or sell copies of the Software, and to permit persons to whom the 
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in 
-- all copies or substantial portions of the Software.
--
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
-- IN THE SOFTWARE.
--                                                  
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;

library work;
use work.reduce_pack.nor_reduce;

package	fp32_pkg is

	-- Useful types of ROM data for twiddle factor: data width = 16 bit --
	type std_array_16x1    is array (0 to 0)      of std_logic_vector(15 downto 00); 	
	type std_array_16x2    is array (0 to 1)      of std_logic_vector(15 downto 00); 	
	type std_array_16x4    is array (0 to 3)      of std_logic_vector(15 downto 00); 	
	type std_array_16x8    is array (0 to 7)      of std_logic_vector(15 downto 00); 	
	type std_array_16x16   is array (0 to 15)     of std_logic_vector(15 downto 00); 	
	type std_array_16x32   is array (0 to 31)     of std_logic_vector(15 downto 00); 	
	type std_array_16x64   is array (0 to 63)     of std_logic_vector(15 downto 00); 		
	type std_array_16x128  is array (0 to 127)    of std_logic_vector(15 downto 00); 		
	type std_array_16x256  is array (0 to 255)    of std_logic_vector(15 downto 00); 		
	type std_array_16x512  is array (0 to 511)    of std_logic_vector(15 downto 00); 		
	type std_array_16x1K   is array (0 to 1023)   of std_logic_vector(15 downto 00); 
	type std_array_16x2K   is array (0 to 2047)   of std_logic_vector(15 downto 00); 	
	type std_array_16x4K   is array (0 to 4095)   of std_logic_vector(15 downto 00); 	
	type std_array_16x8K   is array (0 to 8191)   of std_logic_vector(15 downto 00); 	
	type std_array_16x16K  is array (0 to 16383)  of std_logic_vector(15 downto 00); 	
	type std_array_16x32K  is array (0 to 32767)  of std_logic_vector(15 downto 00); 	
	type std_array_16x64K  is array (0 to 65535)  of std_logic_vector(15 downto 00); 	
	type std_array_16x128K is array (0 to 131071) of std_logic_vector(15 downto 00); 	
	type std_array_16x256K is array (0 to 262143) of std_logic_vector(15 downto 00);  
	type std_array_16x512K is array (0 to 524287) of std_logic_vector(15 downto 00);  
	
	-- Useful types of ROM data for twiddle factor: data width = 32 bit --
	type std_array_32x1    is array (0 to 0)      of std_logic_vector(31 downto 00); 	
	type std_array_32x2    is array (0 to 1)      of std_logic_vector(31 downto 00); 	
	type std_array_32x4    is array (0 to 3)      of std_logic_vector(31 downto 00); 	
	type std_array_32x8    is array (0 to 7)      of std_logic_vector(31 downto 00); 	
	type std_array_32x16   is array (0 to 15)     of std_logic_vector(31 downto 00); 	
	type std_array_32x32   is array (0 to 31)     of std_logic_vector(31 downto 00); 	
	type std_array_32x64   is array (0 to 63)     of std_logic_vector(31 downto 00); 		
	type std_array_32x128  is array (0 to 127)    of std_logic_vector(31 downto 00); 		
	type std_array_32x256  is array (0 to 255)    of std_logic_vector(31 downto 00); 		
	type std_array_32x512  is array (0 to 511)    of std_logic_vector(31 downto 00); 		
	type std_array_32x1K   is array (0 to 1023)   of std_logic_vector(31 downto 00); 
	type std_array_32x2K   is array (0 to 2047)   of std_logic_vector(31 downto 00); 	
	type std_array_32x4K   is array (0 to 4095)   of std_logic_vector(31 downto 00); 	
	type std_array_32x8K   is array (0 to 8191)   of std_logic_vector(31 downto 00); 	
	type std_array_32x16K  is array (0 to 16383)  of std_logic_vector(31 downto 00); 	
	type std_array_32x32K  is array (0 to 32767)  of std_logic_vector(31 downto 00); 	
	type std_array_32x64K  is array (0 to 65535)  of std_logic_vector(31 downto 00); 	
	type std_array_32x128K is array (0 to 131071) of std_logic_vector(31 downto 00); 	
	type std_array_32x256K is array (0 to 262143) of std_logic_vector(31 downto 00);  
	type std_array_32x512K is array (0 to 524287) of std_logic_vector(31 downto 00); 
	
	type fp32_data is record
		exp 	: std_logic_vector(07 downto 0); 
		sig 	: std_logic;
		man 	: std_logic_vector(22 downto 0);
	end record;		
	
	type fp32_complex is record
		re : fp32_data;
		im : fp32_data;
	end record;

	type std32_complex is record
		re : std_logic_vector(31 downto 0);
		im : std_logic_vector(31 downto 0);
	end record;	
	
	type std16_complex is record
		re : std_logic_vector(15 downto 0);
		im : std_logic_vector(15 downto 0);
	end record;	
	
	
	procedure fn_fix2fp32(
		data_i	: in std_logic_vector(31 downto 0);
		data_o	: out std_logic_vector(31 downto 0)
	);		
	
	
end fp32_pkg;

package body fp32_pkg is

	procedure fn_fix2fp32(
		data_i	: in  std_logic_vector(31 downto 0);
		data_o	: out std_logic_vector(31 downto 0)
	) 
	is
		variable man1 		: std_logic_vector(31 downto 00):=(others=>'0');
		variable man2 		: std_logic_vector(31 downto 00):=(others=>'0');
		
		variable msb_num	: std_logic_vector(5 downto 0);

		variable norm		: std_logic_vector(30 downto 0);		
		variable frac		: std_logic_vector(22 downto 0);
		
		variable expc		: std_logic_vector(7 downto 0);
		
	begin
		man1 := data_i - data_i(31);
		
		man2(31) := data_i(31) or man1(31);
		for ii in 0 to 30 loop
			man2(ii) := man1(ii) xor (data_i(31) or man1(31));
		end loop;

		if    (man2(30-00)='1') then msb_num := "000001";
		elsif (man2(30-01)='1') then msb_num := "000010";
		elsif (man2(30-02)='1') then msb_num := "000011";
		elsif (man2(30-03)='1') then msb_num := "000100";
		elsif (man2(30-04)='1') then msb_num := "000101";
		elsif (man2(30-05)='1') then msb_num := "000110";
		elsif (man2(30-06)='1') then msb_num := "000111";
		elsif (man2(30-07)='1') then msb_num := "001000";
		elsif (man2(30-08)='1') then msb_num := "001001";
		elsif (man2(30-09)='1') then msb_num := "001010";
		elsif (man2(30-10)='1') then msb_num := "001011";
		elsif (man2(30-11)='1') then msb_num := "001100";
		elsif (man2(30-12)='1') then msb_num := "001101";
		elsif (man2(30-13)='1') then msb_num := "001110";
		elsif (man2(30-14)='1') then msb_num := "001111";
		elsif (man2(30-15)='1') then msb_num := "010000";
		elsif (man2(30-16)='1') then msb_num := "010001";
		elsif (man2(30-17)='1') then msb_num := "010010";
		elsif (man2(30-18)='1') then msb_num := "010011";
		elsif (man2(30-19)='1') then msb_num := "010100";
		elsif (man2(30-20)='1') then msb_num := "010101";
		elsif (man2(30-21)='1') then msb_num := "010110";
		elsif (man2(30-22)='1') then msb_num := "010111";
		elsif (man2(30-23)='1') then msb_num := "011000";
		elsif (man2(30-24)='1') then msb_num := "011001";
		elsif (man2(30-25)='1') then msb_num := "011010";
		elsif (man2(30-26)='1') then msb_num := "011011";
		elsif (man2(30-27)='1') then msb_num := "011100";
		elsif (man2(30-28)='1') then msb_num := "011101";
		elsif (man2(30-29)='1') then msb_num := "011110";
		elsif (man2(30-30)='1') then msb_num := "011111";	
		else msb_num := "000000";
		end if;	
	
		norm := STD_LOGIC_VECTOR(SHL(UNSIGNED(man2(30 downto 0)), UNSIGNED(msb_num(4 downto 0))));
		frac := norm(30 downto 8);
		
		if ((msb_num(4 downto 0) = "00000") and ((data_i(31) xor man1(31)) = '0')) then
			expc := (others=>'0');
		else
			expc := x"3F" - msb_num;
		end if;		
	
		data_o(31 downto 24) := expc;
		data_o(23) := man2(31);
		data_o(22 downto 00) := frac;
		
	end fn_fix2fp32;	
	
	
end package	body fp32_pkg;