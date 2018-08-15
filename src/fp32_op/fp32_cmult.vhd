-------------------------------------------------------------------------------
--
-- Title       : fp32_cmult
-- Design      : fpfftk
-- Author      : Kapitanov
-- Company     :
--
-- Description : Floating point complex multiplier
--
-------------------------------------------------------------------------------
--
--	Version 1.0  19.09.2017
--			   	 Description: Complex floating point multiplier
--
--					DC_RE = DA_RE * DB_RE - DA_IM * DB_IM
--					DC_IM = DA_RE * DB_IM + DA_IM * DB_RE
--
--	Version 1.1  23.04.2018
--			   	 Changelog: added parameter: XSERIES: 7-series / Ultra-scale FPGA
--
--	Version 1.2  26.04.2018
--			   	 Changelog: added parameter: CM_SCALE - Exponent scale factor 
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library work;
use work.fp32_pkg.fp32_complex;
use work.fp32_pkg.fp32_data; 

entity fp32_cmult is
	generic (
		XSERIES : string:="7SERIES" --! Xilinx series
	);
	port(
		DA 		: in  fp32_complex; --! Data A (input)
		DB 		: in  fp32_complex; --! Data B (input)  
		ENA     : in  STD_LOGIC;	--! Input data enable
 
		DC 		: out fp32_complex; --! Data C (output)	
		VAL     : out STD_LOGIC;	--! Output data valid

		RESET   : in  STD_LOGIC; --! Reset            
		CLK     : in  STD_LOGIC	--! Clock	         
	);	
end fp32_cmult;

architecture fp32_cmult of fp32_cmult is

signal fp32_cc		: fp32_complex;	
signal fp32_val		: std_logic;
signal fp32_mlt		: std_logic;

signal fp32_are_bre	: fp32_data;	
signal fp32_are_bim	: fp32_data;
signal fp32_aim_bre	: fp32_data;	
signal fp32_aim_bim	: fp32_data;

constant CM_SCALE	: std_logic_vector(7 downto 0):=x"30";

begin
   
---------------- FlOAT MULTIPLY A*B ----------------		
ARExBRE : entity work.fp32_mult
	generic map( 
		XSERIES => XSERIES,
		EXP_DIF => CM_SCALE
	)
	port map (
		aa 		=> DA.re,	
		bb 		=> DB.re,	
		cc 		=> fp32_are_bre,	
		ena		=> ENA,	
		vld		=> fp32_mlt,	
		rst		=> RESET,	
		clk		=> clk
	);	
	
AIMxBIM : entity work.fp32_mult
	generic map( 
		XSERIES => XSERIES,		
		EXP_DIF => CM_SCALE
	)
	port map (
		aa 		=> DA.im,	
		bb 		=> DB.im,	
		cc 		=> fp32_aim_bim,	
		ena		=> ENA,	
		vld		=> open,
		rst		=> RESET,	
		clk		=> clk
	);	
	
	
ARExBIM : entity work.fp32_mult
	generic map( 
		XSERIES => XSERIES,		
		EXP_DIF => CM_SCALE
	)
	port map (
		aa 		=> DA.re,	
		bb 		=> DB.im,	
		cc 		=> fp32_are_bim,	
		ena		=> ENA,	
		vld		=> open,
		rst		=> RESET,	
		clk		=> clk
	);		
	
AIMxBRE : entity work.fp32_mult
	generic map( 
		XSERIES => XSERIES,		
		EXP_DIF => CM_SCALE
	)
	port map (
		aa 		=> DA.im,	
		bb 		=> DB.re,	
		cc 		=> fp32_aim_bre,	
		ena		=> ENA,	
		vld		=> open,	
		rst		=> RESET,	
		clk		=> clk
	);		
		
---------------- FlOAT ADD/SUB +/- ----------------	
AB_ADD : entity work.fp32_addsub
	port map (
		aa 		=> fp32_are_bim,	
		bb 		=> fp32_aim_bre,	
		cc 		=> fp32_cc.im,	
		addsub	=> '0',
		ena		=> fp32_mlt,
		vld		=> fp32_val,		
		rst		=> RESET,		
		clk		=> clk
	);
	
AB_SUB : entity work.fp32_addsub
	port map (
		aa 		=> fp32_are_bre,	
		bb 		=> fp32_aim_bim,	
		cc 		=> fp32_cc.re,		
		addsub	=> '1',
		ena		=> fp32_mlt,
		vld		=> open,		
		rst		=> RESET,		
		clk		=> clk
	);		

DC <= fp32_cc;-- when rising_edge(clk);
VAL	<= fp32_val;-- when rising_edge(clk);

end fp32_cmult;