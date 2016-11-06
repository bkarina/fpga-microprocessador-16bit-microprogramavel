library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-------------------------------
entity microprocessor is
 port(  clk, rst                    : in std_logic;
            clk_led                                 : out std_logic;
           display_segs1, display_segs2, display_segs3      : out std_logic_vector(6 downto 0);
            display_segs4, display_segs5, display_segs6     : out std_logic_vector(6 downto 0)
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
    --signal PC         : integer range 0 to 4096-1 := 0;
    signal PC : std_logic_vector (15 downto 0);
   
    -- contador de microprograma
    signal MPC :    std_logic_vector (9 downto 0);
       
    -- registrador de instrucao: armazena instrucao que vem do PC
    signal IR: std_logic_vector(15 downto 0);
 
    -- registrador de memoria
    signal RDM : std_logic_vector (15 downto 0);
   
    signal REM1 : std_logic_vector (15 downto 0);
   
    -- registradores de uso geral
    signal R1       : std_logic_vector (15 downto 0);
    signal R2       : std_logic_vector (15 downto 0);
    signal ACC      : std_logic_vector (15 downto 0);
   
    -- sinal de controle para desligar micro   
     signal halted  : std_logic;
 
    -- signal auxilar para clock
    signal slow_clock: std_logic;
    signal slow_count: integer range 0 to 133333334 := 0;
 
    -- signal auxiliar reset
    signal reset_all : std_logic := '0';
   
    -- signal de controle principal
    signal SC : std_logic_vector (24 downto 1);
   
    -- maquina de moore (FSM)  
    type type_fase is (f_1, f_2, f_3, f_4, f_5); -- Fases da microprogramação
    signal current_fase, next_fase: type_fase;
 
    -- display
   
    type bcd_num is array (0 to 15) of std_logic_vector(6 downto 0);
    signal seg_nums : bcd_num := (
                                            "0000001", "1001111", "0010010", "0000110", "1001100",
                                            "0100100", "1100000", "0001111", "0000000", "0001100",
                                            "0001000", "1100000","0110001", "1000010", "0110000", "0111000");
                   
 
begin
       
-- Process para dividir o clock, necessário para a visualização das etapas.
slow_clock_process:
            process(clk)
           
            variable slow_count_v: integer range 0 to 133333334 :=  0;
            variable slow_clock_v: std_logic;
           
            begin
           
--          slow_count_v := slow_count;
--          slow_clock_v := slow_clock;
               
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
 
--  Process p atualizar a fase atual com a nova fase, definido pela maquina (fase_change)
--      Atualiza em cada pulso de clock ou assincrona com reset
fase_update:
            process(slow_clock, rst)
           
            variable current_fase_v: type_fase;
           
            begin
               
                if (rst = '0') then
               
                    current_fase_v := f_1;
                    reset_all <= '1';
                   
               
                elsif (slow_clock'event and slow_clock = '1') then
                       
                    current_fase_v := next_fase;
                    reset_all <= '0';
                 
                 end if;
           
            current_fase <= current_fase_v;
           
            end process;
 
--  Process para trocar as fase do microprogramado
fase_change:
            process (current_fase) 
   
            variable next_fase_v: type_fase;
           
            begin
                -- caso seja loop interno do microporograma
                if(SC(24) = '1' and not(current_fase = f_4) and not(current_fase = f_5)) then
               
                    next_fase_v := f_4;
               
                else
                   
                    case current_fase is               
                   
                        when f_1    =>  next_fase_v := f_2;
           
                        when f_2    =>  next_fase_v := f_3;
                       
                        when f_3    =>  next_fase_v := f_4;
                       
                        when f_4    =>  next_fase_v := f_5;
                       
                        when f_5    =>  next_fase_v := f_1;
                   
                    end case;
               
                end if;
               
                next_fase <= next_fase_v;
               
            end process;
           
    ----------------------------
    -- FASE |   Bits (SP)     --
    ----------------------------
    -- F_1  |       1 a 9         --
    -- F_2  |     10 a 15     --
    -- F_3  |   16, 17, 18    --
    -- F_4  |     19 a 24     --
    -- F_5  |entrada MIR e MPC--
    ----------------------------   
               
output_process:
            process (current_fase, slow_clock, reset_all)
           
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
            variable PC_v : std_logic_vector (15 downto 0);
           
            -- contador de microprograma
            variable MPC_v :    std_logic_vector (9 downto 0);
               
            -- registrador de instrucao: armazena instrucao que vem do PC
            variable IR_v: std_logic_vector(15 downto 0);
       
            -- registradores de memoria
            variable RDM_v : std_logic_vector (15 downto 0);
            variable REM1_v : std_logic_vector (15 downto 0);
           
            -- registradores de uso geral
            variable R1_v       : std_logic_vector (15 downto 0);
            variable R2_v       : std_logic_vector (15 downto 0);
            variable ACC_v  : std_logic_vector (15 downto 0);
           
           
   
            -- signal de controle principal
            variable SC_v : std_logic_vector (24 downto 1);
           
       
           
            begin          
           
                       
                            if(reset_all = '1') then
 
                                     IR_v := x"0000";
                                     MPC_v := "00" & x"00";
                                     PC_v := x"0000";
                                     BUS_ULA1_v :=x"0000";
                                     BUS_ULA2_v :=x"0000";
                                     BUS_EXT3_v :=x"0000"; 
                                     BUS_INT1_v := "00" & x"00";
                                     BUS_INT2_v := "00" & x"00";
                                     BUS_INT3_v := "00" & x"00";
                               
                                    -- busca --
                                     MIC_MEM_v(0)      := "010001001100000000000001";
                                     MIC_MEM_v(1)      := "011000100000001000010001";
                                     
                                     SC_v := MIC_MEM_v(0);
                                     
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
                                     MIC_MEM_v(5)      := "000000000000000000000000";
                                     MIC_MEM_v(6)      := "000000000000000000000000";
                                     MIC_MEM_v(7)      := "000000000000000000000000";
                                     MIC_MEM_v(8)      := "000000000000000000000000";
                                     MIC_MEM_v(9)      := "000000000000000000000000";
                                     MIC_MEM_v(10)     := "000000000000000000000000";
                                     MIC_MEM_v(17)     := "000000000000000000000000";
                                     MIC_MEM_v(18)     := "000000000000000000000000";
                                     MIC_MEM_v(19)     := "000000000000000000000000";
                                     MIC_MEM_v(20)     := "000000000000000000000000";
                                     MIC_MEM_v(21)     := "000000000000000000000000";
                                     MIC_MEM_v(22)     := "000000000000000000000000";
                                     MIC_MEM_v(23)     := "000000000000000000000000";
                                     MIC_MEM_v(24)     := "000000000000000000000000";
                                     MIC_MEM_v(25)     := "000000000000000000000000";
                                     MIC_MEM_v(26)     := "000000000000000000000000";
                                     MIC_MEM_v(27)     := "000000000000000000000000";
                                     MIC_MEM_v(28)     := "000000000000000000000000";
                                     MIC_MEM_v(29)     := "000000000000000000000000";
                                     MIC_MEM_v(30)     := "000000000000000000000000";
                                     MIC_MEM_v(31)     := "000000000000000000000000";
                                     MIC_MEM_v(32)     := "000000000000000000000000";
                                     MIC_MEM_v(33)     := "000000000000000000000000";
                                     MIC_MEM_v(34)     := "000000000000000000000000";
                                     MIC_MEM_v(35)     := "000000000000000000000000";
                                     MIC_MEM_v(36)     := "000000000000000000000000";
                                     MIC_MEM_v(37)     := "000000000000000000000000";
                                     MIC_MEM_v(38)     := "000000000000000000000000";
                                     MIC_MEM_v(39)     := "000000000000000000000000";
                                     MIC_MEM_v(40)     := "000000000000000000000000";
                                     MIC_MEM_v(41)     := "000000000000000000000000";
                                     MIC_MEM_v(42)     := "000000000000000000000000";
                                     MIC_MEM_v(43)     := "000000000000000000000000";
                                     MIC_MEM_v(44)     := "000000000000000000000000";
                                     MIC_MEM_v(45)     := "000000000000000000000000";
                                     MIC_MEM_v(46)     := "000000000000000000000000";
                                     MIC_MEM_v(47)     := "000000000000000000000000";
                                     MIC_MEM_v(48)     := "000000000000000000000000";
                                     MIC_MEM_v(49)     := "000000000000000000000000";
                             
                             
                                     PRIN_MEM_v(0) := "0000000001000001";
                                     PRIN_MEM_v(1) := "0000000001010010";
                                     PRIN_MEM_v(2) := "0000000000001000";  
                                     PRIN_MEM_v(3) := "0000000000000000";
                                     PRIN_MEM_v(4) := "0000000000001000";
                                     PRIN_MEM_v(5) := "0000000000000000";
                                     PRIN_MEM_v(6) := "0000000000000000";
                                     PRIN_MEM_v(7) := "0000000000000000";
                                     PRIN_MEM_v(8) := "0000000000000000";
                                     PRIN_MEM_v(9) := "0000000000000000";
                                     PRIN_MEM_v(10) := "0000000000000000";
                                     PRIN_MEM_v(11):= "0000000000000000";
                                     PRIN_MEM_v(12):= "0000000000000000";
                                     PRIN_MEM_v(13):= "0000000000000000";
                                     PRIN_MEM_v(14):= "0000000000000000";
                                     PRIN_MEM_v(15):= "0000000000000000";                    
                                     PRIN_MEM_v(16):= "0000000000000000";                              
                                     PRIN_MEM_v(17) := "0000000000000000";
                                     PRIN_MEM_v(18) := "0000000000000000";
                                     PRIN_MEM_v(19) := "0000000000000000";
                                     PRIN_MEM_v(20) := "0000000000000000";
                                     PRIN_MEM_v(21) := "0000000000000000";
                                     PRIN_MEM_v(22) := "0000000000000000";
                                     PRIN_MEM_v(23) := "0000000000000000";
                                     PRIN_MEM_v(24) := "0000000000000000";
                                     PRIN_MEM_v(25) := "0000000000000000";
                                     PRIN_MEM_v(26) := "0000000000000000";
                                     PRIN_MEM_v(27) := "0000000000000000";
                                     PRIN_MEM_v(28) := "0000000000000000";
                                     PRIN_MEM_v(29) := "0000000000000000";
                                     PRIN_MEM_v(30) := "0000000000000000";
                                     PRIN_MEM_v(31) := "0000000000000000";
                                     PRIN_MEM_v(32) := "0000000000010010";
                                     PRIN_MEM_v(33) := "0000000000000000";
                                     PRIN_MEM_v(34) := "0000000000000000";
                                     PRIN_MEM_v(35) := "0000000000000000";
                                     PRIN_MEM_v(36) := "0000000000000000";
                                     PRIN_MEM_v(37) := "0000000000000000";
                                     PRIN_MEM_v(38) := "0000000000000000";
                                     PRIN_MEM_v(39) := "0000000000000000";
                                     PRIN_MEM_v(40) := "0000000000100000";
                                     PRIN_MEM_v(41) := "0000000000000000";
                                     PRIN_MEM_v(42) := "0000000000000000";
                                     PRIN_MEM_v(43) := "0000000000000000";
                                     PRIN_MEM_v(44) := "0000000000000000";
                                     PRIN_MEM_v(45) := "0000000000000000";
                                     PRIN_MEM_v(46) := "0000000000000000";
                                     PRIN_MEM_v(47) := "0000000000000000";
                                     PRIN_MEM_v(48) := "0000000000000000";
                                     PRIN_MEM_v(49) := "0000000000000000";
                                     
                               
                    else
                             
                        case current_fase is
                                   
                        when f_1    => 
                           
                            -- O controle de barramento funciona como a logica do 3state, evitando curto no barramento
                            -- controle do barramento ext1
                            if(SC_v(1) = '1') then
 
                                BUS_ULA1_v := PC_v;
                           
                            elsif(SC_v(2)  = '1') then
                               
                                BUS_ULA1_v := ACC_v;
                           
                            elsif(SC_v(3)  = '1') then
                               
                                BUS_ULA1_v := R1_v;
                            else
                                BUS_ULA1_v := x"0000";
                           
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
                           
                            else
                                BUS_ULA2_v := x"0000";
                            end if;
                           
                           
                            -- logica da ULA: ----------------------------
                            ----------------------------------------------
                            -- SC 8 : BUS3 <- (BUS1)-(BUS 2)                  --
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
                        when f_2    => 
                           
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
 
                        when f_4    => 
                           
                            if(SC_v (19)  = '1') then
                               
                                BUS_INT1_v := "0000000001";
                   
                            --TEST ZERO
                            elsif (SC_v (20)  = '1') then
                                -- 1 se (Acc) = 0
                                --  2 se (Acc) != 0
                                if (Acc = "0000000000000000") then
                               
                                    BUS_INT1_v := "0000000001";
                               
                                else
                               
                                    BUS_INT1_v := "0000000010";
                               
                                end if;
                           
                            --TEST NEG
                            elsif (SC_v(21) = '1') then
                                -- 1 se (Acc) < 0
                                --  2 se (Acc) >= 0
                                if (Acc < "0000000000000000") then
                           
                                    BUS_INT1_v := "0000000001";
                               
                                else
                               
                                    BUS_INT1_v := "0000000010";
                               
                                end if;
                               
                            elsif (SC_v (22) = '1') then
                               
                                BUS_INT1_v := "000000" & IR(15 downto 12);
                           
                            else
                           
                                BUS_INT1_v := "00" & x"00";
                           
                            end if;
                           
                            if (SC_v (23) = '1') then
                               
                                BUS_INT2_v := MPC_v;
                           
                            elsif (SC_v (24) = '1') then
                               
                                BUS_INT2_v := SC(15 downto 6);
                                   
                            end if;
                           
                        -- antes da FASE 5 é necessario atualizar a 'ula' interna
                        BUS_INT3_v := BUs_INT1_v + BUS_INT2_v;
                           
                           
                -- FASE 5
                        when f_5    =>
                           
                            -- atualiza mpc com ula interna
                            MPC_v := BUS_INT3_v;
                           
                            if(SC_v (24) = '1') then
                                SC_v := MIC_MEM_v(to_integer(unsigned(MPC_v)));
                            end if;
                               
                end case;
               
             end if;   
               
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
             R1  <= R1_v;
             R2  <= R2_v;
             ACC <= ACC_v;
           
             -- signal auxiliar reset
             --reset_all <= reset_all_v;
   
             -- signal de controle principal
             SC <= SC_v;
             
             
            end process;
           
------------------------------------------------ DEBUG PROCESS ---
           
            display_segs1 <=    seg_nums(1) when MPC   =    "0000000000" else
           
                                                                    seg_nums(2) when  MPC   =   "0000000001" else
                                                                    seg_nums(3) when  MPC   =   "0000000010" else
                                                                    seg_nums(4) when  MPC   =   "0000000011" else
                                                                    seg_nums(5) when  MPC   =   "0000000100" else
                                                                    seg_nums(6) when  MPC   =   "0000000101" else
                                                                    seg_nums(7) when  MPC   =   "0000000110" else
                                                                    seg_nums(8) when  MPC   =   "0000000111" else
                                                                    seg_nums(9) when  MPC   =   "0000001000" else
                                                                    seg_nums(10) when MPC       =   "0000001001" else
                                                                    seg_nums(11) when MPC       =    "0000001010"else
                                                                    seg_nums(12) when MPC       =    "0000001011"else
                                                                    seg_nums(13) when MPC       =    "0000001100"else
                                                                    seg_nums(14) when MPC       =   "0000001101" else
                                                                    seg_nums(15) when MPC       =   "0000001110" else
                                                                    "1111110";
                                                                   
            display_segs2 <=    seg_nums(0) when PC   = "0000000000000000" else
           
                                                                    seg_nums(1) when  PC   =    "0000000000000001" else
                                                                    seg_nums(2) when  PC   =    "0000000000000010" else
                                                                    seg_nums(3) when  PC   =    "0000000000000011" else
                                                                    seg_nums(4) when  PC   =    "0000000000000100" else
                                                                    seg_nums(5) when  PC   =    "0000000000000101" else
                                                                    seg_nums(6) when  PC   =    "0000000000000110" else
                                                                    seg_nums(7) when  PC   =    "0000000000000111" else
                                                                    seg_nums(8) when  PC   =    "0000000000001000" else
                                                                    seg_nums(9) when  PC    =   "0000000000001001" else
                                                                    seg_nums(10) when PC    =   "0000000000001010"else
                                                                    seg_nums(11) when PC    =   "0000000000001011"else
                                                                    seg_nums(12) when PC    =   "0000000000001100"else
                                                                    seg_nums(13) when PC    =   "0000000000001101" else
                                                                    seg_nums(14) when PC    =   "0000000000001110" else
                                                                    "1111110";
                   
 
            display_segs3 <=    seg_nums(0) when ACC   =    "0000000000000000" else
           
                                                                    seg_nums(1) when  ACC   =   "0000000000000001" else
                                                                    seg_nums(2) when  ACC   =   "0000000000000010" else
                                                                    seg_nums(3) when  ACC   =   "0000000000000011" else
                                                                    seg_nums(4) when  ACC   =   "0000000000000100" else
                                                                    seg_nums(5) when  ACC   =   "0000000000000101" else
                                                                    seg_nums(6) when  ACC   =   "0000000000000110" else
                                                                    seg_nums(7) when  ACC   =   "0000000000000111" else
                                                                    seg_nums(8) when  ACC   =   "0000000000001000" else
                                                                    seg_nums(9) when  ACC       =   "0000000000001001" else
                                                                    seg_nums(10) when ACC       =    "0000000000001010"else
                                                                    seg_nums(11) when ACC       =    "0000000000001011"else
                                                                    seg_nums(12) when ACC       =    "0000000000001100"else
                                                                    seg_nums(13) when ACC       =   "0000000000001101" else
                                                                    seg_nums(14) when ACC       =   "0000000000001110" else
                                                                    "1111110";
                                                   
            display_segs4 <=    seg_nums(0) when PRIN_MEM(4) = "0000000000000000" else
           
                                                                    seg_nums(1) when  PRIN_MEM(4)   =   "1000000000000000" else
                                                                    seg_nums(2) when  PRIN_MEM(4)   =   "0100000000000000" else
                                                                    seg_nums(3) when  PRIN_MEM(4)   =   "1100000000000000" else
                                                                    seg_nums(4) when  PRIN_MEM(4)   =   "0010000000000000" else
                                                                    seg_nums(5) when  PRIN_MEM(4)   =   "1010000000000000" else
                                                                    "1111110"; 
display_segs5 <=    seg_nums(0) when BUS_ULA2  =    "0000000000000000" else
           
                                                                    seg_nums(1) when  BUS_ULA2   =  "0000000000000001" else
                                                                    seg_nums(2) when  BUS_ULA2   =  "0000000000000010" else
                                                                    seg_nums(3) when  BUS_ULA2   =  "0000000000000011" else
                                                                    seg_nums(4) when  BUS_ULA2   =  "0000000000000100" else
                                                                    seg_nums(5) when  BUS_ULA2   =  "0000000000000101" else
                                                                    seg_nums(6) when  BUS_ULA2  =   "0000000000000110" else
                                                                    seg_nums(7) when  BUS_ULA2   =  "0000000000000111" else
                                                                    seg_nums(8) when  BUS_ULA2   =  "0000000000001000" else
                                                                    seg_nums(9) when  BUS_ULA2      =   "0000000000001001" else
                                                                    seg_nums(10) when BUS_ULA2      =    "0000000000001010"else
                                                                    seg_nums(11) when BUS_ULA2      =    "0000000000001011"else
                                                                    seg_nums(12) when BUS_ULA2      =    "0000000000001100"else
                                                                    seg_nums(13) when BUS_ULA2      =   "0000000000001101" else
                                                                    seg_nums(14) when BUS_ULA2      =   "0000000000001110" else
                                                                    "1111110";         
           
---------------------------------------------------------------------                      
end behavior;