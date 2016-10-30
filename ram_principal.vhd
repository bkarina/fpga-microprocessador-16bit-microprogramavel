library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ram_principal is

port( dado			  		:  in  std_logic_vector(15 downto 0);
		saida		    		:	out std_logic_vector(15 downto 0);
		endereco      		:  in  std_logic_vector(11 downto 0);
		enable_w, enable  :  in  std_logic);

end ram_principal;


architecture hardware of ram_principal is
 
	type MEM_ROM is array (0 to 20-1) of std_logic_vector(15 downto 0 );
  	
	signal  PRIN_MEM: MEM_ROM;
	
begin

  process(enable, endereco)
  begin
  
	if rising_edge(enable) then -- dado armazenado na subida de "ce" com "we=0"
		
		if enable_w = '0' then 

			PRIN_MEM(to_integer(unsigned(endereco))) <= dado;

		end if;
	end if;
	 
  end process;
  
  saida <= PRIN_MEM(to_integer(unsigned(endereco)));
  
end hardware;
