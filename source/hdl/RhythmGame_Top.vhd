----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03/10/2025 09:32:25 PM
-- Design Name:
-- Module Name: RhythmGame_Top - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

  -- Uncomment the following library declaration if using
  -- arithmetic functions with Signed or Unsigned values
  use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity rhythmgame_top is
  generic (
    serial_clock : integer := 5000000;
    game_len     : integer := 8
  );
  port (
    clk100mhz : in    std_logic;
    -- Buttons --
    btnc    : in    std_logic;
    btnl    : in    std_logic;
    btnr    : in    std_logic;
    btnd    : in    std_logic; -- start button
    reset_b : in    std_logic;

    Off_Device : in std_logic; -- SW0

    -- 7 Segment Display--
    an        : out   std_logic_vector(7 downto 0);
    seg7_cath : out   std_logic_vector(7 downto 0);
    -- OLED Screen--
    cs         : out   std_logic;
    mosi       : out   std_logic;
    dat_cmd    : out   std_logic; -- Data/Command Bit 1 = Data. 0 = Command
    sclk       : out   std_logic; -- Minimum Period is 150ns
    oled_reset : out   std_logic;
    vcc_en     : out   std_logic;
    pmod_en    : out   std_logic

  );
end entity rhythmgame_top;

architecture behavioral of rhythmgame_top is

  signal spidata       : std_logic_vector(95 downto 0) := (others => '0');
  signal miso          : std_logic                     := '0'; -- Not used by the OLED module
  signal msgready      : std_logic                     := '0';
  signal numberofbytes : integer                       := 0;
  signal spiready      : std_logic                     := '0';
  signal sclk_s        : std_logic                     := '0';

  signal btnl_d       : std_logic;
  signal btnc_d       : std_logic;
  signal btnr_d       : std_logic;
  signal start_button : std_logic;

  signal button_lane  : std_logic_vector(1 downto 0) := "00";
  signal button_click : std_logic;

  type disp_array is array(7 downto 0) of std_logic_vector(3 downto 0);

  signal disp : disp_array := (x"F", x"0", x"0", x"0", x"C", x"0", x"0", x"0");
  signal score : integer := 0;
  signal high_score : integer := 0;

  -- FSM control
  signal start_game : std_logic;
  signal playing    : std_logic;
  signal show_score : std_logic;
  signal game_done  : std_logic;

  -- Note data
  signal notes_y      : std_logic_vector(127 downto 0); -- 16 * 8
  signal notes_lane   : std_logic_vector(31 downto 0);  -- 16 * 2
  signal notes_active : std_logic_vector( 15 downto 0); -- 16

  -- Hit signal
  signal hit           : std_logic;
  signal hit_note_mask : std_logic_vector(15 downto 0);

  -- Game Timer
  signal frame_tick : std_logic := '0';

begin

  oled_spi : entity work.spi_master
    generic map (
      fpga_clock => 100000000
    )
    port map (
      clk           => clk100mhz,
      data_in       => spidata,
      reset         => reset_b,
      msgready      => msgready,
      numberofbytes => numberofbytes,
      offdevice     => Off_Device,
      cs            => cs,
      mosi          => mosi,
      miso          => '0',
      sclk          => sclk,
      sclk_sig      => sclk_s,
      data_command  => dat_cmd,
      pmodenable    => pmod_en,
      vccenable     => vcc_en,
      slavereset    => oled_reset,
      spiready      => spiready
    -- p_CurrState   => CurrState,
    -- p_delayDone   => delayDone
    );

  debounce_c : entity work.debounce
    port map (
      btni => btnc,
      btno => btnc_d,
      clk  => clk100mhz
    );

  debounce_l : entity work.debounce
    port map (
      btni => btnl,
      btno => btnl_d,
      clk  => clk100mhz
    );

  debounce_r : entity work.debounce
    port map (
      btni => btnr,
      btno => btnr_d,
      clk  => clk100mhz
    );

  debounce_start : entity work.debounce
    port map (
      btni => btnd,
      btno => start_button,
      clk  => clk100mhz
    );

  seg7_disp : entity work.seg7_controller
    port map (
      clk100    => clk100mhz,
      rst       => reset_b,
      char0     => disp(0),
      char1     => disp(1),
      char2     => disp(2),
      char3     => disp(3),
      char4     => disp(4),
      char5     => disp(5),
      char6     => disp(6),
      char7     => disp(7),
      an        => an,
      seg7_cath => seg7_cath
    );

