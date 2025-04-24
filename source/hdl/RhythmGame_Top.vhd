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
    reset_b   : in    std_logic;
    -- Buttons --
    btnc : in    std_logic;
    btnl : in    std_logic;
    btnr : in    std_logic;

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

  -- -- --Debug Signals --
  -- gamestate_out : out integer;
  -- spidata_out : out std_logic_vector(95 downto 0);
  -- NumberofBytes_out : out integer;
  -- blueindex_out : out integer;
  -- tempindexb_out : out integer;
  -- bluesquares_one_out : out std_logic_vector(95 downto 0);
  -- blue_reg_out : out std_logic_vector(7 downto 0);
  -- bluevector_out : out std_logic_vector(7 downto 0);

  -- CurrState : out unsigned(7 downto 0);
  -- delayDone : out std_logic
  );
end entity rhythmgame_top;

architecture behavioral of rhythmgame_top is

  signal spidata       : std_logic_vector(95 downto 0) := (others => '0');
  signal miso          : std_logic                     := '0'; -- Not used by the OLED module
  signal msgready      : std_logic                     := '0';
  signal numberofbytes : integer                       := 0;
  signal offdevice     : std_logic                     := '0';
  signal spiready      : std_logic                     := '0';
  signal sclk_s        : std_logic                     := '0';

  signal btnc_d : std_logic;
  signal btnl_d : std_logic;
  signal btnr_d : std_logic;

  type disp_array is array(7 downto 0) of std_logic_vector(3 downto 0);

  signal disp : disp_array := (x"0", x"1", x"0", x"0", x"C", x"1", x"0", x"0");

  -- Game Logic--

  type gamefsm is (
    init, breakstate, enablefill, clearscreen, clearscreen_buff, bluesq, redsq,
    greensq, updateindices, disablefill, outlinesql, outlinesqm, outlinesqr, waitforinput,
    gamedone
  );

  signal gamestate     : gamefsm := init;
  signal nextgamestate : gamefsm;

  signal gameready : std_logic := '0'; -- Game is ready for an update call

  signal mxcnt1ms_sclk   : integer   := (serial_clock / 5000);
  signal gamepulsemaxcnt : integer   := mxcnt1ms_sclk * 500; -- start with 500ms per Wait interval
  signal pulsegame       : std_logic := '0';
  signal game_enable     : std_logic := '0';

  type squarearray is array (0 to 2) of std_logic_vector(95 downto 0);

  signal bluevector  : std_logic_vector((game_len - 1) downto 0) := x"88";
  signal bluereg     : std_logic_vector((game_len - 1) downto 0) := (others => '0');
  signal bluesquares : squarearray                               := (others => (others => '0'));
  signal bluemsg     : std_logic_vector(95 downto 0)             := x"2201001D12FF0000FF000000";
  signal blueindex   : integer                                   := 0;
  -- signal tempindexb  : integer                       := 0;

  signal redvector  : std_logic_vector((game_len - 1) downto 0) := x"88";
  signal redreg     : std_logic_vector((game_len - 1) downto 0) := (others => '0');
  signal redsquares : squarearray                               := (others => (others => '0'));
  signal redmsg     : std_logic_vector(95 downto 0)             := x"2221003B1200FF0000FF0000";
  signal redindex   : integer                                   := 0;
  -- signal tempindexr : integer                       := 0;

  signal greenvector  : std_logic_vector((game_len - 1) downto 0) := x"88";
  signal greenreg     : std_logic_vector((game_len - 1) downto 0) := (others => '0');
  signal greensquares : squarearray                               := (others => (others => '0'));
  signal greenmsg     : std_logic_vector(95 downto 0)             := x"2240005D120000FF0000FF00";
  signal greenindex   : integer                                   := 0;
  -- signal tempindexg   : integer                       := 0;

  signal tempindex : integer := 0; -- to iterate through each square array

  signal counter : integer := 0;

-- --Debug signal --
-- signal logicstate : integer := 0;

