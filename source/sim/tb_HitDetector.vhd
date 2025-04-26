library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_HitDetector is
end tb_HitDetector;

architecture sim of tb_HitDetector is
    signal clk           : std_logic := '0';
    signal reset         : std_logic := '1';
    signal button_lane   : std_logic_vector(2 downto 0) := (others => '0');
    signal button_click  : std_logic_vector(2 downto 0) := (others => '0');
    signal notes_y       : std_logic_vector(127 downto 0) := (others => '0');
    signal notes_lane    : std_logic_vector(31 downto 0) := (others => '0');
    signal notes_active  : std_logic_vector(15 downto 0) := (others => '0');

begin

    uut: entity work.HitDetector
        port map (
            clk => clk,
            reset => reset,
            button_lane => button_lane,
            button_click => button_click,
            notes_y => notes_y,
            notes_lane => notes_lane,
            notes_active => notes_active
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
        button_click(0) <= '1';
        wait for 10 ns;
        button_click(0) <= '0';
        wait;
    end process;

end sim;