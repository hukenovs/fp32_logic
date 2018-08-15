-------------------------------------------------------------------------------
--
-- Title       : fp32_addsub
-- Design      : FPU
-- Author      : Kapitanov
-- Company     :
--
-------------------------------------------------------------------------------
--
-- Description : floating point adder/subtractor
--
-------------------------------------------------------------------------------
--
--	Version 1.0  02.02.2017
--			   	 Description: Common FP32 adder for FFT, 	
--					24 bits - fraction,
--					1 bit   - sign,
--					8 bits  - exponent
--
--	> Reduced DSP48E1 to 1. Barrel shifter is used.		
--	> Add and Sub in 1 component
--			
--	Version 1.1  04.02.2017
--			   	 Description: Reduced DSP48E1 to 0. 2x Barrel shifter is used.
--			
--					> 0 DSP48E1 blocks used; 
--					Total time delay is 14 clocks! 	
--
--	Version 1.2  11.08.2017
--			   	 Description: Add/sub logic changed.
--		
--	Version 1.3  19.08.2017
--			   	 Description: Improved adder logic.
--					Total time delay is 9 clocks! 
--			
--	Version 1.4  11.10.2017
--			   	 Description: Added reset signal
--
--	Version 1.5  01.11.2017 
--			   	 Remove old UNISIM logic for 6/7 series. Works w/ Ultrascale.
--					Reduce total delay on 4 clocks. (-4 taps).
--					Total time delay is 10 clocks! 
--
--	Version 1.6  21.02.2018 
--			   	 Fixed subnormal zeros calculation.
--
--	Version 1.7  26.02.2018 
--			   	 Added: SET_ZERO: when Exponent shifting = b'11111111;
--						SET_ONES: when Exp(A) < Exp shifting (exp out = 0x01)
--						EXP_NORM: when Exp(A) >= Exp shifting (normal op)
--
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

entity fp32_addsub is
	port(
		aa 		: in  fp32_data;	--! Summand/Minuend A   
		bb 		: in  fp32_data;	--! Summand/Substrahend B     
		cc 		: out fp32_data;	--! Sum/Dif C        
		addsub	: in  std_logic;	--! '0' - Add, '1' - Sub
		ena 	: in  std_logic;	--! Input data ena
		vld		: out std_logic;	--! Output data vld          
		clk 	: in  std_logic;	--! Clock
		rst  	: in  std_logic		--! Reset		         
	);
end fp32_addsub;

architecture fp32_addsub of fp32_addsub is 

signal rstp				: std_logic;  

type std_logic_array_5x8 is array (4 downto 0) of std_logic_vector(7 downto 0);

signal aa_z			   	: fp32_data;	  
signal bb_z				: fp32_data;
signal aatr				: std_logic_vector(30 downto 0);
signal bbtr				: std_logic_vector(30 downto 0); 

signal muxa             : fp32_data;
signal muxb             : fp32_data;
signal muxaz            : fp32_data;
signal muxbz            : std_logic_vector(22 downto 0);

signal exp_dif			: std_logic_vector(7 downto 0);

signal implied_a		: std_logic;
signal implied_b		: std_logic; 

signal man_az			: std_logic_vector(23 downto 0);
signal subtract         : std_logic_vector(1 downto 0);

signal sum_manz			: std_logic_vector(23 downto 0);

signal msb_num			: std_logic_vector(5 downto 0);
signal msb_numn			: std_logic_vector(7 downto 0);

signal expc				: std_logic_vector(7 downto 0);
signal norm_c           : std_logic_vector(23 downto 0);
signal frac           	: std_logic_vector(23 downto 0);

signal set_zero			: std_logic;
signal set_ones			: std_logic;

signal expaz			: std_logic_array_5x8;
signal sign_c			: std_logic_vector(5 downto 0);

signal exch				: std_logic;

signal valid			: std_logic_vector(7 downto 0);

signal man_shift		: std_logic_vector(23 downto 0);
signal norm_man			: std_logic_vector(23 downto 0);
signal diff_man			: std_logic_vector(23 downto 0);

