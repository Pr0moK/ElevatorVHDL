--Autor: Jakub Szymanek 277673
--Sterownik windy w 5-pietrowym budynku
--Pt. 15:45
--26.01.2026r.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use std.textio.all;
use IEEE.std_logic_textio.all;

entity Winda is
    port (
		  -- Wejscia
        clk, reset : in std_logic; -- reset i zegar
        floor_req  : in std_logic_vector(4 downto 0); -- Przyciski (0-4)
        open_btn   : in std_logic; -- przycisk otwierania drzwi
		  close_btn   : in std_logic; -- przycisk zamykania drzwi
        alarm      : in std_logic; -- wejscie alarmu
        error      : in std_logic; -- wejscie od czujnika; blad mechaniczny windy
        -- Wyjscia
        cur_floor  : out std_logic_vector(2 downto 0); -- aktualne pietro
        motor_on   : out std_logic; -- silnik 1=wlaczony 0=wylaczony
        motor_dir  : out std_logic; -- 1 = gora, 0 = dol
        door_state : out std_logic; -- drzwi 1 = otwarte 0 = zamkniete
        display : out std_logic; -- wyswietlanie na wyswietlaczu 1 = wlaczone , 0 = wylaczone
		  alarm_led  : out std_logic; -- zasilanie led od alarmu
        error_led  : out std_logic -- zasilanie led od awarii
    );
end Winda;

architecture Behavioral of Winda is

type STANY is (IDLE, DECIDE, GO_UP, GO_DOWN, OPEN_DOOR, WAIT_DOOR, CLOSE_DOOR, ALARM_S, ERROR_S);
signal stan, next_stan : STANY;

-- Sygnaly wewnetrzne
signal floor_reg    : std_logic_vector(2 downto 0) := (others => '0'); --  Rejestr aktualnego pietra
signal req_reg      : std_logic_vector(4 downto 0) := (others => '0'); --  Rejestr zatrzasnietych pieter
signal target_floor : std_logic_vector(2 downto 0) := (others => '0'); --  Rejestr pietro docelowe
signal move_cnt     : std_logic_vector(2 downto 0) := (others => '0'); -- licznik czasu jazdy windy
signal door_timer   : std_logic_vector(3 downto 0) := (others => '0'); -- licznik czasu otwarcia drzwi
signal floor_reached : std_logic := '0'; -- sprawdzanie czy osiagnieto pietro 

