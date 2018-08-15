--------------------------------------------------------------------------------
--
-- Title       : rtl_dsp48_25x25
-- Design      : DSP48 MULT
-- Author      : Kapitanov
-- Company     :
--
-------------------------------------------------------------------------------
--
-- Description : floating point multiplier
--
-------------------------------------------------------------------------------
--
--	Version 1.0  10.05.2018
--		Description:
--			Multiplier for integer values
--			3 clock cycles delay
--	
-- 			Has 2 DSP48E1/2 units. Data width: A' = 24, B' = 24, C' = 48;
-- 
--       _______________________________________________________
--      |     ___    ___                                        |
--  DA  | A  |   |  |   |    {MLT}           {ADD}              |
--   ---|--->| Z |->| Z |\    ___    ___      ___    ___        |
--      |    |___|  |___| -->|   |  |   |    |   |  |   |  P    | P2
--      |     ___    ___     | * |->| Z |--->|   |->| Z |------>|--->
--  B2  | B  |   |  |   | -->|___|  |___|    | + |  |___|       |
--   ---|--->| Z |->| Z |/                .->|   |              |
--      |    |___|  |___|                 |  |___|              |
--      |                                _|_                    |
--      |                               /___\ {17-BIT SHR}      |
--      |                                 |                     |
--      |  DSP48                          .-----------------.   |
--      |___________________________________________________|___|
--                                                          ^   {PCIN}
--                                                          |  
--       ___________________________________________________|___{PCOUT}
--      |     ___                                           ^   |
--  DA  | A  |   |           {MLT}           {ADD}          |   |
--   ---|--->| Z |--\         ___    ___      ___    ___    |   |
--      |    |___|   \------>|   |  |   |    |   |  |   |   |   | P1
--      |     ___            | * |->| Z |--->|   |->| Z |---o-->|--->
--  B1  | B  |   |   /------>|___|  |___|    | + |  |___|  P    |
--   ---|--->| Z |->/                     .->|   |              |
--      |    |___|                        |  |___|              |
--      |                                                       |
--      |                                                       |
--      |                                                       |
--      |  DSP48                                                |
--      |____________________________________________________  _|
--      
-- Input:
--
-- DA = A[24:00]
-- B1 = B[16:00]
-- B2 = B[24:17]
--
-- DSP48:
-- PCIN = A * B2 << 17 BIT (Shift register) 
-- P1 = A * B1 = A[24:00] * B[16:00]
-- P2 = A * B2 + PCIN = ( A[24:00] * B[24:17] ) + ( A[24:00] * B[16:00] << 17 )
-- 
-- Output:
-- POUT =  P2[32:00] & P1[16:0].
--
--
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
library unisim;
use unisim.vcomponents.DSP48E1;	
use unisim.vcomponents.DSP48E2;

entity rtl_dsp48_25x25 is
	generic(
		XSERIES : string:="7SERIES" --! Xilinx series
	);
	port(
		d_a		: in  std_logic_vector(24 downto 0); --! Input Multiplicand A
		d_b		: in  std_logic_vector(24 downto 0); --! Input Multiplier B
		d_c		: out std_logic_vector(47 downto 0); --! Product С=A*B
		clk		: in  std_logic; --! Clock
		reset	: in  std_logic --! Reset (positive)
	);
end rtl_dsp48_25x25;

architecture rtl_dsp48_25x25 of rtl_dsp48_25x25 is 
  	
signal p1, p2, pc 		: std_logic_vector(47 downto 0);
signal ax 				: std_logic_vector(29 downto 0);
signal b1, b2			: std_logic_vector(17 downto 0);
signal p_out 			: std_logic_vector(49 downto 0);

begin

ax(24 downto 00) <= d_a(24 downto 0);
ax(29 downto 25) <= (others => d_a(24));
b1(17 downto 0) <= "0" & d_b(16 downto 0);
b2(17 downto 0) <= d_b(24) &  d_b(24) & d_b(24) & d_b(24) & d_b(24) & d_b(24) & d_b(24) & d_b(24) & d_b(24) & d_b(24) & d_b(24 downto 17);

p_out(49 downto 17) <= p2(32 downto 0) after 0.1 ns;
p_out(16 downto 00) <= p1(16 downto 0) after 0.1 ns when rising_edge(clk);
d_c <= p_out(47 downto 0); -- when rising_edge(clk)


