library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity rom_micro is

port( endereco  :   in  std_logic_vector(9 downto 0);  
		enable    :   in  std_logic;             
		saida     :   out std_logic_vector(15 downto 0)); 

end rom_micro;

architecture hardware of rom_micro is

	type MEM_MICRO is array (natural range <>) of std_logic_vector(24 downto 1 );
	
	constant MIC_MEM: MEM_MICRO (0 to 20-1) :=
		
	(	
		-- busca
		"010001001100000000000001", --0 
		"011000100000001000010001", --1
		-- mapeamento
		"100000000000001101000000", --2
		"100000000000001011000000", --3
		"100000000000001111000000", --4
		
		"000000000000000000000000", --5
		"000000000000000000000000", --6
		"000000000000000000000000", --7
		"000000000000000000000000", --8
		"000000000000000000000000", --9
		"000000000000000000000000", --10
		
		-- LOAD
		"010001001100000000100000", --11
		"000000000000010001000000", --12
		-- STORE
		"010001000100000000100000", --13
		"000000010010000000000010", --14
		-- ADD
		"010001001100000000100000", --15
		"000000000000010001000010", --16
		"000000000000000000000000"	 --17
		);

begin

  saida <= MIC_MEM(to_integer(unsigned(endereco))) when enable = '1' else (others => 'Z');
  
end hardware;



