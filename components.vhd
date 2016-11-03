LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.all;

-------------------------------------

PACKAGE components IS

	-- MEMORIAS

	component ram_principal is
		port( dado			  		:  in  std_logic_vector(15 downto 0);
				saida		    		:	out std_logic_vector(15 downto 0);
				endereco      		:  in  std_logic_vector(11 downto 0);
				enable_w, enable  :  in  std_logic);
	end component;

	
	component rom_micro is
		port( endereco  :   in  std_logic_vector(9 downto 0);  
				enable    :   in  std_logic;             
				saida     :   out std_logic_vector(15 downto 0));
	end component;	

	
	-- ULA
	
	-- REGISTRADORES
	
	-- BARRAMENTOS
	
	component bus_ula1 is
		port(  entrada_pc			  		:  in  std_logic_vector(15 downto 0);
				 entrada_acc			  	:  in  std_logic_vector(15 downto 0);
				 entrada_r1			  		:  in  std_logic_vector(15 downto 0);
				 saida		    			:	out std_logic_vector(15 downto 0);
				 en_sc1, en_sc2, en_sc3 :  in  std_logic  );
	end component;	
	
	
	component bus_ula2 is
  		port( entrada_r2			  		:  in  std_logic_vector(15 downto 0);
				entrada_ir			  		:  in  std_logic_vector(11 downto 0); -- apenas o endereço
				entrada_rdm			  		:  in  std_logic_vector(15 downto 0);
				saida		    		      :  out std_logic_vector(15 downto 0);
				en_sc4, en_sc5 			:  in  std_logic;
				en_sc6, en_sc7			   :  in  std_logic);
	end component;	

END components;