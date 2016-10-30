library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity BUS_ULA1 is

port(  entrada_pc			  		:  in  std_logic_vector(15 downto 0);
		 entrada_acc			  	:  in  std_logic_vector(15 downto 0);
		 entrada_r1			  		:  in  std_logic_vector(15 downto 0);
		 saida		    			:	out std_logic_vector(15 downto 0);
		 en_sc1, en_sc2, en_sc3 :  in  std_logic  );
		
end BUS_ULA1;


architecture hardware of BUS_ULA1 is

  signal  bus1ext: std_logic_vector(15 downto 0);
	
begin


  process(en_sc1, en_sc2, en_sc3)
  
  variable  bus1ext_v: std_logic_vector(15 downto 0);
  
  begin
		
		if (en_sc1 = '1') then 

			bus1ext_v := entrada_pc;
			
		elsif (en_sc2 = '1') then
		
			bus1ext_v  := entrada_acc;
			
		elsif (en_sc3 = '1') then
		
			bus1ext_v := entrada_r1;
		else
			bus1ext_v := x"0000";
			
		end if;
	 
	 bus1ext <= bus1ext_v;
	 
  end process;
  
  saida <= bus1ext;
  
end hardware;