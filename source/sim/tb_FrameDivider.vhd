library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity tb_FrameDivider is
end tb_FrameDivider;

architecture sim of tb_FrameDivider is
    signal clk_in    : std_logic := '0';
    signal reset     : std_logic := '1';
    signal clk_out   : std_logic;

begin

    uut: entity work.FrameDivider
        port map (
            clk => clk_in,
            reset => reset,
            frame_tick => clk_out
        );

    -- Clock generation
    clk_process: process
    begin
        while true loop
            clk_in <= not clk_in;
            wait for 5 ns;
        end loop;
    end process;

    -- Stimulus process
    stimulus: process
    begin
        wait for 20 ns;
        reset <= '0';
        wait;
    end process;

end sim;