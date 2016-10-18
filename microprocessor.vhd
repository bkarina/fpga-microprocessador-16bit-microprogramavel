library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-------------------------------

entity microprocessor is
	
  port(	clk, rst				 					: in std_logic;
			clk_led						  			: out std_logic);
end microprocessor;
 
-------------------------------
 
architecture behavior of microprocessor is	 
	-- definicao de tipos da memoria
	type MEM_ROM is array (0 to 4096-1) of std_logic_vector(15 downto 0 );
	type MEM_MICRO is array (0 to 1024-1) of std_logic_vector(23 downto 0 );
	
	-- type MEM_FILE is array (0 to 15) of std_logic_vector(7 downto 0 );

	-- ROM: armazena as instrucoes (op|ra|rb|rd)
	signal ROM: MEM_ROM;

	signal MIC_MEM: MEM_MICRO;

	-- registrador de arquivo : env
	--signal RF : MEM_FILE;

	-- contador de programa
	signal PC			: integer range 0 to 4096-1 := 0;
	signal MPC			: integer range 0 to 1024-1 := 0;
	
	--signal PC_temp		: integer range 0 to 255;
	--signal PC_return	: std_logic;
	
	-- registrador de instrucao: armazena instrucao que vem do PC
	signal MIR: std_logic_vector(24 downto 1);
	signal IR: std_logic_vector(15 downto 0);

	-- sinais decodificacao
	signal opcode	: std_logic_vector (3 downto 0);
	
	signal R1		: std_logic_vector (15 downto 0);
	signal R2		: std_logic_vector (15 downto 0);
	signal ACC		: std_logic_vector (15 downto 0);

	
	-- registrador temporario: envia 8bits para a memoria de saida
	-- signal TMP		: std_logic_vector(7 downto 0);


	-- sinal auxiliar para imediatos
	-- signal imediato: std_logic_vector(7 downto 0);


	-- sinal de controle para desligar micro	
	 signal halted	: std_logic;


	-- signal auxilar para clock
	signal slow_clock: std_logic;
	signal slow_count: integer range 0 to 133333334 := 0;


	-- signal auxiliar reset
	signal reset_all : std_logic := '0';
	
	-- signal de controle principal
	signal SC :	std_logic_vector (24 downto 1);	


	-- maquina de moore (FSM)	
	type type_fase is (f_1, f_2, f_3, f_4, f_5); -- Fases da microprogramação
	signal current_fase, next_fase: type_fase;


begin
		

-- Process para dividir o clock, necessário para a visualização das etapas.
slow_clock_process:
			process(clk)
			begin
				if (rising_edge(clk)) then
					slow_count <= slow_count + 1;
					if (slow_count = 133333333) then
						slow_count <= 0;
						slow_clock <= '0';
					elsif (slow_count = 66666667) then
						slow_clock <= '1';
					end if;
				end if;
				clk_led <= slow_clock;
			end process;
		


-- 	Process p atualizar a fase atual com a nova fase, definido pela maquina (fase_change)
--		Atualiza em cada pulso de clock ou assincrona com reset
fase_update:
			process(slow_clock, rst)
			begin
				if (rst = '0') then
					current_fase <= f_1;
				elsif (slow_clock'event and slow_clock = '1') then
					current_fase <= next_fase;
				 end if;
			end process;


-- 	Process para trocar as fase do microprogramado
fase_change:

			process (current_fase)			
			begin
				-- caso seja loop interno do microporograma
				if(SC(24) = '1') then
					next_fase <= f_4;
				else
					case current_fase is				
						when f_1  	=>	next_fase <= f_2;
						when f_2  	=>	next_fase <= f_3;
	

	when f_3  	=>	next_fase <= f_4;
						when f_4  	=>	next_fase <= f_5;
						when f_5  	=>	next_fase <= f_1;
					end case;
				end if;
			end process;


	----------------------------
	-- FASE |	Bits (SP)     --
	----------------------------
	
	-- F_1  |		1 a 9		  --
	-- F_2  |  	  10 a 15     --
	-- F_3  | 	16, 17, 18    --
	-- F_4  |  	  19 a 24     --
	-- F_5  |entrada MIR e MPC--
	----------------------------	
				
output_process:
			process (current_fase, slow_clock, rst)
			begin
				case current_fase is
						when f_1  	=>	
								if(rst = '0') then
								
									reset_all <= '1';
									
									-- busca --
									 MIC_MEM(0)      <= "100000000000001100100010";
									 MIC_MEM(1)      <= "100010000100000001000110";
									 
									 -- mapeamento --
									 MIC_MEM(2)      <= "000000101100000000000001"; -- jump LOAD
									 MIC_MEM(3)      <= "000000110100000000000001"; -- jump STORE
									 MIC_MEM(4)      <= "000000111100000000000001"; -- jump ADD
									 
									 -- LOAD --
									 MIC_MEM(11)     <= "000001000000001100100010";
									 MIC_MEM(12)     <= "000000100010000000000000";
									 
									 -- STORE --
									 MIC_MEM(13)     <= "000001000000001000100010";
									 MIC_MEM(14)     <= "010000000000010010000000";
									 
									 -- ADD --
									 MIC_MEM(15)     <= "000001000000001100100010";					 
									 MIC_MEM(16)     <= "010000100010000000000000";
							 
							 -- atualiza o registrador de instrução com o valor do pc
							 elsif slow_clock'event and slow_clock = '1' then    
							
								MIR <= MIC_MEM(MPC);
							 
							 end if;	
							
							if(SC(1) = '1') then
							end if;
							
							if(SC(2) = '1') then
							end if;
							
							if(SC(3) = '1') then
							end if;
							
							if(SC(4) = '1') then
							end if;
							
							if(SC(5) = '1') then
							end if;
						
				-- FASE 2
						when f_2  	=>	
							if(SC(1) = '1') then
							end if;
							
				-- FASE 3
						when f_3  	=>	
							if(SC(1) = '1') then
							end if;
				
				-- FASE 4
						when f_4  	=>	
							if(SC(1) = '1') then
							end if;
							
				-- FASE 5
						when f_5  	=>
							if(SC(1) = '1') then
							end if;
								
				end case;
			end process;
			
						
end behavior;   