-------------------------------------------------------------------------------
x7SERIES: if (XSERIES = "7SERIES") generate
    xDSP2: DSP48E1 --   +/-(A*B+Cin)   -- for Virtex-6 families and 7 series 
    generic map(
            ACASCREG		=> 1,	
            ADREG			=> 0,		
            AREG			=> 2,			
            BCASCREG		=> 1,	
            BREG			=> 2,				
            DREG			=> 0,		
            INMODEREG		=> 1,	
            MREG			=> 1,		   
            PREG			=> 1,		
            USE_DPORT		=> FALSE	
        )		
    port map(      
            P               => p2, 
    --		PCOUT           => , 
            A               => ax,
            ACIN			=> (others=>'0'),
            ALUMODE			=> (others=>'0'),
            B               => b2, 
            BCIN            => (others=>'0'), 
            C               => (others=>'0'),
            CARRYCASCIN		=> '0',
            CARRYIN         => '0', 
            CARRYINSEL      => (others=>'0'),
            CEA1            => '1',
            CEA2            => '1', 		
            CEAD            => '1',
            CEALUMODE       => '1',
            CEB1            => '1', 
            CEB2            => '1', 		
            CEC             => '1', 
            CECARRYIN       => '1', 
            CECTRL          => '1',
            CED				=> '1',
            CEINMODE		=> '1',
            CEM             => '1', 
            CEP             => '1', 
            CLK             => clk,
            D               => (others=>'0'),
            INMODE			=> "00000",		-- for DSP48E1 
            MULTSIGNIN		=> '0',                    
            OPMODE          => "1010101", 		
    --       PCIN            => (others=>'0'),
            PCIN            => pc,
            RSTA            => reset,
            RSTALLCARRYIN	=> reset,
            RSTALUMODE   	=> reset,
            RSTB            => reset, 
            RSTC            => reset, 
            RSTCTRL         => reset,
            RSTD			=> reset,
            RSTINMODE		=> reset,
            RSTM            => reset, 
            RSTP            => reset 
        );	  

    xDSP1: DSP48E1 --   +/-(A*B+Cin)   -- for Virtex-6 families and 7 series 
    -- normalize: DSP48E --   +/-(A*B+Cin) -- for Virtex-5	
    generic map(
            ACASCREG		=> 1,	
            ADREG			=> 0,			
            AREG			=> 1,			
            BCASCREG		=> 1,	
            BREG			=> 1,			
            DREG			=> 0,		
            INMODEREG		=> 1,	     
            MREG			=> 1,		
            PREG			=> 1,		
            USE_DPORT		=> FALSE,	
            USE_MULT		=> "MULTIPLY"	
        )		
    port map(     
            P               => p1, 
            PCOUT           => pc, 
            A               => ax,
            ACIN			=> (others=>'0'),
            ALUMODE			=> (others=>'0'),
            B               => b1, 
            BCIN            => (others=>'0'), 
            C               => (others=>'0'),
            CARRYCASCIN		=> '0',
            CARRYIN         => '0', 
            CARRYINSEL      => (others=>'0'),
            CEA1            => '1',
            CEA2            => '1', 		
            CEAD            => '1',
            CEALUMODE       => '1',
            CEB1            => '1', 
            CEB2            => '1', 		
            CEC             => '1', 
            CECARRYIN       => '1', 
            CECTRL          => '1',
            CED				=> '1',
            CEINMODE		=> '1',
            CEM             => '1', 
            CEP             => '1', 
            CLK             => clk,
            D               => (others=>'0'),
            INMODE			=> "00000",		-- for DSP48E1 
            MULTSIGNIN		=> '0',                    
            OPMODE          => "0000101", 		
            PCIN            => (others=>'0'),
            RSTA            => reset,
            RSTALLCARRYIN	=> reset,
            RSTALUMODE   	=> reset,
            RSTB            => reset, 
            RSTC            => reset, 
            RSTCTRL         => reset,
            RSTD			=> reset,
            RSTINMODE		=> reset,
            RSTM            => reset, 
            RSTP            => reset 
        );	
    end generate;