signal diff_exp			: std_logic_vector(1 downto 0);
signal man_azz			: std_logic_vector(23 downto 0);
signal sum_co			: std_logic; 
signal ext_sum			: std_logic;

signal sum_mt			: std_logic_vector(24 downto 0);
signal addsign			: std_logic;

attribute use_dsp48 	: string;
attribute use_dsp48 of sum_mt : signal is "NO";

begin	

rstp <= not rst when rising_edge(clk); 	

-- add or sub operation --
pr_addsub: process(clk) is
begin
	if rising_edge(clk) then
		aa_z <= aa;
		if (addsub = '0') then
			bb_z <= bb;
		else
			bb_z <= (bb.exp, not bb.sig, bb.man);
		end if;
	end if;
end process;

-- check difference (least/most attribute) --
aatr <= aa.exp & aa.man;
bbtr <= bb.exp & bb.man;

pr_ex: process(clk) is
begin
	if rising_edge(clk) then
		if (aatr < bbtr) then
			exch <= '0';
		else
			exch <= '1';
		end if;
	end if;
end process; 

-- data switch multiplexer --			
pr_mux: process(clk) is
begin
	if rising_edge(clk) then
		if (exch = '0') then
			muxa <= bb_z;
			muxb <= aa_z;
		else
			muxa <= aa_z;
			muxb <= bb_z;
		end if;
		muxaz <= muxa; 
		muxbz <= muxb.man;	
	end if;							   
end process;		

-- implied '1' for fraction --
pr_imp: process(clk) is
begin
	if rising_edge(clk) then
		if (muxa.exp = x"00") then
			implied_a <= '0';
		else
			implied_a <= '1';
		end if;
		
		if (muxb.exp = x"00") then	
			implied_b <= '0';
		else
			implied_b <= '1';
		end if;	
	end if;
end process;

-- find exponent --
exp_dif <= muxa.exp - muxb.exp when rising_edge(clk);	
diff_exp <= exp_dif(6 downto 5) when rising_edge(clk);

pr_del: process(clk) is
begin
	if rising_edge(clk) then
		man_az <= implied_a & muxaz.man;
		man_azz <= man_az;
		
		subtract(0) <= muxa.sig xor muxb.sig;
		subtract(1) <= subtract(0);
		addsign <= not subtract(1);
	end if;
end process;

man_shift <= implied_b & muxbz;	
norm_man <= STD_LOGIC_VECTOR(SHR(UNSIGNED(man_shift), UNSIGNED(exp_dif(4 downto 0)))) when rising_edge(clk);	

pr_norm_man: process(clk) is
begin
	if rising_edge(clk) then
		if (diff_exp(1 downto 0) = "00") then
			diff_man <= norm_man;
		else
			diff_man <= (others => '0');
		end if;
	end if;
end process;

-- sum of fractions --
pr_man: process(clk) is
begin
	if rising_edge(clk) then
		if (addsign = '1') then
			sum_mt <= ('0' & man_azz) + ('0' & diff_man);
		else
			sum_mt <= ('0' & man_azz) - ('0' & diff_man);
		end if;
	end if;
end process;	

---- find MSB (highest '1' position) ----
pr_lead: process(clk) is
begin 
	if rising_edge(clk) then 
		if    (sum_mt(24-00)='1') then msb_num <= "000000"; 
		elsif (sum_mt(24-01)='1') then msb_num <= "000001";
		elsif (sum_mt(24-02)='1') then msb_num <= "000010";
		elsif (sum_mt(24-03)='1') then msb_num <= "000011";
		elsif (sum_mt(24-04)='1') then msb_num <= "000100";
		elsif (sum_mt(24-05)='1') then msb_num <= "000101";
		elsif (sum_mt(24-06)='1') then msb_num <= "000110";
		elsif (sum_mt(24-07)='1') then msb_num <= "000111";
		elsif (sum_mt(24-08)='1') then msb_num <= "001000";
		elsif (sum_mt(24-09)='1') then msb_num <= "001001";
		elsif (sum_mt(24-10)='1') then msb_num <= "001010";
		elsif (sum_mt(24-11)='1') then msb_num <= "001011";
		elsif (sum_mt(24-12)='1') then msb_num <= "001100";
		elsif (sum_mt(24-13)='1') then msb_num <= "001101";
		elsif (sum_mt(24-14)='1') then msb_num <= "001110";
		elsif (sum_mt(24-15)='1') then msb_num <= "001111";
		elsif (sum_mt(24-16)='1') then msb_num <= "010000";
		elsif (sum_mt(24-17)='1') then msb_num <= "010001";
		elsif (sum_mt(24-18)='1') then msb_num <= "010010";
		elsif (sum_mt(24-19)='1') then msb_num <= "010011";
		elsif (sum_mt(24-20)='1') then msb_num <= "010100";
		elsif (sum_mt(24-21)='1') then msb_num <= "010101";
		elsif (sum_mt(24-22)='1') then msb_num <= "010110";
		-- elsif (sum_mt(24-23)='1') then msb_num <= "010111";
		-- elsif (sum_mt(24-24)='1') then msb_num <= "011000";
		else msb_num <= "111111";
		end if;	
	end if;
