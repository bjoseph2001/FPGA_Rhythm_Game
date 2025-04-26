library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_RhythmGameFSM is
end tb_RhythmGameFSM;

architecture sim of tb_RhythmGameFSM is
    signal clk         : std_logic := '0';
    signal reset       : std_logic := '1';
    signal start_btn   : std_logic := '0';
    signal playing     : std_logic;

begin

    uut: entity work.RhythmGameFSM
        port map (
            clk => clk,
            reset => reset,
            start_btn => start_btn,
            playing => playing
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
        wait for 50 ns;
        start_btn <= '1';
        wait for 20 ns;
        start_btn <= '0';
        wait;
    end process;

end sim;