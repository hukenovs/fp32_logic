-------------------------------------------------------------------------------
--
-- Title       : fp32_fix2float
-- Design      : fp unit
-- Author      : Kapitanov
-- Company     : 
--
-------------------------------------------------------------------------------
--
-- Description : Signed fix (24 bits) to float (fp32 custom format)
--
-------------------------------------------------------------------------------
--
--	Version 1.0  25.01.2017
--			   	 Description:
--					Bus width for:
--					din = 24 (23 data + 1 sign)
--					dout = 32	
-- 					exp = 8
-- 					sign = 1
-- 					mant = 23 (+ 1 hidden)
--
--				 !! Math expression: !! 
--				 A = (-1)^sign(A) * 2^(exp(A)-46) * mant(A)
--
--
--				 NB:
--				 1's complement
--				 Converting from fixed to float takes only 4 clock cycles
--
--	MODES: 	Mode0	: normal fix2float (1's complement data)
--			Mode1	: +1 fix2float for negative data (uncomment and 
--					change this code a little: add a component 
-- 					sp_addsub_m1 and some signals): 2's complement data.
--	
--	Version 1.1  26.01.2017
--			   	 Description:
--					New version of FP (Reduced fraction width)
--					DSP48E1 has been removed. Barrel shift is used now.
--					Total delay = 6 clocks
--							 
--	Version 1.5  31.01.2016
--			   	 Description:
--					New barrel shifter with minimum resources. 
--					New FP format: FP32 (Custom!!! Not IEEE754)
--
--	Version 1.6  10.07.2017
--			   	 Description:
--					New generic parameter: IS_CMPL (boolean)  
--					FALSE = 1's complement code
--					TRUE  = 2's complement code
--
--	Version 1.7  12.07.2017
--			   	 Description:
--					Data words code is only 2's complement!
--
--	Version 1.8  11.10.2017
--			   	 Description: Reset signal has been added
--
-------------------------------------------------------------------------------
-- 
-- FIX 2 FLOAT (INT 24 -> FP32)                                             *
--                                 MSB (SIGN)                          SIGN |
--     -------------------------------------------------------------------->|->  
--    |       _____       ______                                            |
--    |      |     | SG  |      |                      _____                |
--    |----->| XOR |---->| LEAD |                     |     |  SET ZERO     |
--    |      |     | MT  |  1.  |------------>|------>| NOR o---->|         |
--  -------->| MSB |---->| FIND |       |     |       |_____|     |         |
--    INT24  |_____| |   |______|       |    _v_                __v__       |
--                   |                  |   /   \              |     |  EXP |
--                   |                  |  / SUB \------------>| EXP |----->|->
--                   |                  |  \  -  /             |_____|      |
--                   |                  |   \___/                           |
--                   |                  |     ^                             |
--                   |                  |     |  EXP - x"3F"                |
--                   |                  |     |_____________                |
--                   |                __v___                                |
--                   |  ABS (DATA)   |      |                           MAN |
--                   >-------------->| FRAC |------------------------------>|-> 
--                                   |______|                               *
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.fp32_pkg.fp32_data;
use work.reduce_pack.nor_reduce;

entity fp32_fix2float is
	generic(
		--IS_CMPL : boolean :=false; --! 0 - 1's complement, 1 - 2's complement
		DW		: integer := 32 --! Data width for integer signal
		);
	port(
		din		: in  std_logic_vector(DW-1 downto 0);	--! Fixed input data					
		ena		: in  std_logic;	--! Data enable 		
		dout	: out fp32_data;	--! Float output data
		vld		: out std_logic;	--! Data out valid      
		clk		: in  std_logic;	--! Clock            
		reset	: in  std_logic		--! Negative Reset            
	);
end fp32_fix2float;

architecture fp32_fix2float of fp32_fix2float is 

	constant FP32_EXP		: std_logic_vector(7 downto 0):=x"3F";
	
	signal rstp				: std_logic;
	signal set_zero			: std_logic;
	
	signal true_form		: std_logic_vector(DW-1 downto 0);	
	signal sum_man		    : std_logic_vector(DW-2 downto 0); 
	signal norm				: std_logic_vector(DW-2 downto 0);	
	signal frac           	: std_logic_vector(22 downto 0);	
	
	signal msb_num			: std_logic_vector(4 downto 0);
	signal msb_numt			: std_logic_vector(4 downto 0);
	signal msb_numz			: std_logic_vector(5 downto 0);
	signal expc				: std_logic_vector(7 downto 0); -- (E - 127) by (IEEE754)

	signal sign				: std_logic_vector(2 downto 0);
	signal valid			: std_logic_vector(4 downto 0);

    signal dinz             : std_logic_vector(DW-1 downto 0);
	signal dinh				: std_logic;
	signal dinx				: std_logic;
	
begin

rstp <= not reset when rising_edge(clk);

-- x1S_COMPL: if (IS_CMPL = FALSE) generate
    -- dinz <= din when rising_edge(clk);
-- end generate;
-- x2S_COMPL: if (IS_CMPL = TRUE) generate
pr_sgn: process(clk) is
begin
	if rising_edge(clk) then
		dinz <= din - din(DW-1);
		dinh <= din(DW-1);
	end if;
end process;      
-- end generate;


---- make abs(data) by using XOR ----
pr_abs: process(clk) is
begin
	if rising_edge(clk) then
		if (rstp = '1') then
			true_form <= (others => '0');
		else
			true_form(DW-1) <= dinz(DW-1) or dinh;
			for ii in 0 to DW-2 loop
				true_form(ii) <= dinz(ii) xor (dinz(DW-1) or dinh);
			end loop;	
		end if;
	end if;
end process;
	
---- fraction delay ----
pr_man: process(clk) begin
	if rising_edge(clk) then 
		sum_man <= true_form(DW-2 downto 0); 		
	end if;
end process; 

---- find MSB (highest '1' position) ----
pr_lead: process(clk) is
begin 
	if rising_edge(clk) then 
		if    (true_form(30-00)='1') then msb_num <= "00001";
		elsif (true_form(30-01)='1') then msb_num <= "00010";
		elsif (true_form(30-02)='1') then msb_num <= "00011";
		elsif (true_form(30-03)='1') then msb_num <= "00100";
		elsif (true_form(30-04)='1') then msb_num <= "00101";
		elsif (true_form(30-05)='1') then msb_num <= "00110";
		elsif (true_form(30-06)='1') then msb_num <= "00111";
		elsif (true_form(30-07)='1') then msb_num <= "01000";
		elsif (true_form(30-08)='1') then msb_num <= "01001";
		elsif (true_form(30-09)='1') then msb_num <= "01010";
		elsif (true_form(30-10)='1') then msb_num <= "01011";
		elsif (true_form(30-11)='1') then msb_num <= "01100";
		elsif (true_form(30-12)='1') then msb_num <= "01101";
		elsif (true_form(30-13)='1') then msb_num <= "01110";
		elsif (true_form(30-14)='1') then msb_num <= "01111";
		elsif (true_form(30-15)='1') then msb_num <= "10000";
		elsif (true_form(30-16)='1') then msb_num <= "10001";
		elsif (true_form(30-17)='1') then msb_num <= "10010";
		elsif (true_form(30-18)='1') then msb_num <= "10011";
		elsif (true_form(30-19)='1') then msb_num <= "10100";
		elsif (true_form(30-20)='1') then msb_num <= "10101";
		elsif (true_form(30-21)='1') then msb_num <= "10110";
		elsif (true_form(30-22)='1') then msb_num <= "10111";
		elsif (true_form(30-23)='1') then msb_num <= "11000";
		elsif (true_form(30-24)='1') then msb_num <= "11001";
		elsif (true_form(30-25)='1') then msb_num <= "11010";
		elsif (true_form(30-26)='1') then msb_num <= "11011";
		elsif (true_form(30-27)='1') then msb_num <= "11100";
		elsif (true_form(30-28)='1') then msb_num <= "11101";
		elsif (true_form(30-29)='1') then msb_num <= "11110";
		elsif (true_form(30-30)='1') then msb_num <= "11111";
		-- elsif (true_form(30-31)='1') then msb_num <= "100000";		
		else msb_num <= "00000";
		end if;	
	end if;
end process;

dinx <= dinz(DW-1) xor dinh when rising_edge(clk);
msb_numz(5) <= dinx when rising_edge(clk);
msb_numz(4 downto 0) <= msb_num;
msb_numt <= msb_num when rising_edge(clk);

---- barrel shifter by 0-23 ----
norm <= STD_LOGIC_VECTOR(SHL(UNSIGNED(sum_man), UNSIGNED(msb_num))) when rising_edge(clk);
frac <= norm(30 downto 8) when rising_edge(clk);

---- Check zero value for fraction and exponent ----
set_zero <= nor_reduce(msb_numz) when rising_edge(clk);
---- find exponent (inv msb - x"2E") ---- 
pr_sub: process(clk) is 
begin
	if rising_edge(clk) then
		if (set_zero = '1') then
			expc <= (others=>'0');
		else
			expc <= FP32_EXP - msb_numt;
		end if;
	end if;
end process;	
	
---- sign delay ----
sign <= sign(sign'left-1 downto 0) & true_form(DW-1) when rising_edge(clk);
   
---- output data ---- 
pr_out: process(clk) is 
begin
	if rising_edge(clk) then
		if (rstp = '1') then
			dout <= (x"00", '0', "000" & x"00000");
		elsif (valid(valid'left) = '1') then
			dout <= (expc, sign(sign'left), frac);
		end if;
	end if;
end process; 

pr_vld: process(clk) is 
begin
	if rising_edge(clk) then
		if (rstp = '1') then
			valid <= (others => '0');
		else
			valid <= valid(valid'left-1 downto 0) & ena;	
		end if;
	end if;
end process; 

-- valid <= valid(valid'left-1 downto 0) & ena when rising_edge(clk);	
vld <= valid(valid'left) when rising_edge(clk);

end fp32_fix2float;