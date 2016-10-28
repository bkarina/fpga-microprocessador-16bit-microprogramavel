






	library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-------------------------------
entity microprocessor is
 port(	clk, rst				 					: in std_logic;
			clk_led						  			: out std_logic;
		   display_segs1, display_segs2, display_segs3		: out std_logic_vector(6 downto 0);
			display_segs4, display_segs5, display_segs6		: out std_logic_vector(6 downto 0)
			);
end microprocessor;
 
-------------------------------
 
architecture behavior of microprocessor is	 
	-- definicao de tipos da memoria
	type MEM_ROM is array (0 to 50-1) of std_logic_vector(15 downto 0 );
	type MEM_MICRO is array (0 to 50-1) of std_logic_vector(24 downto 1 );

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
	
	-- registradores de uso geral
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

	-- display
	
	type bcd_num is array (0 to 9) of std_logic_vector(6 downto 0);
	signal seg_nums : bcd_num := (
											"0000001", "1001111", "0010010", "0000110", "1001100",
											"0100100", "1100000", "0001111", "0000000", "0001100");
					

begin
		
-- Process para dividir o clock, necessário para a visualização das etapas.
slow_clock_process:
			process(clk)
			
			variable slow_count_v: integer range 0 to 133333334 :=  0;
			variable slow_clock_v: std_logic;
			
			begin
			
--			slow_count_v := slow_count;
--			slow_clock_v := slow_clock;
				
				if (rising_edge(clk)) then
					
					slow_count_v := slow_count_v + 1;
					
					if (slow_count_v = 133333333) then
						
						slow_count_v := 0;
					
						slow_clock_v := '0';
					
					elsif (slow_count_v = 66666667) then
					
						slow_clock_v := '1';
				
					end if;
				
				end if;
			
				clk_led <= slow_clock_v;
				slow_count <= slow_count_v;
				slow_clock <= slow_clock_v;
			
			end process;

