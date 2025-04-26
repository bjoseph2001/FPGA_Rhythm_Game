library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_DisplayController is
end tb_DisplayController;

architecture sim of tb_DisplayController is
    constant NUM_NOTES     : integer := 16;

    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal frame_tick     : std_logic := '0';
    signal notes_y        : std_logic_vector(NUM_NOTES * 8 - 1 downto 0) := (others => '0');
    signal notes_lane     : std_logic_vector(NUM_NOTES * 2 - 1 downto 0) := (others => '0');
    signal notes_active   : std_logic_vector(NUM_NOTES - 1 downto 0) := (others => '0');

    signal spi_data       : std_logic_vector(95 downto 0);
    signal spi_send       : std_logic;
    signal spi_bytes      : integer range 1 to 12;
    signal spi_ready      : std_logic := '1';

begin

    uut: entity work.DisplayController
        port map (
            clk => clk,
            reset => reset,
            frame_tick => frame_tick,
            notes_y => notes_y,
            notes_lane => notes_lane,
            notes_active => notes_active,
            spi_data => spi_data,
            spi_send => spi_send,
            spi_bytes => spi_bytes,
            spi_ready => spi_ready
        );

    -- Clock generation
    clk_process: process
    begin
        while true loop
            clk <= not clk;
            wait for 5 ns;
        end loop;
    end process;

    -- SPI Ready simulation
    spi_ready_process: process(clk)
    begin
        if rising_edge(clk) then
            if spi_send = '1' then
                spi_ready <= '0'; -- SPI busy
            else
                spi_ready <= '1'; -- SPI ready
            end if;
        end if;
    end process;

    -- Stimulus process
    stimulus: process
    begin
        wait for 20 ns;
        reset <= '0';
        wait for 30 ns;

        -- ✅ Activate notes manually first
        notes_active(0) <= '1';
        notes_lane(1 downto 0) <= "00"; -- Lane 0
        notes_y(7 downto 0) <= std_logic_vector(to_unsigned(10, 8));

        notes_active(1) <= '1';
        notes_lane(3 downto 2) <= "01"; -- Lane 1
        notes_y(15 downto 8) <= std_logic_vector(to_unsigned(20, 8));

        notes_active(2) <= '1';
        notes_lane(5 downto 4) <= "10"; -- Lane 2
        notes_y(23 downto 16) <= std_logic_vector(to_unsigned(30, 8));

        wait for 30 ns;

        -- ✅ Now pulse frame_tick AFTER notes are valid
        frame_tick <= '1';
        wait for 10 ns;
        frame_tick <= '0';

        wait;
    end process;

end sim;