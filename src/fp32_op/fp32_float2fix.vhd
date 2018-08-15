-------------------------------------------------------------------------------
--
-- Title       : fp32_float2fix
-- Design      : fpfftk
-- Author      : Kapitanov
-- Company     :
--
-------------------------------------------------------------------------------
--
-- Description : Float FP32 to signed FIX32 converter
--
-------------------------------------------------------------------------------
--
--	Version 1.0  22.01.2017
--			   	 Description:
--					Bus width for:
--					din = 24 (23 data + 1 sign)
--					dout = 32	
-- 					exp = 8
-- 					sign = 1
-- 					mant = 23 (+ 1 hidden)
--
--				 Math expression: 
--					A = (-1)^sign(A) * 2^(exp(A)-46) * mant(A)
--
--				Another algorithm: double precision with 2 DSP48E1.
--	 
--	Version 1.1  24.01.2017
--
--					> 2 DSP48E1 blocks used (MEGA_DSP);
--					> SLICEL logic has been simplified;	  
--					> Clear all unrouted signals and components;  
-- 
--	Version 1.2  21.02.2017
--					> Add Barrel shifter instead of DSP48E1;  
--					> Data out width is only 24 bits. 
--					> Add constant for negative data converter. 
--
--					> Careful: check all conditions of input fp data 
--						Example: exp = 0xFF, sig = 0, man = 0x000000;  
-- 
--	Version 1.3  10.08.2017
--			   	 Description:
--					New generic parameter: IS_CMPL (boolean)  
--					FALSE = 1's complement code
--					TRUE  = 2's complement code
--
--	Version 1.4  11.08.2017
--			   	 Description:
--					Data out has 32 bits 
--
--	Version 1.5  12.08.2017
--			   	 Description:
--					Logic delay = 5 taps 
--
--	Version 1.6  13.08.2017
--			   	 Description:
--					Logic delay = 4 taps 
--					Data is only 2's complement!
--
--	Version 1.7  11.10.2017
--			   	 Description: Added reset signal
--
--	Version 1.8  21.01.2018
--					> Change exp shift logic
--					> Overflow and underflow logic has been improved. 
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	The MIT License (MIT)
--	Copyright (c) 2018 Kapitanov Alexander 													 
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
-- use work.reduce_pack.and_reduce;

entity fp32_float2fix is
	port(
		din			: in  fp32_data;						--! Float input data	
		ena			: in  std_logic;						--! Data enable                        
		scale		: in  std_logic_vector(07 downto 0);	--! Scale factor 	   
		dout		: out std_logic_vector(31 downto 0);	--! Fixed output data
		vld			: out std_logic;						--! Data out valid
		clk			: in  std_logic;						--! Clock
		reset		: in  std_logic;						--! Negative reset			
		overflow	: out std_logic							--! Flag overflow 		                      
	);
end fp32_float2fix;

architecture fp32_float2fix of fp32_float2fix is 

signal rstp				: std_logic;
signal implied			: std_logic;

signal exp_dif			: std_logic_vector(4 downto 0);
signal exp_dift			: std_logic_vector(7 downto 0);
signal shift			: std_logic_vector(7 downto 0);

signal norm_man			: std_logic_vector(31 downto 0);
signal mant				: std_logic_vector(31 downto 0);
signal frac				: std_logic_vector(22 downto 0);  
signal sign_z			: std_logic_vector(2 downto 0);	
signal valid			: std_logic_vector(2 downto 0);	

signal exp_null			: std_logic; 
signal exp_nullz		: std_logic; 
signal exp_nullt		: std_logic; 
signal exp_cmp			: std_logic;
signal exp_ovr			: std_logic;

signal overflow_i		: std_logic;

begin	
  
rstp <= not reset when rising_edge(clk); 
shift <= scale when rising_edge(clk);	

---- exp difference ----	
pr_exp: process(clk) is
begin
	if rising_edge(clk) then
		exp_dift <= din.exp - shift;
	end if;
end process;

pr_cmp: process(clk) is
begin
	if rising_edge(clk) then
		if (din.exp < shift) then
			exp_cmp <= '1';
		else
			exp_cmp <= '0';
		end if;
	end if;
end process;

-- exp_null <= exp_dift(7) when rising_edge(clk);   	
exp_null <= exp_cmp when rising_edge(clk);   	
exp_nullz <= exp_null when rising_edge(clk);   	 

pr_ovf: process(clk) is
begin
	if rising_edge(clk) then
		if ("00011110" < exp_dift) then
			exp_ovr <= '1';
		else
			exp_ovr <= '0';
		end if;
	end if;
end process;

exp_nullt <= exp_ovr when rising_edge(clk);  

-- implied for mantissa and find sign
pr_impl: process(clk) is
begin 
	if rising_edge(clk) then
		if (din.exp = x"00") then
			implied	<='0';
		else 
			implied	<='1';
		end if;
	end if;
end process;	

-- find fraction --
frac <= din.man when rising_edge(clk);
pr_man: process(clk) is
begin 
	if rising_edge(clk) then
		mant(31 downto 8) <= implied & frac;
		if (sign_z(0) = '0') then
			mant(7 downto 0) <=	x"00";
		else
			mant(7 downto 0) <=	x"FF";
		end if;
	end if;
end process;
sign_z <= sign_z(sign_z'left-1 downto 0) & din.sig when rising_edge(clk);

-- barrel shifter --	
exp_dif <= not exp_dift(4 downto 0) when rising_edge(clk);
norm_man <= STD_LOGIC_VECTOR(SHR(UNSIGNED(mant), UNSIGNED(exp_dif))) when rising_edge(clk);

-- x2S_COMPL: if (IS_CMPL = TRUE) generate
	-- pr_sgn: process(clk) is
	-- begin
		-- if rising_edge(clk) then
			-- if (sign_z(1) = '0') then
				-- norm_manz <= norm_man;
			-- else
				-- norm_manz <= norm_man - 1;
			-- end if;
		-- end if;
	-- end process;      
-- end generate;

-- data valid and data out --
pr_out: process(clk) is
begin
	if rising_edge(clk) then
		if (rstp = '1') then 
			dout <= (others => '0');
		else
			if (exp_nullz = '1') then
				-- dout <= (others => sign_z(2));
				dout <= (others => '0');
			-- elsif (overflow_i = '1') then
			elsif (exp_nullt = '1') then
				dout(31) <= sign_z(2);
				for ii in 0 to 30 loop
					dout(ii) <=	not sign_z(2);	 
				end loop;		
			else
				if (sign_z(2) = '1') then
					dout <=	(not norm_man) + 1;
				else
					dout <=	norm_man;
				end if;				
			end if;	
		end if;
	end if;	
end process;

pr_vld: process(clk) is
begin
	if rising_edge(clk) then
		if (rstp = '1') then 
			vld <= '0';
		else
			vld <= valid(valid'left);
		end if;
	end if;	
end process;

valid <= valid(valid'left-1 downto 0) & ena when rising_edge(clk);	

pr_ovr: process(clk) is
begin 
	if rising_edge(clk) then
		overflow_i <= exp_nullt and not exp_nullz;
	end if;
end process;

overflow <= overflow_i when rising_edge(clk); 

end fp32_float2fix;