--Update score when a hit is made
  process(clk100mhz,reset_b)
  begin
    if(reset_b = '1') then
      score <= 0;
      high_score <= 0;
    elsif(rising_edge(clk100mhz)) then
      if(playing = '1' and hit = '1') then
        --if hit was made during a game, iterate score
        score <= score + 1;
      elsif(show_score = '1') then
        if(score > high_score) then
            --if score is higher than high score, update high score
            high_score <= score;
        end if;
      elsif(start_game = '1') then
        score <= 0;
      end if;
    end if;
  end process;
  
  --Display Current Score
  disp(2) <= std_logic_vector(to_unsigned((score/100),4));
  disp(1) <= std_logic_vector(to_unsigned(((score mod 100)/10),4));
  disp(0) <= std_logic_vector(to_unsigned(((score mod 100) mod 10),4));
  
  --Display High Score
  disp(6) <= std_logic_vector(to_unsigned((high_score/100),4));
  disp(5) <= std_logic_vector(to_unsigned(((high_score mod 100)/10),4));
  disp(4) <= std_logic_vector(to_unsigned(((high_score mod 100) mod 10),4));


  -- Game Timer
  timer_inst : entity work.gametimer
    port map (
      clk        => clk100mhz,
      reset      => reset_b,
      enable     => playing,
      start_game => start_game,
      frame_tick => frame_tick,
      game_done  => game_done
    );

  -- Display Controller
  display_inst : entity work.displaycontroller
    port map (
      clk          => clk100mhz,
      reset        => reset_b,
      frame_tick   => frame_tick,
      notes_y      => notes_y,
      notes_lane   => notes_lane,
      notes_active => notes_active,
      spi_data     => spidata,
      spi_send     => msgready,
      spi_bytes    => numberofbytes,
      spi_ready    => spiready
    );

  -- Hit Detection
  hit_inst : entity work.hitdetector
    generic map (
      num_notes => 16,
      hit_min   => 54,
      hit_max   => 64
    )
    port map (
      clk           => clk100mhz,
      reset         => reset_b,
      button_lane   => button_lane,
      button_click  => button_click,
      notes_y       => notes_y,
      notes_lane    => notes_lane,
      notes_active  => notes_active,
      hit           => hit,
      hit_note_mask => hit_note_mask
    );

  -- Note Movement --
  notes_inst : entity work.notecontroller
    generic map (
      num_notes     => 16,
      screen_height => 64
    )
    port map (
      clk           => clk100mhz,
      reset         => reset_b,
      frame_tick    => frame_tick,
      start         => start_game,
      enable        => playing,
      hit_note_mask => hit_note_mask,
      notes_y       => notes_y,
      notes_lane    => notes_lane,
      notes_active  => notes_active
    );

  -- Game FSM --
  game_inst : entity work.rhythmgamefsm
    port map (
      clk          => clk100mhz,
      reset        => reset_b,
      start_button => start_button,
      game_done    => game_done,
      start_game   => start_game,
      playing      => playing,
      show_score   => show_score
    );

  -- Frame Tick Generator--
  frame_inst : entity work.framedivider
    generic map (
      clock_freq_hz => 100000000,
      frame_rate_hz => 60
    )
    port map (
      clk        => clk100mhz,
      reset      => reset_b,
      frame_tick => frame_tick
    );

  button_mapping : process (clk100mhz, reset_b) is
  begin

    if (reset_b = '1') then
      button_lane  <= "00";
      button_click <= '0';
    elsif (rising_edge(clk100mhz)) then
      -- Priority encoder: left most button takes priority
      if (btnl_d = '1') then
        button_lane  <= "00";
        button_click <= '1';
      elsif (btnc_d = '1') then
        button_lane  <= "01";
        button_click <= '1';
      elsif (btnr_d = '1') then
        button_lane  <= "10";
        button_click <= '1';
      else
        button_click <= '0';
      end if;
    end if;

  end process button_mapping;



end architecture behavioral;
