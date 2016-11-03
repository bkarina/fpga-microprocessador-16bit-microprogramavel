library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-------------------------------

entity microprocessor is
	
  port(	clk, rst				 					: in std_logic;
			clk_led						  			: out std_logic;
			display_segs1, display_segs2		: out std_logic_vector(6 downto 0);
			display_segs3, display_segs4		: out std_logic_vector(6 downto 0);
			display_segs5, display_segs6		: out std_logic_vector(6 downto 0));
end microprocessor;
 
-------------------------------
 
architecture behavior of microprocessor is	 

	-- definicao de tipos da memoria
	type MEM_ROM is array (0 to 255) of std_logic_vector(15 downto 0 );
	type MEM_FILE is array (0 to 15) of std_logic_vector(7 downto 0 );

	-- ROM: armazena as instrucoes (op|ra|rb|rd)
	signal ROM: MEM_ROM;

	-- registrador de arquivo : env
	signal RF : MEM_FILE;
	
	-- contador de programa
	signal PC			: integer range 0 to 255 := 0;
	signal PC_temp		: integer range 0 to 255;
	signal PC_return	: std_logic;
	
	-- registrador de instrucao: armazena instrucao que vem do PC
	signal IR: std_logic_vector(15 downto 0);
	
	-- sinais decodificacao
	signal opcode	: std_logic_vector (3 downto 0);
	signal RA		: std_logic_vector(3 downto 0);
	signal RB		: std_logic_vector(3 downto 0);
	signal RD		: std_logic_vector(3 downto 0);
	
	-- registrador temporario: envia 8bits para a memoria de saida
	signal TMP		: std_logic_vector(7 downto 0);
	
	-- sinal auxiliar para imediatos
	signal imediato: std_logic_vector(7 downto 0);
	
	-- sinal de controle para desligar micro
	signal halted	: std_logic;

	-- signal auxilar para clock
	signal slow_clock: std_logic;
	signal slow_count: integer range 0 to 133333334 := 0;

	-- signal auxiliar reset
	signal reset_all : std_logic := '0';
	

	-- maquina de moore (FSM)
	type type_state is (s_fetch, s_decode, s_execute, s_store); --Quantidade de estados
	signal current_state, next_state: type_state;


begin
		
		-- maquina de moore de quatro estados (busca|decodificacao|execucao|armazenaento)
		-- primeiro ciclo (fetch)	: BUSCA dados na memoria (ROM), coloca no (PC) em seguida passa para (IR)
		-- segundo  ciclo	(decode)	: DECODIFICA o (IR) para 16-bits (opcode|RA|RB|RD)
		-- terceiro ciclo	(execute): EXECUTA na ULA o opcode e guarda no (TMP)
		-- quarto	ciclo	(store)	: ARMAZENA o resultado do (TMP) no (RF)
		
		
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
		
		
		