begin

    cur_floor <= floor_reg; -- przypisanie aktualnego pietra do wyjscia

	 
	wyswietlacz: process(clk)
		file display : text open write_mode is out "winda_display.txt"; -- plik wyjsciowy
		variable linia : line; -- buffor lini
		variable pietro : integer; -- pietra jako liczba
	 begin
		if(clk'event and clk='1') then
			pietro := conv_integer(floor_reg);
			writeline(display, linia);
		   if stan = GO_UP then
            write(linia, string'("  ^  "));
         elsif stan = GO_DOWN then
            write(linia, string'("  v  "));
         elsif stan = ALARM_S then
            write(linia, string'(" ALARM "));
         elsif stan = ERROR_S then
            write(linia, string'(" AWARIA"));
         else
            write(linia, string'("     "));
         end if;
			
			write(linia, pietro);	
		end if;
	end process wyswietlacz;
	 
   rejestry: process(clk, reset)
    begin
        if reset = '1' then
            stan <= IDLE;                          -- Poczatkowy stan: bezczynnosc
            floor_reg <= (others => '0');          -- Poczatkowe pietro parter (0)
            req_reg <= (others => '0');            -- Brak zadan pieter
            target_floor <= (others => '0');       -- Brak docelowego pietra
            move_cnt <= (others => '0');           -- Licznik ruchu wyzerowany
            door_timer <= (others => '0');         -- Licznik drzwi wyzerowany
            floor_reached <= '0';                  -- Osiagniecie pietra wyzerowane
        elsif (clk'event and clk ='1') then
            stan <= next_stan;	-- aktualizacja stanu			
				floor_reached <= '0'; -- wyzerowanie domysle dla osiagniecia pietra

            
				if stan /= ERROR_S then
					req_reg <= req_reg or floor_req; -- zatrzaskiwanie zadanego pietra
				end if;

            -- Kasowanie zadania po otwarciu drzwi
            if stan = OPEN_DOOR then
                case floor_reg is
                    when "000" => req_reg(0) <= '0'; -- parter
                    when "001" => req_reg(1) <= '0'; -- 1 pietro
                    when "010" => req_reg(2) <= '0'; -- 2 pietro
                    when "011" => req_reg(3) <= '0'; -- 3 pietro
                    when "100" => req_reg(4) <= '0'; -- 4 pietro
                    when others => null;
                end case;
            end if;
				-- Wybieranie zadanego pietra i priorytet pieter
				if stan = DECIDE then
                if req_reg(4) = '1' then target_floor <= "100"; -- pietro 4
						elsif req_reg(3) = '1' then target_floor <= "011"; 
						elsif req_reg(2) = '1' then target_floor <= "010";
						elsif req_reg(1) = '1' then target_floor <= "001";
						elsif req_reg(0) = '1' then target_floor <= "000"; -- parter
                end if;
            end if;
            -- Licznik przemieszczenia 
				if stan = GO_UP or stan = GO_DOWN then
					 if move_cnt = "101" then -- 6 taktow
						  move_cnt <= (others => '0'); -- zerowanie licznika 
						  floor_reached <= '1'; -- sygnal o osiagneciu pietra
						  if stan = GO_UP then 
								floor_reg <= floor_reg + 1; -- jazda w gore, inkrementacja pietra
						  else
								floor_reg <= floor_reg - 1; -- jazda w dol, dekrementacja pietra
						  end if;
					 else
						  move_cnt <= move_cnt + 1; -- inkrementuj licznik
					 end if;
				elsif stan = OPEN_DOOR or reset = '1' then
					 move_cnt <= (others => '0'); -- zeruj przy otwarciu drzwi badz resecie
				end if;

            -- Licznik czasu otwarcia drzwi
            if stan = WAIT_DOOR then
                door_timer <= door_timer + 1;
            else
                door_timer <= (others => '0');
            end if;
        end if;
    end process rejestry;

    -- Logika przejsc
    process(stan, floor_reg, req_reg, target_floor, move_cnt, door_timer, alarm, error, open_btn,close_btn,floor_reached)
    begin
        next_stan  <= stan;       -- Domyslnie pozostan w aktualnym stanie
        motor_on   <= '0';        -- Silnik wylaczony
        motor_dir  <= '0';        -- Kierunek: dol (nieistotny gdy silnik wylaczony)
        door_state <= '0';        -- Drzwi zamkniete
        display    <= '1';        -- Wyswietlacz wlaczony
        alarm_led  <= '0';        -- LED alarmu wylaczony
        error_led  <= '0';        -- LED awarii wylaczony
		  
        case stan is
		  
            when IDLE => -- oczekuje w miejscu na zadania pieter lub obslugi drzwi/awarii/alarmu
					 display <= '0';
                if error = '1' then
						next_stan <= ERROR_S;
                elsif alarm = '1' then
						next_stan <= ALARM_S;
                elsif req_reg /= "00000" then 
						next_stan <= DECIDE;
                elsif open_btn = '1' then
						next_stan <= OPEN_DOOR;
                end if;

			when DECIDE => -- Decyzja o kierunku jazdy windy
				 if error = '1' then
					  next_stan <= ERROR_S;
				 elsif alarm = '1' then
					  next_stan <= ALARM_S;
				 else
					  if (floor_reg < "100" and req_reg(4) = '1') or -- sprawdzanie czy mamy zadania powyzej aktualnego pietra
						  (floor_reg < "011" and req_reg(3) = '1') or
						  (floor_reg < "010" and req_reg(2) = '1') or
						  (floor_reg < "001" and req_reg(1) = '1') then
							next_stan <= GO_UP; -- jazda do gory
					  elsif (floor_reg > "000" and req_reg(0) = '1') or -- sprawdzanie czy mamy zadania pieter ponizej aktualnego
							  (floor_reg > "001" and req_reg(1) = '1') or
							  (floor_reg > "010" and req_reg(2) = '1') or
							  (floor_reg > "011" and req_reg(3) = '1') then
							next_stan <= GO_DOWN; -- jazda w dol
					  else
							next_stan <= OPEN_DOOR; -- jak jestesmy na tym pietrze to otworz drzwi
					  end if;
				 end if;

            when GO_UP => -- stan obslugujacy jazde do gory
				    if error = '1' then
						next_stan <= Error_S;
                elsif alarm = '1' then
						next_stan <= ALARM_S;
					 else
						motor_on <= '1'; -- wlacz silnik
						motor_dir <= '1'; -- kierunek gora
						
						if floor_reached = '1' then -- sprawdz czy osiagnelismy pietro
							if floor_reg = target_floor then -- sprawdz czy jest to pietro docelowe
								next_stan <= OPEN_DOOR; -- otworz drzwi
						elsif (floor_reg = "001" and req_reg(1) = '1') or -- sprawdzanie czy na aktualnym pietrze bylo jakies zadanie jesli tak to otworz drzwi
								(floor_reg = "010" and req_reg(2) = '1') or
								(floor_reg = "011" and req_reg(3) = '1') or
								(floor_reg = "100" and req_reg(4) = '1') then
								next_stan <= OPEN_DOOR;
							end if;
						end if;
                end if;

            when GO_DOWN =>
				    if error = '1' then
						next_stan <= Error_S;
                elsif alarm = '1' then
						next_stan <= ALARM_S;
					 else
						motor_on <= '1'; -- wlacz silnik
						motor_dir <= '0'; -- kierunek dol
						if floor_reached = '1' then
							if floor_reg = target_floor then -- sprawdz czy jest to pietro docelowe
								next_stan <= OPEN_DOOR;
							elsif (floor_reg = "000" and req_reg(0) = '1') or -- sprawdzanie czy na aktualnym pietrze bylo jakies zadanie jesli tak to otworz drzwi
									(floor_reg = "001" and req_reg(1) = '1') or
									(floor_reg = "010" and req_reg(2) = '1') or
									(floor_reg = "011" and req_reg(3) = '1') then
									next_stan <= OPEN_DOOR;
								end if;
                    end if;
                end if;

            when OPEN_DOOR =>
				    if error = '1' then 
						next_stan <= Error_S;
                elsif alarm = '1' then 
						next_stan <= ALARM_S;
					 else
						door_state <= '1'; -- drzwi otwarte
						next_stan <= WAIT_DOOR; -- przejscie do oczekiwania na zamkniecie
					 end if;

            when WAIT_DOOR => -- drzwi otwarte oczekuja na zamkniecie guzikiem/automatycznie
				    if error = '1' then
						next_stan <= Error_S;
                elsif alarm = '1' then
						next_stan <= ALARM_S;
					 else
						door_state <= '1';
						if close_btn = '1' then -- warunki zamkniecia drzwi              
							next_stan <= CLOSE_DOOR;
						elsif door_timer = "1010" then -- automatyczne zamkniecie
							next_stan <= CLOSE_DOOR;
						elsif open_btn = '1' then -- przedluzenie zamykania drzwi
							next_stan <= OPEN_DOOR;
						end if;
					end if;

            when CLOSE_DOOR => -- stan przejsciowy decyzja czy idle czy wybor kierunku
				    if error = '1' then
						next_stan <= Error_S;
                elsif alarm = '1' then
						next_stan <= ALARM_S;
					 else
						if req_reg /= "00000" then -- jesli kolejne zadania to wybor kierunku
							next_stan <= DECIDE;
						else
							next_stan <= IDLE; -- brak zadan to idle
						end if;
					end if;

            when ALARM_S =>
					 alarm_led <= '1'; -- zapalenie LED
					 door_state <= '1'; -- otwarcie drzwi
					 motor_on <= '0'; -- wylacz silnik
                if alarm = '0' then -- jesli alarm wylaczony to przejdz do idle
						next_stan <= IDLE; 
					 end if;
					 
				when Error_S =>
					error_led <= '1'; -- zapalenie led
					motor_on <= '0'; -- wylacz silnik
					if reset = '1' and error = '0' then -- oczekiwanie na reset i usuniecie awarii.
						next_stan <= Idle;
					end if;

            when others =>
					next_stan <= IDLE;
        end case;
    end process;

end Behavioral;