-- 	Process p atualizar a fase atual com a nova fase, definido pela maquina (fase_change)
--		Atualiza em cada pulso de clock ou assincrona com reset
fase_update:
			process(slow_clock, rst)
			
			variable current_fase_v: type_fase;
			
			begin
				
				if (rst = '0') then
				
					current_fase_v := f_1;
				
				elsif (slow_clock'event and slow_clock = '1') then
						
					current_fase_v := next_fase;
				 
				 end if;
			
			current_fase <= current_fase_v;
			
			end process;

-- 	Process para trocar as fase do microprogramado
fase_change:
			process (current_fase)	
	
			variable next_fase_v: type_fase;
			
			begin
				-- caso seja loop interno do microporograma
				if(SC(24) = '1' and not(current_fase = f_4) and not(current_fase = f_5)) then
				
					next_fase_v := f_4;
				
				else
					
					case current_fase is				
					
						when f_1  	=>	next_fase_v := f_2;
			
						when f_2  	=>	next_fase_v := f_3;
						
						when f_3  	=>	next_fase_v := f_4;
						
						when f_4  	=>	next_fase_v := f_5;
						
						when f_5  	=>	next_fase_v := f_1;
					
					end case;
				
				end if;
				
				next_fase <= next_fase_v;
				
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
			
			-- Barramentos externos
			variable BUS_ULA1_v: std_logic_vector(15 downto 0);
			variable BUS_ULA2_v: std_logic_vector(15 downto 0);
			variable BUS_EXT3_v: std_logic_vector (15 downto 0);
	
			-- Barramentos internos
			variable BUS_INT1_v: std_logic_vector(9 downto 0);
			variable BUS_INT2_v: std_logic_vector(9 downto 0);
			variable BUS_INT3_v: std_logic_vector(9 downto 0);
			
			
			-- Mems
			variable PRIN_MEM_v: MEM_ROM;
			variable MIC_MEM_v: MEM_MICRO;
		
			-- contador de programa
			variable PC_v :	std_logic_vector (15 downto 0);
			
			-- contador de microprograma
			variable MPC_v :	std_logic_vector (9 downto 0);
				
			-- registrador de instrucao: armazena instrucao que vem do PC
			variable IR_v: std_logic_vector(15 downto 0);
		
			-- registradores de memoria 
			variable RDM_v : std_logic_vector (15 downto 0);
			variable REM1_v : std_logic_vector (15 downto 0);
			
			-- registradores de uso geral
			variable R1_v		: std_logic_vector (15 downto 0);
			variable R2_v		: std_logic_vector (15 downto 0);
			variable ACC_v	: std_logic_vector (15 downto 0);
			
			-- signal auxiliar reset
			variable reset_all_v : std_logic := '0';
	
			-- signal de controle principal
			variable SC_v :	std_logic_vector (24 downto 1);
			
			begin			
			
				case current_fase is
						
						when f_1  	=>	
							
							if(rst = '0') then
								
									reset_all_v := '1';
									
									-- busca --
									 MIC_MEM_v(0)      := "010001001100000000000001";
									 MIC_MEM_v(1)      := "011000100000001000010001";
									 
									 -- mapeamento --
									 MIC_MEM_v(2)      := "100000000000001101000000"; -- jump LOAD
									 MIC_MEM_v(3)      := "100000000000001011000000"; -- jump STORE
									 MIC_MEM_v(4)      := "100000000000001111000000"; -- jump ADD
									 
									 -- LOAD --:=
									 MIC_MEM_v(11)     := "010001001100000000100000";
									 MIC_MEM_v(12)     := "000000000000010001000000";
									 
									 -- STORE --:=
									 MIC_MEM_v(13)     := "010001000100000000100000";
									 MIC_MEM_v(14)     := "000000010010000000000010";
									 
									 -- ADD --:=
									 MIC_MEM_v(15)     := "010001001100000000100000";					 
									 MIC_MEM_v(16)     := "000000000000010001000010";
							 
							 end if;	
							
							-- O controle de barramento funciona como a logica do 3state, evitando curto no barramento
							-- controle do barramento ext1
							if(SC_v(1) = '1') then

								BUS_ULA1_v := PC_v;
							
							elsif(SC_v(2)  = '1') then
								
								BUS_ULA1_v := ACC_v;
							
							elsif(SC_v(3)  = '1') then
								
								BUS_ULA1_v := R1_v;
							
							end if;
							
							-- controle do barramento ext2
							if(SC_v(4)  = '1') then
								
								BUS_ULA2_v := R2_v;
							
							elsif(SC_v(5) = '1') then
								
								BUS_ULA2_v := "0000000000000001";
					
							elsif(SC_v(6)  = '1') then
							
								BUS_ULA2_v(15 downto 12)  := "0000";
								BUS_ULA2_v(11 downto 0)   := IR_v(11 downto 0);
								
							elsif(SC_v(7)  = '1') then
							
								BUS_ULA2_v := RDM_v;
							
							end if;
							
							
							-- logica da ULA: ----------------------------
							----------------------------------------------
							-- SC 8 : BUS3 <- (BUS1)-(BUS 2)				  --
							-- SC 9 : BUS3 <- SHIFT LEFT((BUS1)-(BUS 2))--
							----------------------------------------------
			
							if(SC_v(8)  = '1') then
								
								BUS_EXT3_v := BUS_ULA1_v - BUS_ULA2_v;
							
							elsif(SC_v(9)  = '1') then
								
								BUS_EXT3_v := (BUS_ULA1_v(14 downto 0) + BUS_ULA2_v(14 downto 0)) & '0';
								
							else
								
								BUS_EXT3_v := BUS_ULA1_v + BUS_ULA2_v;
							
							end if;
						
				-- FASE 2
						when f_2  	=>	
							
							if(SC_v(10)  = '1') then
									
								PC_v := BUS_EXT3_v;
							
							end if;
							
							if(SC_v(11)  = '1') then
							
								Acc_v := BUS_EXT3_v;
							
							end if;
							
							if(SC_v(12) = '1') then
							
								R1_v := BUS_EXT3_v;
							
							end if;
							
							if(SC_v(13)  = '1') then
							
								R2_v := BUS_EXT3_v;
							
							end if;
							
							if(SC_v(14)  = '1') then
							
								RDM_v := BUS_EXT3_v;
							
							end if;
							
							if(SC_v(15)  = '1') then
								-- contem todo o valor do barramento, porem só utiliza 12bits para o endereco (4k)
								REM1_v := BUS_EXT3_v;
					
							end if;
							

				-- FASE 3
						when f_3  =>
						
							if(SC_v(16)  = '1') then
							
								RDM_v := PRIN_MEM_v(to_integer(unsigned(REM1_v(15 downto 4))));
							
							elsif (SC_v(17)  = '1') then
							
								PRIN_MEM_v(to_integer(unsigned(REM1_v(15 downto 4)))) := RDM_v;
							
							end if;

							if(SC_v (18)  = '1') then
							
								IR_v := RDM_v;
							
							end if;
							
			
				-- FASE 4

						when f_4  	=>	
							
							if(SC_v (19)  = '1') then
								
								BUS_INT1_v := "0000000001";
					
							--TEST ZERO
							elsif (SC_v (20)  = '1') then
								-- 1 se (Acc) = 0
								--	2 se (Acc) != 0
								if (Acc = "0000000000000000") then
								
									BUS_INT1_v := "0000000001";
								
								else
								
									BUS_INT1_v := "0000000010";
								
								end if;
							
							--TEST NEG
							elsif (SC_v(21) = '1') then
								-- 1 se (Acc) < 0
								--	2 se (Acc) >= 0
								if (Acc < "0000000000000000") then
							
									BUS_INT1_v := "0000000001";
								
								else
								
									BUS_INT1_v := "0000000010";
								
								end if;
								
							elsif (SC_v (22) = '1') then
								
								BUS_INT1_v := "000000" & IR(15 downto 12);
							
							end if;
							
							if (SC_v (23) = '1') then
								
								BUS_INT2_v := MPC_v;
							
							elsif (SC_v (24) = '1') then
								
								BUS_INT2_v := SC(15 downto 6);
									
							end if;
							
						-- antes da FASE 5 é necessario atualizar a 'ula' interna
						BUS_INT3_v := BUs_INT1_v + BUS_INT2_v;
							
							
				-- FASE 5
						when f_5  	=>
							
							-- atualiza mpc com ula interna
							MPC_v := BUS_INT3_v;
							
							if(SC_v (24) = '1') then
								SC_v := MIC_MEM_v(to_integer(unsigned(MPC_v)));
							end if;
								
				end case;
				
			 -- Barramentos externos
			 BUS_ULA1 <= BUS_ULA1_v;
			 BUS_ULA2 <= BUS_ULA2_v;
			 BUS_EXT3 <= BUS_EXT3_v; 
	
			 -- Barramentos internos
			 BUS_INT1 <= BUS_INT1_v;
			 BUS_INT2 <= BUS_INT2_v;
			 BUS_INT3 <= BUS_INT3_v;
			
			
			 -- Mems
			 PRIN_MEM <= PRIN_MEM_v;
			 MIC_MEM <= MIC_MEM_v;
		
			 -- contador de programa
			 PC <= PC_v;
			
			 -- contador de microprograma
			 MPC <= MPC_v;
			
			 -- registrador de instrucao: armazena instrucao que vem do PC
			 IR <= IR_v;
		
			 -- registradores de memoria 
			 RDM <= RDM_v;
			 REM1 <= REM1_v;
			
			 -- registradores de uso geral
			 R1	 <= R1_v;
			 R2	 <= R2_v;
			 ACC <= ACC_v;
			
			 -- signal auxiliar reset
			 reset_all <= reset_all_v;
	
			 -- signal de controle principal
			 SC <= SC_v;
				
			end process;
										 
			display_segs1 <= seg_nums(to_integer(unsigned(MPC)));
			display_segs2 <= seg_nums(to_integer(unsignedx'(IR(15 downto 12))));
			display_segs3 <= seg_nums(3);
			display_segs4 <= seg_nums(4);
			display_segs5 <= seg_nums(5);
			display_segs6 <= seg_nums(6);
					
																	
  						
end behavior;   





						
		
			  
		