state_update:
			process(slow_clock, rst)
			begin
				if (rst = '0') then
					
					current_state <= s_fetch;
				elsif (slow_clock'event and slow_clock = '1') then
					 current_state <= next_state;
				 end if;
			end process;
			
			
			
state_change:
			process (current_state)
			begin
				case current_state is
					
					when s_fetch  	=>	next_state <= s_decode;
					
					when s_decode 	=>	next_state <= s_execute;
					
					when s_execute =>	next_state <= s_store;
					
					when s_store 	=>	next_state <= s_fetch;
							
				end case;
			end process;

			
			
output_process:
			process (current_state, slow_clock, rst)
			begin
				case current_state is
					when s_fetch 	=>	
						
											 if (rst = '0') then
												 
												 reset_all <= '1';
												 
												 ROM(0)  	 <= "0001000000100000";
												 ROM(1)  	 <= "0001000001110001";
												 ROM(2)  	 <= "0010000000010010";
												 ROM(3)  	 <= "0001000111110100";
												 ROM(4)  	 <= "0010010000100011";
												 ROM(5)  	 <= "1000010000000000";
												 ROM(6)  	 <= "0011001000010110";
												 ROM(7)  	 <= "0000000000000000";
												 ROM(8)  	 <= "0000000000000000";
												 ROM(9)  	 <= "0000000000000000";
												 ROM(10)     <= "0000000000000000";
												 ROM(11)     <= "0000000000000000";
												 ROM(12)     <= "0000000000000000";
												 ROM(13)     <= "0000000000000000";
												 ROM(14)     <= "0000000000000000";
												 ROM(15)     <= "0000000000000000";
												 ROM(16)     <= "0000000000000000";
												 ROM(17)     <= "0000000000000000";
												 ROM(18 to 255) <= (others => x"0000");
											 
											 elsif slow_clock'event and slow_clock = '1' then    
												 IR <= ROM(PC);
											 end if;					
						
											
										
											
					when s_decode	=>
					
											 if (reset_all = '1') then
												  opcode  	<=  "1111";
												  RA      	<=  "0000";
												  RB      	<=  "0000";
												  RD      	<=  "0000";
												  imediato 	<=  "00000000";
													  
											 elsif slow_clock'event and slow_clock = '1' then
												  opcode  	<= IR(15 downto 12 );
												  RA      	<= IR(11 downto 8  );
												  RB      	<= IR(7  downto 4  );
												  RD      	<= IR(3  downto 0  );
												  imediato 	<= IR(11 downto 4  );
											 end if;           
					
					
					
							--pc process
											if (reset_all = '1') then
												PC <= 0;
											
											elsif (halted = '1') then
												PC <= PC;
											
											elsif slow_clock'event and slow_clock = '1' then
												
												if (opcode = "1001") then 
													PC_temp <= PC;
													PC <= to_integer(unsigned(imediato));
													PC_return <= '1';
												
												elsif (PC_return = '1') then
													PC <= PC_temp + 1;
													PC_return <= '0';
												
												else
													PC <= PC + 1;
												end if;
											end if;
					
					when s_execute =>
									
											 if (reset_all = '1') then
														  TMP 		<= "00000000";
														  halted  	<= '0';
											
											elsif slow_clock'event and slow_clock = '1' then
														if  (opcode = "0000")   then  -- HALT
															 halted <= '1';
															 TMP <= "00000000";
														
														elsif (opcode = "0001") then-- LDR
															 TMP <= imediato;
														
														elsif (opcode = "0010") then-- ADD
															 TMP <= RF(to_integer(unsigned(RA))) +   RF(to_integer(unsigned(RB)));
														
														elsif (opcode = "0011") then -- SUB
															 TMP <= RF(to_integer(unsigned(RA))) -   RF(to_integer(unsigned(RB)));
														
														elsif (opcode = "0100") then -- OR
															 TMP <= RF(to_integer(unsigned(RA))) OR  RF(to_integer(unsigned(RB)));
														
														elsif (opcode = "1000") then -- XOR
															 TMP <= RF(to_integer(unsigned(RA))) XOR RF(to_integer(unsigned(RB)));
														
														elsif (opcode = "1001") then 
															 TMP <= imediato;                                   
														
														else
															 TMP <= "00000000";
														
														end if;
											 end if;
							
					when s_store	=>
											 
											 if (reset_all = '1') then
												 RF(0) 	<= x"00";
												 RF(1) 	<= x"00";
												 RF(2) 	<= x"00";
												 RF(3) 	<= x"00";
												 RF(4) 	<= x"00";
												 RF(5) 	<= x"00";
												 RF(6) 	<= x"00";
												 RF(7) 	<= x"00";
												 RF(8) 	<= x"00";
												 RF(9) 	<= x"00";
												 RF(10) 	<= x"00";
												 RF(11) 	<= x"00";
												 RF(12) 	<= x"00";
												 RF(13) 	<= x"00";
												 RF(14) 	<= x"00";
												 RF(15) 	<= x"00";
												 
												 reset_all <= '0';
											 
											 elsif slow_clock'event and slow_clock = '1' then
												 RF(to_integer(unsigned(RD))) <= TMP;
											end if;
				end case;
				
			end process;
			
										

											display_segs6 <= 	"0000001" when opcode 	=	"0000" else
																	"1001111" when opcode	=	"0001" else
																	"0010010" when opcode	=	"0010" else
																	"0000110" when opcode	=	"0011" else
																	"1001100" when opcode	=	"0100" else
																	"0100100" when opcode	=	"0101" else
																	"0100000" when opcode	=	"0110" else
																	"0001111" when opcode	=	"0111" else
																	"0000000" when opcode	=	"1000" else
																	"0000100" when opcode	=	"1001" else
																	"0001000" when opcode	=	"1010" else
																	"1100000" when opcode	=	"1011" else
																	"0110001" when opcode	=	"1100" else
																	"1000010" when opcode	=	"1101" else
																	"0110000" when opcode	=	"1110" else
																	"0111000";
																	
																	
											display_segs5 <= 	"0000001" when RA =	"0000" else
																	"1001111" when RA	=	"0001" else
																	"0010010" when RA =	"0010" else
																	"0000110" when RA =	"0011" else
																	"1001100" when RA	=	"0100" else
																	"0100100" when RA	=	"0101" else
																	"0100000" when RA =	"0110" else
																	"0001111" when RA =	"0111" else
																	"0000000" when RA =	"1000" else
																	"0000100" when RA =	"1001" else
																	"0001000" when RA =	"1010" else
																	"1100000" when RA =	"1011" else
																	"0110001" when RA =	"1100" else
																	"1000010" when RA =	"1101" else
																	"0110000" when RA =	"1110" else
																	"0111000";
																	
											display_segs4 <= 	"0000001" when RB =	"0000" else
																	"1001111" when RB	=	"0001" else
																	"0010010" when RB =	"0010" else
																	"0000110" when RB =	"0011" else
																	"1001100" when RB	=	"0100" else
																	"0100100" when RB	=	"0101" else
																	"0100000" when RB =	"0110" else
																	"0001111" when RB =	"0111" else
																	"0000000" when RB =	"1000" else
																	"0000100" when RB =	"1001" else
																	"0001000" when RB =	"1010" else
																	"1100000" when RB =	"1011" else
																	"0110001" when RB =	"1100" else
																	"1000010" when RB =	"1101" else
																	"0110000" when RB =	"1110" else
																	"0111000";
																	
											display_segs3 <= 	"0000001" when RD =	"0000" else
																	"1001111" when RD	=	"0001" else
																	"0010010" when RD =	"0010" else
																	"0000110" when RD =	"0011" else
																	"1001100" when RD	=	"0100" else
																	"0100100" when RD	=	"0101" else
																	"0100000" when RD =	"0110" else
																	"0001111" when RD =	"0111" else
																	"0000000" when RD =	"1000" else
																	"0000100" when RD =	"1001" else
																	"0001000" when RD =	"1010" else
																	"1100000" when RD =	"1011" else
																	"0110001" when RD =	"1100" else
																	"1000010" when RD =	"1101" else
																	"0110000" when RD =	"1110" else
																	"0111000";		
										
			
											display_segs2 <=  "0000001" when TMP(7 downto 4) 	=	"0000" else
																	"1001111" when TMP(7 downto 4)	=	"0001" else
																	"0010010" when TMP(7 downto 4)	=	"0010" else
																	"0000110" when TMP(7 downto 4)	=	"0011" else
																	"1001100" when TMP(7 downto 4)	=	"0100" else
																	"0100100" when TMP(7 downto 4)	=	"0101" else
																	"0100000" when TMP(7 downto 4)	=	"0110" else
																	"0001111" when TMP(7 downto 4)	=	"0111" else
																	"0000000" when TMP(7 downto 4)	=	"1000" else
																	"0000100" when TMP(7 downto 4)	=	"1001" else
																	"0001000" when TMP(7 downto 4)	=	"1010" else
																	"1100000" when TMP(7 downto 4)	=	"1011" else
																	"0110001" when TMP(7 downto 4)	=	"1100" else
																	"1000010" when TMP(7 downto 4)	=	"1101" else
																	"0110000" when TMP(7 downto 4)	=	"1110" else
																	"0111000";
																	
											display_segs1 <= 	"0000001" when TMP(3 downto 0)   =	"0000" else
																	"1001111" when TMP(3 downto 0)	=	"0001" else
																	"0010010" when TMP(3 downto 0)	=	"0010" else
																	"0000110" when TMP(3 downto 0)	=	"0011" else
																	"1001100" when TMP(3 downto 0)	=	"0100" else
																	"0100100" when TMP(3 downto 0)	=	"0101" else
																	"0100000" when TMP(3 downto 0)	=	"0110" else
																	"0001111" when TMP(3 downto 0)	=	"0111" else
																	"0000000" when TMP(3 downto 0)	=	"1000" else
																	"0000100" when TMP(3 downto 0)	=	"1001" else
																	"0001000" when TMP(3 downto 0)	=	"1010" else
																	"1100000" when TMP(3 downto 0)	=	"1011" else
																	"0110001" when TMP(3 downto 0)	=	"1100" else
																	"1000010" when TMP(3 downto 0)	=	"1101" else
																	"0110000" when TMP(3 downto 0)	=	"1110" else
																	"0111000";
end behavior;   