xULTRA: if (XSERIES = "ULTRA") generate
	xDSP2 : DSP48E2
		generic map (
			-- Feature Control Attributes: Data Path Selection
			AMULTSEL 			=> "A",             
			A_INPUT 			=> "DIRECT",        
			BMULTSEL 			=> "B",             
			B_INPUT 			=> "DIRECT",        
			PREADDINSEL 		=> "A",             
			RND 				=> X"000000000000", 
			USE_MULT 			=> "MULTIPLY",      
			USE_SIMD 			=> "ONE48",         
			USE_WIDEXOR 		=> "FALSE",         
			XORSIMD 			=> "XOR24_48_96",   
			-- Register Control Attributes: Pipeline Register Configuration
			ACASCREG 			=> 1,
			ADREG 				=> 0,
			ALUMODEREG 			=> 1,
			AREG 				=> 2,
			BCASCREG 			=> 1,
			BREG 				=> 2,
			CARRYINREG 			=> 1,
			CARRYINSELREG 		=> 1,
			CREG 				=> 1,
			DREG 				=> 0,
			INMODEREG 			=> 1,
			MREG 				=> 1,
			OPMODEREG 			=> 1,
			PREG 				=> 1 
		)
		port map (
			PCOUT 				=> open,   
			P 					=> p2,
			-- Cascade: 30-bit (each) input: Cascade Ports
			ACIN 				=> (others=>'0'),
			BCIN 				=> (others=>'0'),
			CARRYCASCIN 		=> '0',    
			MULTSIGNIN 			=> '0',    
			PCIN 				=> pc,              
			-- Control: 4-bit (each) input: Control Inputs/Status Bits
			ALUMODE 			=> (others=>'0'),
			CARRYINSEL 			=> (others=>'0'),
			CLK 				=> clk, 
			INMODE 				=> (others=>'0'),
			OPMODE 				=> "001010101", 
			-- Data inputs: Data Ports
			A 					=> ax,    
			B 					=> b2,    
			C 					=> (others=>'0'),         
			CARRYIN 			=> '0',
			D 					=> (others=>'0'),
			-- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
			CEA1 				=> '1', 
			CEA2 				=> '1',    
			CEAD 				=> '1',    
			CEALUMODE 			=> '1',           
			CEB1 				=> '1',                     
			CEB2 				=> '1',                     
			CEC 				=> '1',                       
			CECARRYIN 			=> '1',         
			CECTRL 				=> '1',            
			CED 				=> '1',               
			CEINMODE 			=> '1',          
			CEM 				=> '1',                      
			CEP 				=> '1',                      
			RSTA				=> reset,           
			RSTALLCARRYIN 		=> reset,  
			RSTALUMODE 			=> reset,     
			RSTB 				=> reset,           
			RSTC 				=> reset,           
			RSTCTRL 			=> reset,        
			RSTD 				=> reset,           
			RSTINMODE 			=> reset,      
			RSTM 				=> reset,           
			RSTP 				=> reset   
	   );
	xDSP1 : DSP48E2
		generic map (
			-- Feature Control Attributes: Data Path Selection
			AMULTSEL 			=> "A",             
			A_INPUT 			=> "DIRECT",        
			BMULTSEL 			=> "B",             
			B_INPUT 			=> "DIRECT",        
			PREADDINSEL 		=> "A",             
			RND 				=> X"000000000000", 
			USE_MULT 			=> "MULTIPLY",      
			USE_SIMD 			=> "ONE48",         
			USE_WIDEXOR 		=> "FALSE",         
			XORSIMD 			=> "XOR24_48_96",
			-- Register Control Attributes: Pipeline Register Configuration
			ACASCREG 			=> 1,
			ADREG 				=> 0,
			ALUMODEREG 			=> 1,
			AREG 				=> 1,
			BCASCREG 			=> 1,
			BREG 				=> 1,
			CARRYINREG 			=> 1,
			CARRYINSELREG 		=> 1,
			CREG 				=> 1,
			DREG 				=> 0,
			INMODEREG 			=> 1,
			MREG 				=> 1,
			OPMODEREG 			=> 1,
			PREG 				=> 1 
		)
		port map (
			PCOUT 				=> pc,   
			P 					=> p1,
			-- Cascade: 30-bit (each) input: Cascade Ports
			ACIN 				=> (others=>'0'),
			BCIN 				=> (others=>'0'),
			CARRYCASCIN 		=> '0',    
			MULTSIGNIN 			=> '0',    
			PCIN 				=> (others=>'0'),              
			-- Control: 4-bit (each) input: Control Inputs/Status Bits
			ALUMODE 			=> (others=>'0'),
			CARRYINSEL 			=> (others=>'0'),
			CLK 				=> clk, 
			INMODE 				=> (others=>'0'),
			OPMODE 				=> "000000101", 
			-- Data inputs: Data Ports
			A 					=> ax,    
			B 					=> b1,    
			C 					=> (others=>'0'),         
			CARRYIN 			=> '0',
			D 					=> (others=>'0'),
			-- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
			CEA1 				=> '1', 
			CEA2 				=> '1',    
			CEAD 				=> '1',    
			CEALUMODE 			=> '1',           
			CEB1 				=> '1',                     
			CEB2 				=> '1',                     
			CEC 				=> '1',                       
			CECARRYIN 			=> '1',         
			CECTRL 				=> '1',            
			CED 				=> '1',               
			CEINMODE 			=> '1',          
			CEM 				=> '1',                      
			CEP 				=> '1',                      
			RSTA				=> reset,           
			RSTALLCARRYIN 		=> reset,  
			RSTALUMODE 			=> reset,     
			RSTB 				=> reset,           
			RSTC 				=> reset,           
			RSTCTRL 			=> reset,        
			RSTD 				=> reset,           
			RSTINMODE 			=> reset,      
			RSTM 				=> reset,           
			RSTP 				=> reset   
	   );
end generate;		

end rtl_dsp48_25x25;