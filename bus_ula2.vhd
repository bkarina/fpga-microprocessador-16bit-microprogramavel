library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity BUS_ULA2 is

port( entrada_r2			  		:  in  std_logic_vector(15 downto 0);
		 entrada_ir			  		:  in  std_logic_vector(11 downto 0); -- apenas o endereço
		 entrada_rdm			  	:  in  std_logic_vector(15 downto 0);
		 saida		    		        :  out std_logic_vector(15 downto 0);
		 en_sc4, en_sc5 			:  in  std_logic;
		 en_sc6, en_sc7			    :  in  std_logic
		 
		 );
		
end BUS_ULA2;


architecture hardware of BUS_ULA2 is

  signal  bus2ext: std_logic_vector(15 downto 0);
	
begin

  
  process(en_sc4, en_sc5, en_sc6, en_sc7)
  
  variable  bus2ext_v: std_logic_vector(15 downto 0);
  
  begin
		
		if (en_sc4 = '1') then 

			bus2ext_v := entrada_r2;
			
		elsif (en_sc5 = '1') then
		
			bus2ext_v  := x"0001";
			
		elsif (en_sc6 = '1') then
		
			bus2ext_v := "0000" & entrada_ir;
			
		elsif (en_sc7 = '1') then
		
		    bus2ext_v := entrada_rdm;
			
		else
			
			bus2ext_v := x"0000";
		
		end if;
	 
	 bus2ext <= bus2ext_v;
	 
  end process;
  
  saida <= bus2ext;
  
end hardware;