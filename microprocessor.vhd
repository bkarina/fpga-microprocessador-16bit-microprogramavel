library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-------------------------------
entity microprocessor is
 port(	clk, rst				 					: in std_logic;
			clk_led						  			: out std_logic;
			display_segs6							: out std_logic_vector(6 downto 0)
			);
end microprocessor;
 
-------------------------------
 
architecture behavior of microprocessor is	 
	-- definicao de tipos da memoria
	type MEM_ROM is array (0 to 4096-1) of std_logic_vector(15 downto 0 );
	type MEM_MICRO is array (0 to 1024-1) of std_logic_vector(24 downto 1 );

	-- Barramentos externos 1_2 (ULA) e 3
	signal BUS_ULA1: std_logic_vector(15 downto 0);
	signal BUS_ULA2: std_logic_vector(15 downto 0);
	
	signal BUS_EXT3: std_logic_vector (15 downto 0);
	
	-- Barramentos interno 1_2 (MIC) e 3
	signal BUS_INT1: std_logic_vector(9 downto 0);
	signal BUS_INT2: std_logic_vector(9 downto 0);
	signal BUS_INT3: std_logic_vector(9 downto 0);
	
	
	-- ROM: armazena as instrucoes (op|ra|rb|rd)
	signal PRIN_MEM: MEM_ROM;

	signal MIC_MEM: MEM_MICRO;

	-- contador de programa
	--signal PC			: integer range 0 to 4096-1 := 0;
	signal PC :	std_logic_vector (15 downto 0);
	
	-- contador de microprograma
	signal MPC :	std_logic_vector (9 downto 0);
		
	-- registrador de instrucao: armazena instrucao que vem do PC
	signal IR: std_logic_vector(15 downto 0);

	-- registrador de memoria 
	signal RDM : std_logic_vector (15 downto 0);
	
	signal REM1 : std_logic_vector (15 downto 0);

	-- registradores gerais
	signal R1		: std_logic_vector (15 downto 0);
	signal R2		: std_logic_vector (15 downto 0);
	signal ACC		: std_logic_vector (15 downto 0);
	
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
				if(SC(24) = '1' and not(current_fase = f_4 or current_fase = f_5)) then
				
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
									 MIC_MEM(0)      <= "010001001100000000000001";
									 MIC_MEM(1)      <= "011000100000001000010001";
									 
									 -- mapeamento --
									 MIC_MEM(2)      <= "100000000000001101000000"; -- jump LOAD
									 MIC_MEM(3)      <= "100000000000001011000000"; -- jump STORE
									 MIC_MEM(4)      <= "100000000000001111000000"; -- jump ADD
									 
									 -- LOAD --
									 MIC_MEM(11)     <= "010001001100000000100000";
									 MIC_MEM(12)     <= "000000000000010001000000";
									 
									 -- STORE --
									 MIC_MEM(13)     <= "010001000100000000100000";
									 MIC_MEM(14)     <= "000000010010000000000010";
									 
									 -- ADD --
									 MIC_MEM(15)     <= "010001001100000000100000";					 
									 MIC_MEM(16)     <= "000000000000010001000010";
							 
							 
							 end if;	
							
							-- O controle de barramento funciona como a logica do 3state, evitando curto no barramento
							-- controle do barramento ext1
							if(SC(1) = '1') then

								BUS_ULA1 <= PC;
							
							elsif(SC(2) = '1') then
								
								BUS_ULA1 <= ACC;
							
							elsif(SC(3) = '1') then
								
								BUS_ULA1 <= R1;
							
							end if;
							
							-- controle do barramento ext2
							if(SC(4) = '1') then
								
								BUS_ULA2 <= R2;
							
							elsif(SC(5) = '1') then
								
								BUS_ULA2 <= "0000000000000001";
					
							elsif(SC(6) = '1') then
							
								BUS_ULA2(15 downto 12)  <= "0000";
								BUS_ULA2(11 downto 0)   <= IR(11 downto 0);
								
							elsif(SC(7) = '1') then
							
								BUS_ULA2 <= RDM;
							
							end if;
							
							
							-- logica da ULA: ----------------------------
							----------------------------------------------
							-- SC 8 : BUS3 <- (BUS1)-(BUS 2)				  --
							-- SC 9 : BUS3 <- SHIFT LEFT((BUS1)-(BUS 2))--
							----------------------------------------------
			
							if(SC(8) = '1') then
								
								BUS_EXT3 <= BUS_ULA1 - BUS_ULA2;
							
							elsif(SC(9) = '1') then
								
								BUS_EXT3 <= (BUS_ULA1(14 downto 0) + BUS_ULA2(14 downto 0)) & '0';
								
							else
								
								BUS_EXT3 <= BUS_ULA1 + BUS_ULA2;
							
							end if;
						
				-- FASE 2
						when f_2  	=>	
							
							if(SC(10) = '1') then
									
								PC <= BUS_EXT3;
							
							end if;
							
							if(SC(11) = '1') then
							
								Acc <= BUS_EXT3;
							
							end if;
							
							if(SC(12) = '1') then
							
								R1 <= BUS_EXT3;
							
							end if;
							
							if(SC(13) = '1') then
							
								R2 <= BUS_EXT3;
							
							end if;
							
							if(SC(14) = '1') then
							
								RDM <= BUS_EXT3;
							
							end if;
							
							if(SC(15) = '1') then
								-- contem todo o valor do barramento, porem só utiliza 12bits para o endereco (4k)
								REM1 <= BUS_EXT3;
					
							end if;
							

				-- FASE 3
						when f_3  =>
						
							if(SC(16) = '1') then
							
								RDM <= PRIN_MEM(to_integer(unsigned(REM1(15 downto 4))));
							
							elsif (SC(17) = '1') then
							
								PRIN_MEM(to_integer(unsigned(REM1(15 downto 4)))) <= RDM;
							
							end if;
							

							if(SC(18) = '1') then
							
								IR <= RDM;
							
							end if;
							
			
				-- FASE 4

						when f_4  	=>	
							
							if(SC(19) = '1') then
								
								BUS_INT1 <= "0000000001";
					
							--TEST ZERO
							elsif (SC(20) = '1') then
								-- 1 se (Acc) = 0
								--	2 se (Acc) != 0
								if (Acc = "0000000000000000") then
								
									BUS_INT1 <= "0000000001";
								
								else
								
									BUS_INT1 <= "0000000010";
								
								end if;
							
							--TEST NEG
							elsif (SC(21) = '1') then
								-- 1 se (Acc) < 0
								--	2 se (Acc) >= 0
								if (Acc < "0000000000000000") then
							
									BUS_INT1 <= "0000000001";
								
								else
								
									BUS_INT1 <= "0000000010";
								
								end if;
								
							elsif (SC(22) = '1') then
								
								BUS_INT1 <= "000000" & IR(15 downto 12);
							
							end if;
							
							if (SC(23) = '1') then
								
								BUS_INT2 <= MPC;
							
							elsif (SC(24) = '1') then
								
								BUS_INT2 <= SC(15 downto 6);
									
							end if;
							
						-- antes da FASE 5 é necessario atualizar a 'ula' interna
						BUS_INT3 <= BUs_INT1 + BUS_INT2;
							
							
				-- FASE 5
						when f_5  	=>
							
							-- atualiza mpc com ula interna
							MPC <= BUS_INT3;
							
							if(SC(24) = '1') then
								SC <= MIC_MEM(to_integer(unsigned(MPC)));
							end if;
								
				
				
				
				
				
				
						-- display
				
					--	if(MPC = "0000000001") then
						--	display_segs6 <= "0000001";
						--elsif(MPC = "0000000011") then
						--	display_segs6 <= "1001111";
						--elsif(MPC = "0000000100") then
						--	display_segs6 <= "0010010";
						--elsif(MPC = "0000000101") then
						--	display_segs6 <= "0000110";
						--elsif(MPC = "0000000110") then
						--	display_segs6 <= "1001100";
						--else
						--	display_segs6 <= "0111000";
						--end if;
						
					--case MPC is				
					
						--	when "0000000001" => display_segs6 <= "0000001";
						--	when "0000000011" => display_segs6 <= "1001111";
						--	when "0000000100" => display_segs6 <= "0010010";
						--	when "0000000101" => display_segs6 <= "0000110";
						--	when "0000000110" => display_segs6 <= "1001100";
						--	when 		  OTHERS => display_segs6 <= "0111000";	
					--	end case;
							
				
						
				
				
				end case;
				
			end process;
		
end behavior;