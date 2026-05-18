--Autor: Jakub Szymanek 277673
--Sterownik windy w 5-pietrowym budynku
--Pt. 15:45
--26.01.2026r.
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

 
ENTITY WindaTest IS
END WindaTest;
 
ARCHITECTURE behavior OF WindaTest IS 
  
    COMPONENT Winda
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
         floor_req : IN  std_logic_vector(4 downto 0);
         open_btn : IN  std_logic;
         close_btn : IN  std_logic;
         alarm : IN  std_logic;
         error : IN  std_logic;
         cur_floor : OUT  std_logic_vector(2 downto 0);
         motor_on : OUT  std_logic;
         motor_dir : OUT  std_logic;
         door_state : OUT  std_logic;
         display : OUT  std_logic;
		   alarm_led  : out std_logic;
         error_led  : out std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal floor_req : std_logic_vector(4 downto 0) := (others => '0');
   signal open_btn : std_logic := '0';
   signal close_btn : std_logic := '0';
   signal alarm : std_logic := '0';
   signal error : std_logic := '0';
	signal floor_reached : std_logic := '0';

 	--Outputs
   signal cur_floor : std_logic_vector(2 downto 0);
   signal motor_on : std_logic;
   signal motor_dir : std_logic;
   signal door_state : std_logic;
   signal display : std_logic;
	signal alarm_led : std_logic;
	signal error_led : std_logic;
   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Winda PORT MAP (
          clk => clk,
          reset => reset,
          floor_req => floor_req,
          open_btn => open_btn,
          close_btn => close_btn,
          alarm => alarm,
          error => error,
          cur_floor => cur_floor,
          motor_on => motor_on,
          motor_dir => motor_dir,
          door_state => door_state,
          display=> display,
			 alarm_led => alarm_led,
			 error_led => error_led
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin	


		-- Reset sterownika
        reset <= '1';
        wait for clk_period *1.3;
        reset <= '0';
        wait for clk_period * 5;
--TEST JAZDA GORA-DOL 
        -- wezwanie na 4 piętro
        floor_req <= "10000"; -- Przycisk 4 
        wait for clk_period * 2;
        floor_req <= "00000"; -- puszczenie przycisku

        -- W międzyczasie (gdy winda mija 1 piętro) ktos wzywa piętro 2
        wait until cur_floor = "001";
        floor_req <= "00100"; -- Przycisk 2 
        wait for clk_period * 2;
        floor_req <= "00000";     
		  
        wait until cur_floor = "100";
		  
        -- Na 4 piętrze ktoś klika PARTER (0)
        wait for clk_period * 5;
        floor_req <= "00001"; -- Przycisk 0 
        wait for clk_period * 2;
        floor_req <= "00000";

        -- Winda na 3 piętrze (jedzie w dol) i ktoś wzywa windę na 4 piętro
        wait until cur_floor = "011";
        floor_req <= "10000"; -- Przycisk 4
        wait for clk_period * 2;
        floor_req <= "00000";
        
        wait until cur_floor = "100";

--TEST JAZDA GORA i AWARIA
		
		-- wezwanie na 4 piętro
--		  floor_req <= "10000"; 
--        wait for clk_period * 2;
--        floor_req <= "00000";
--		  
--		  wait until cur_floor = "010";
--		  
--		  error <= '1';
--		  
--		  wait for clk_period * 10;
--		  
--		  reset <= '1';
--		  wait for clk_period;
--		  reset <= '0';
--		  
--		  wait for clk_period * 5;
--		  
--		  error <= '0';
--		  reset <= '1';
--		  wait for clk_period;
--		  reset <= '0';
--		  
--		  wait for clk_period *3;

--- TEST ALARM PODCZAS JAZDY

		 --wezwanie na 4 piętro
--		  floor_req <= "10000"; 
--      wait for clk_period * 2;
--      floor_req <= "00000";
--		  
--		  wait until cur_floor = "010";
--		  
--		  wait for clk_period * 2;
--		  
--		  alarm <= '1';
--		  
--		  wait for clk_period * 10;
--		  
--		  alarm <= '0';
--		  
--		  wait for clk_period *3;

-- TEST DZIALANIA PRZYCISKOW OD DRZWI
--		  open_btn <= '1';
--        wait for clk_period;
--        open_btn <= '0';
--		  
--		  wait for clk_period * 4;
--		  floor_req <= "01000";
--		  wait for clk_period;
--		  floor_req <= "00000";
--		  
--		  wait for clk_period *2;
--		  close_btn <= '1';
--		  wait for clk_period;
--		  close_btn <= '0';
--
--		  wait for clk_period * 3;
--		  
--
--		  
--		  wait for clk_period * 6;
--		  
--		  open_btn <= '1';
--        wait for clk_period;
--        open_btn <= '0';
--		  
--		  wait for clk_period * 12;
	
        wait for 200 ns;
        assert false report "Koniec symulacji" severity failure;
		
    end process;

END;
