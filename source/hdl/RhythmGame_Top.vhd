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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RhythmGame_Top is
  Port (
        CLK100MHZ : in STD_LOGIC;
        RESET_B : in STD_LOGIC;
        --Buttons --
        BTNC : in STD_LOGIC;
        BTNL : in STD_LOGIC;
        BTNR : in STD_LOGIC;
        
        --7 Segment Display--
        AN : out STD_LOGIC_VECTOR (7 downto 0);
        SEG7_CATH : out STD_LOGIC_VECTOR(7 downto 0);
        --OLED Screen--       
        CS : out STD_LOGIC;
        MOSI : out STD_LOGIC;
        DAT_CMD : out STD_LOGIC; --Data/Command Bit 1 = Data. 0 = Command
        SCLK : out STD_LOGIC; -- Minimum Period is 150ns
        OLED_RESET : out STD_LOGIC;
        VCC_EN : out STD_LOGIC;
        PMOD_EN : out STD_LOGIC
   );
end RhythmGame_Top;

architecture Behavioral of RhythmGame_Top is

  signal SPIdata: STD_LOGIC_VECTOR(95 downto 0) := (others=>'0');
  signal MISO: STD_LOGIC := '0'; --Not used by the OLED module
  signal msgReady : STD_LOGIC := '0';
  signal NumberofBytes : integer := 0;
  signal OffDevice : STD_LOGIC := '0';
  signal SPIReady : STD_LOGIC := '0';
  signal SCLK_s : STD_LOGIC := '0';

  signal BTNC_d : STD_LOGIC;
  signal BTNL_d : STD_LOGIC;
  signal BTNR_d : STD_LOGIC; 

  type disp_array is array(7 downto 0) of STD_LOGIC_VECTOR(3 downto 0);
  signal disp : disp_array:= (x"0",x"1",x"0",x"0",x"C",x"1",x"0",x"0");

  --Game Logic--
  signal OutlineMade : STD_LOGIC := '0';
  signal OutlineSq : unsigned (1 downto 0):= "00";

begin

  OLED_SPI : entity work.SPI_master port map(
      CLK => CLK100MHZ,
      Data_in => SPIdata,
      Reset => RESET_B,
      msgReady => msgReady,
      NumberofBytes => NumberofBytes,
      OffDevice => OffDevice,
      CS => CS,
      MOSI => MOSI,
      MISO => MISO,
      SCLK => SCLK,
      SCLK_sig => SCLK_s,
      Data_Command => DAT_CMD,
      PMODEnable => PMOD_EN,
      VCCEnable => VCC_EN,
      SlaveReset => OLED_RESET,
      SPIReady => SPIReady
  );

  Debounce_C : entity work.Debounce port map(
    BTNI => BTNC,
    BTNO => BTNC_d,
    CLK=> CLK100MHZ
  );

  Debounce_L : entity work.Debounce port map(
      BTNI => BTNL,
      BTNO => BTNL_d,
      CLK=> CLK100MHZ
  );

  Debounce_R : entity work.Debounce port map(
    BTNI => BTNR,
    BTNO => BTNR_d,
    CLK=> CLK100MHZ
  );

  Seg7_Disp : entity work.seg7_controller port map(
    clk100 => CLK100MHZ,
    rst => RESET_B,
    char0 => disp(0),
    char1 => disp(1),
    char2 => disp(2),
    char3 => disp(3), 
    char4 => disp(4), 
    char5 => disp(5), 
    char6 => disp(6), 
    char7 => disp(7), 
    an    => AN,
    seg7_cath => SEG7_CATH
  );

 ----- Game Logic-------------
-- The game starts with 3 square outlines at the bottom of the screen 
-- Squares of R, B, Y start to move down the screen to their respective
-- outlines, when they cover the outline, the correct button must be pressed
-- If done, percentage on 7 segment goes up. Start with 10 squares per game.
-- If not pressed in time, square will continue off screen and no point awarded.
-- When game finished, wait for a button press to restart.

Square_Outline : process(RESET_B, SCLK_s)
begin
  if(RESET_B = '1') then
    OutlineMade <= '0';
    OutlineSq <= "00";
    msgReady <= '0';
  elsif(falling_edge(SCLK_s)) then
    if(SPIReady = '1' and OutlineMade = '0') then
      case OutlineSq is
        when "00" =>
          SPIdata <= x"22002B1E3FFFFFFFFFFFFF00"; -- Leftmost Square
          NumberofBytes <= 11;
          msgReady <= '1';
          OutlineSq <= "01";
        when "01" =>
          SPIdata <= x"22202B3D3FFFFFFFFFFFFF00"; -- Middle Square
          NumberofBytes <= 11;
          msgReady <= '1';
          OutlineSq <= "10";
        when "10" => 
          SPIdata <= x"223F2B5E3FFFFFFFFFFFFF00"; -- Right Square
          NumberofBytes <= 11;
          msgReady <= '1';
          OutlineSq <= "11";
        when "11" => 
          OutlineMade <= '1';
          msgReady <= '0';
      end case;
    else
      msgReady <= '0';
    end if;
  end if;

end process Square_Outline;

end Behavioral;