end process;
msb_numn <= "00" & msb_num when rising_edge(clk);

----------------------------------------
pr_manz: process(clk) is
begin
	if rising_edge(clk) then 
		if (rstp = '1') then
			sum_manz <= (others=>'0');
		else		
			sum_manz <= sum_mt(24 downto 1); --sum_mt(24 downto 0);
			--sum_mt(24 downto 1); --sum_man(33 downto 16);	
		end if;
	end if;
end process;
----------------------------------------

-- second barrel shifter --
norm_c <= STD_LOGIC_VECTOR(SHL(UNSIGNED(sum_manz), UNSIGNED(msb_num(4 downto 0)))) when rising_edge(clk);	
-- frac <= norm_c when rising_edge(clk);

pr_frac: process(clk) is
begin
	if rising_edge(clk) then 
		if (rstp = '1') then
			frac <= (others => '0');
		else
			frac <= norm_c;
		end if;
	end if;
end process;

-- pr_set: process(clk) is
-- begin
	-- if rising_edge(clk) then 
		-- if (expaz(3) < msb_num) then
			-- set_zero <= '1';
		-- else
			-- set_zero <= '0';
		-- end if;
	-- end if;
-- end process;

-- set zero to find output exponent and fraction --
pr_set0: process(clk) is
begin
	if rising_edge(clk) then 
		-- if (msb_num = "111111") then -- optimize this: check "msb_num" cond.
		if (msb_num(5) = '1') then
			set_zero <= '1';
		else
			set_zero <= '0';
		end if;
	end if;
end process;  

-- set ones to find subnormal exponents --
pr_set1: process(clk) is
begin
	if rising_edge(clk) then 
		if (expaz(3) < ("00" & msb_num)) then
			set_ones <= '1';
		else
			set_ones <= '0';
		end if;
	end if;
end process;

-- exponent increment --	
pr_expx: process(clk) is
begin
	if rising_edge(clk) then 
		if (set_zero = '0') then
			if (set_ones = '0') then
				expc <= expaz(4) - msb_numn + '1';
			else
				expc <= x"01";
			end if;
		else
			expc <= x"00";
		end if;
	end if;
end process;

-- exp & sign delay --
pr_expz: process(clk) is
begin
	if rising_edge(clk) then
		expaz(0) <= muxaz.exp;
		for ii in 0 to 3 loop
			expaz(ii+1) <= expaz(ii);
		end loop;		
	end if;
end process;	

sign_c <= sign_c(sign_c'left-1 downto 0) & muxaz.sig when rising_edge(clk);

-- data out and result --	
cc <= (expc, sign_c(sign_c'left), frac(22 downto 0));-- when rising_edge(clk);

-- pr_dout: process(clk) is
-- begin 		
	-- if rising_edge(clk) then
		-- if (rstp = '1') then
			-- cc <= (x"00", '0', (others=>'0'));
		-- else
			-- cc <= (expc, sign_c(sign_c'left), frac(22 downto 0));
		-- end if;
	-- end if;
-- end process;

valid <= valid(valid'left-1 downto 0) & ena when rising_edge(clk);
vld <= valid(valid'left) when rising_edge(clk);

end fp32_addsub;