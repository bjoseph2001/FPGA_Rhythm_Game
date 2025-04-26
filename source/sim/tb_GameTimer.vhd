
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_GameTimer is
end tb_GameTimer;

architecture sim of tb_GameTimer is
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal enable       : std_logic := '0';
    signal frame_tick   : std_logic := '0';
    signal game_done    : std_logic;

begin

    uut: entity work.GameTimer
        port map (
            clk => clk,
            reset => reset,
            enable => enable,
            frame_tick => frame_tick,
            game_done => game_done
        );

    -- Clock generation
    clk_process: process
    begin
        while true loop
            clk <= not clk;
            wait for 5 ns;
        end loop;
    end process;

    -- Stimulus process
    stimulus: process
    begin
        wait for 20 ns;
        reset <= '0';
        wait for 30 ns;
        enable <= '1';

        -- Simulate periodic frame_tick pulses at 60Hz (every 16.67ms ~ 16670000ps)
        for i in 0 to 10 loop
            frame_tick <= '1';
            wait for 10 ns;
            frame_tick <= '0';
            wait for 166660 ns;  -- simulate 60 FPS rate
        end loop;

        wait;
    end process;

end sim;