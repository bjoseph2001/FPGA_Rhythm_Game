-- Testbench for DisplayController (Tb_DisplayController)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Tb_DisplayController is
end entity Tb_DisplayController;

architecture Behavioral of Tb_DisplayController is
    -- Component under test
    component displaycontroller is
      port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        frame_tick   : in  std_logic;
        notes_y      : in  std_logic_vector(127 downto 0);
        notes_lane   : in  std_logic_vector(31 downto 0);
        notes_active : in  std_logic_vector(15 downto 0);
        spi_data     : out std_logic_vector(95 downto 0);
        spi_send     : out std_logic;
        spi_bytes    : out integer range 1 to 12;
        spi_ready    : in  std_logic
      );
    end component;

    -- Testbench signals
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal frame_tick : std_logic := '0';

    signal notes_y      : std_logic_vector(127 downto 0) := (others => '0');
    signal notes_lane   : std_logic_vector(31 downto 0)  := (others => '0');
    signal notes_active : std_logic_vector(15 downto 0)  := (others => '0');

    signal spi_data  : std_logic_vector(95 downto 0);
    signal spi_send  : std_logic;
    signal spi_bytes : integer range 1 to 12;
    signal spi_ready : std_logic := '1';

    signal frm_count : integer := 0;

    constant CLK_PERIOD   : time := 10 ns;        -- 100 MHz clock
    constant FRAME_CYCLES : integer := 80;        -- shortened frame interval

    -- Expected values for note in lane 1 at y=10
    constant EXP_LANE       : integer := 1;
    constant EXP_Y          : integer := 10;
    constant EXP_X1         : integer := EXP_LANE*32 + 2;
    constant EXP_X2         : integer := (EXP_LANE+1)*32 - 2;
    constant EXP_Y2         : integer := EXP_Y + 6;
    constant EXP_COLOR_SL   : std_logic_vector(23 downto 0) := x"1F0000";
    constant EXP_COLOR_INT  : integer := to_integer(unsigned(EXP_COLOR_SL));
begin
    -- Instantiate DUT
    uut: displaycontroller
      port map (
        clk          => clk,
        reset        => reset,
        frame_tick   => frame_tick,
        notes_y      => notes_y,
        notes_lane   => notes_lane,
        notes_active => notes_active,
        spi_data     => spi_data,
        spi_send     => spi_send,
        spi_bytes    => spi_bytes,
        spi_ready    => spi_ready
      );

    -- Clock generation
    clk_process: process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- SPI handshake: when DUT asserts spi_send, deassert spi_ready next cycle
    handshake: process(clk)
    begin
        if rising_edge(clk) then
            if spi_send = '1' then
                spi_ready <= '0';
            else
                spi_ready <= '1';
            end if;
        end if;
    end process;

    -- Monitor and automatic checks
    monitor_proc: process(clk)
        variable x1, y1, x2, y2 : integer;
        variable color_int      : integer;
    begin
        if rising_edge(clk) then
            if spi_send = '1' then
                -- extract fields from spi_data
                x1 := to_integer(unsigned(spi_data(87 downto 80)));
                y1 := to_integer(unsigned(spi_data(79 downto 72)));
                x2 := to_integer(unsigned(spi_data(71 downto 64)));
                y2 := to_integer(unsigned(spi_data(63 downto 56)));
                color_int := to_integer(unsigned(spi_data(55 downto 32)));
                report "[SPI SEND] bytes=" & integer'image(spi_bytes) &
                       " x1=" & integer'image(x1) &
                       " y1=" & integer'image(y1) &
                       " x2=" & integer'image(x2) &
                       " y2=" & integer'image(y2) &
                       " color=" & integer'image(color_int);
                -- Geometry check
                assert x1 = EXP_X1 and y1 = EXP_Y and x2 = EXP_X2 and y2 = EXP_Y2
                  report "NOTE geometry mismatch!" severity error;
                -- Color check
                assert color_int = EXP_COLOR_INT
                  report "NOTE color mismatch!" severity error;
            elsif frame_tick = '1' then
                report "FRAME_TICK: " & integer'image(frm_count);
                frm_count <= frm_count + 1;
            end if;
        end if;
    end process;

    -- Stimulus
    stim_proc: process
    begin
        -- release reset
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;

        -- drive one active note in lane 1 at y=10
        notes_active <= (others => '0');
        notes_active(1) <= '1';
        notes_lane(15*2+1 downto 15*2) <= std_logic_vector(to_unsigned(EXP_LANE,2));
        notes_y(15*8+7 downto 15*8) <= std_logic_vector(to_unsigned(EXP_Y,8));

        -- generate two frames
        for i in 1 to 2 loop
            wait for FRAME_CYCLES * CLK_PERIOD;
            frame_tick <= '1';
            wait for CLK_PERIOD;
            frame_tick <= '0';
        end loop;

        wait for 200 ns;
        report "TEST COMPLETED";
        wait;
    end process;

end architecture Behavioral;