begin

  -- --Debug assignments
  -- gamestate_out <= logicstate;
  -- spidata_out <= spidata;
  -- NumberofBytes_out <= numberofbytes;
  -- blueindex_out <= blueindex;
  -- tempindexb_out <= tempindexb;
  -- bluesquares_one_out <= bluesquares(0);
  -- blue_reg_out <= bluereg;
  -- bluevector_out <= bluevector;

  oled_spi : entity work.spi_master
    port map (
      clk           => clk100mhz,
      data_in       => spidata,
      reset         => reset_b,
      msgready      => msgready,
      numberofbytes => numberofbytes,
      offdevice     => offdevice,
      cs            => cs,
      mosi          => mosi,
      miso          => miso,
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

  game_pulse : entity work.pulsegeneratorfallingedge
    port map (
      clk      => sclk_s,
      reset    => reset_b,
      maxcount => to_unsigned(gamepulsemaxcnt, 27),
      pulseout => pulsegame,
      en       => game_enable
    );

  ----- Game Logic-------------
  -- The game starts with 3 square outlines at the bottom of the screen
  -- Squares of R, B, Y start to move down the screen to their respective
  -- outlines, when they cover the outline, the correct button must be pressed
  -- If done, percentage on 7 segment goes up. Start with 10 squares per game.
  -- If not pressed in time, square will continue off screen and no point awarded.
  -- When game finished, wait for a button press to restart.

  -- Implementing the squares:
  -- Have each column handle their own squares, should have a command
  -- that sets the square and then a subsequent command that removes it before
  -- moving it down
  -- Implement a delay so that multiple squares can show up in a row on the column

  game_logic : process (sclk_s, reset_b) is
  begin

    if (reset_b = '1') then
      gamestate <= init;
    elsif (falling_edge(sclk_s)) then

      case gamestate is

        when init =>

          gameready     <= '1';
          msgready      <= '0';
          numberofbytes <= 0;
          spidata       <= (others => '0');
          gamestate     <= enablefill;
          bluereg       <= bluevector;
          redreg        <= redvector;
          greenreg      <= greenvector;
          counter       <= 0;
          tempindex     <= 0;
        -- logicstate <= 1;

        when enablefill =>

          if (gameready = '1') then
            if (spiready = '1') then
              gameready     <= '0';
              spidata       <= x"260100000000000000000000";
              numberofbytes <= 2;
              msgready      <= '1';
              gamestate     <= breakstate;
              nextgamestate <= clearscreen;
            -- logicstate <= 2;
            end if;
          end if;

        when clearscreen =>

          if (spiready = '1') then
            spidata       <= x"2500005F3F00000000000000";
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= clearscreen_buff;
            -- logicstate <= 3;
            -- Reset all tempindex
            tempindex <= 0;
            if (counter mod 32 = 0) then
              -- shift all the registers by one
              bluereg  <= std_logic_vector(unsigned(bluereg) sll 1);
              redreg   <= std_logic_vector(unsigned(redreg) sll 1);
              greenreg <= std_logic_vector(unsigned(greenreg) sll 1);
            end if;
          end if;

        when clearscreen_buff =>

          gamestate <= bluesq;
        -- logicstate <= 4;

        when breakstate =>

          msgready <= '0';
          -- logicstate <= 30;
          if (spiready = '1') then
            gamestate <= nextgamestate;
          else
            gamestate <= breakstate;
          end if;

        when bluesq =>

          -- Check if there is enough space to fit a new square
          -- If TempindexB > 0 then don't need to add more squares
          -- logicstate <= 4;
          if (spiready = '1') then
            if (counter mod 32 = 0 and tempindex = 0) then
              -- Add new square to available space in array
              -- check if this is the first loop
              if (bluereg(7) = '1') then
                bluesquares(blueindex mod 3) <= bluemsg;
              else
                bluesquares(blueindex mod 3) <= (others => '0');
              end if;
            -- elsif (tempindex = 1) then
            --   -- increment blueindex to point to next available vector in squarearray
            --   blueindex <= blueindex + 1;
            end if;

            spidata       <= bluesquares(tempindex);
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= redsq;
            -- Move blue square down for next time
            bluesquares(tempindex) <= std_logic_vector(unsigned(bluesquares(tempindex)) + x"000001000100000000000000");
          end if;

        -- Display 1 square for each column at a time, iterate the previous squares column so no multiply
        -- driven nets. Keep looping between states until all squares are displayed (3 loops, 12 states total including BreakStates)
        when redsq =>

          -- logicstate <= 5;
          if (spiready = '1') then
            -- Check if there is enough space to fit a new square
            -- If TempindexR > 0 then don't need to add more squares
            if (counter mod 32 = 0 and tempindex = 0) then
              -- Add new square to available space in array
              -- check if this is the first loop
              if (redreg(7) = '1') then
                redsquares(redindex mod 3) <= redmsg;
              else
                redsquares(redindex mod 3) <= (others => '0');
              end if;
            -- elsif (tempindex = 1) then
            --   -- increment redindex to point to next available vector in squarearray
            --   redindex <= redindex + 1;
            end if;

            spidata       <= redsquares(tempindex);
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= greensq;
            -- Move red square down for next time
            redsquares(tempindex) <= std_logic_vector(unsigned(redsquares(tempindex)) + x"000001000100000000000000");
          end if;

        when greensq =>

          -- logicstate <= 6;
          if (spiready = '1') then
            -- Check if there is enough space to fit a new square
            -- If TempindexG > 0 then don't need to add more squares
            if (counter mod 32 = 0 and tempindex = 0) then
              -- Add new square to available space in array
              -- check if this is the first loop
              if (greenreg(7) = '1') then
                greensquares(greenindex mod 3) <= greenmsg;
              else
                greensquares(greenindex mod 3) <= (others => '0');
              end if;
            -- elsif (tempindex = 1) then
            --   -- increment greenindex to point to next available vector in squarearray
            --   greenindex <= greenindex + 1;
            end if;

            spidata       <= greensquares(tempindex);
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= updateindices;
            -- Move red square down for next time
            greensquares(tempindex) <= std_logic_vector(unsigned(greensquares(tempindex)) + x"000001000100000000000000");
          end if;

        when updateindices =>

          -- Update all indices for vectors and arrays here
          tempindex <= tempindex + 1;
          if(tempindex = 1) then
            blueindex <= blueindex + 1;
            redindex <= redindex + 1;
            greenindex <= greenindex + 1;
          end if;
          if (tempindex > 2) then
            -- displayed all squares, put outline squares back
            nextgamestate <= disablefill;
          else
            -- not done displaying all squares loop back
            nextgamestate <= bluesq;
          end if;

        when disablefill =>

          -- logicstate <= 7;
          if (spiready = '1') then
            spidata       <= x"260000000000000000000000";
            numberofbytes <= 2;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= outlinesql;
          end if;

        when outlinesql =>

          -- logicstate <= 8;
          counter <= counter + 1;                                                                                                          -- Squares have all been moved by 1
          if (spiready = '1') then
            spidata       <= x"22002B1E3FFFFFFFFFFFFF00";                                                                                  -- Leftmost Square
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= outlinesqm;
          end if;

        when outlinesqm =>

          -- logicstate <= 9;
          if (spiready = '1') then
            spidata       <= x"22202B3D3FFFFFFFFFFFFF00";                                                                                  -- Middle Square
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= outlinesqr;
          end if;

        when outlinesqr =>

          -- logicstate <= 10;
          if (spiready = '1') then
            spidata       <= x"223F2B5E3FFFFFFFFFFFFF00";                                                                                  -- Rightmost Square
            numberofbytes <= 11;
            msgready      <= '1';
            gamestate     <= breakstate;
            nextgamestate <= waitforinput;
          end if;

        when waitforinput =>

          -- logicstate <= 11;
          if ((500 - (50 * counter - 1)) >= 250) then
            gamepulsemaxcnt <= mxcnt1ms_sclk * (500 - (50 * counter - 1));                                                                 -- shorten delay for every loop
          else
            -- cap at 250ms since thats the time to debounce pushbuttons
            gamepulsemaxcnt <= mxcnt1ms_sclk * 250;
          end if;
          game_enable <= '1';
          if (pulsegame = '1') then
            if (counter / 32 > game_len) then
              gamestate <= gamedone;
            else
              gameready <= '1';
              gamestate <= clearscreen;
            end if;
          end if;

        when gamedone =>

          -- do nothing game is done
          gamestate <= gamedone;

      end case;

    end if;

  end process game_logic;

end architecture behavioral;
