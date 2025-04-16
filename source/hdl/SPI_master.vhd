----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/16/2025 12:35:28 PM
-- Design Name: 
-- Module Name: SPI_master - Behavioral
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
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SPI_master is
  generic (
    fpga_clock : integer := 100000000 -- clock of fpga board
  );
  port (
    CLK           : in std_logic;
    Data_in       : in std_logic_vector (95 downto 0);
    Reset         : in std_logic;
    msgReady      : in std_logic;
    NumberofBytes : in integer;
    OffDevice     : in std_logic;
    CS            : out std_logic;
    MOSI          : out std_logic;
    SCLK          : out std_logic;
    SCLK_sig      : out std_logic;
    MISO          : in std_logic;
    Data_Command  : out std_logic;
    VCCEnable     : out std_logic;
    PMODEnable    : out std_logic;
    SlaveReset    : out std_logic;
    SPIReady      : out std_logic
  );
  --    p_delayDone : out STD_LOGIC;
  --    p_SPI_start : out STD_LOGIC;
  --    p_CurrState : out unsigned(7 downto 0);
  --    p_Serialize : out STD_LOGIC);
end SPI_master;

architecture Behavioral of SPI_master is

  signal MxCnt1ms    : integer := (fpga_clock/1000);
  signal MxCnt1us    : integer := (fpga_clock/1000000);
  signal sclk_signal : std_logic;

  signal Delay_EN      : std_logic;
  signal delayMaxCount : integer := fpga_clock;
  signal delayReset    : std_logic;

  type PowerUpFSM is (Init, Wait20ms, ResetToggle, SPIUnlock, BreakState, DisplayOff, DisplayRemap, SetStartLine, SetVertOffset,
    SetNormalDisplay, SetMultiplexRatio, SetVCCSupply, DisablePwrSaving, SetChrgDschrgPhase, SetDisplayClkDivideRatio,
    SetPreChrgSpeedClrA, SetPreChrgSpeedClrB, SetPreChrgSpeedClrC, SetPreChrgVolt, SetVCOMH,
    SetMasterAtten, SetAContrast, SetBContrast, SetCContrast, DisableScrolling, ClearScreen, ENVCC, OnDisplay, OLEDReady, Done);

  type NormalOpFSM is (Init, WaitforSPImsg, SendSPImsg, BreakState, Done);

  type ShutDownFSM is (Init, DisplayOff, ENVCC_off, Done);

  --PowerUpFSM signals --

  signal PowerUpState   : PowerUpFSM := Init;
  signal PrevPwrUpState : PowerUpFSM; --let FSM return to its state after going to BreakState
  signal Start_SPI      : std_logic := '0';

  signal delayDone          : std_logic;
  signal serializer_data_in : std_logic_vector(95 downto 0);
  signal Serialize          : std_logic;
  signal Wait_s             : std_logic;

  signal PowerUpFSM_data          : std_logic_vector(95 downto 0);
  signal PowerUpFSM_numBytes      : integer   := 0;
  signal PowerUpFSM_delayMaxCount : integer   := fpga_clock;
  signal PowerUpFSM_VCCEN         : std_logic := '0';
  signal PowerUpFSM_delay_EN      : std_logic := '0';
  signal PowerUpFSM_Serialize     : std_logic := '0';
  signal PowerUpFSM_DC            : std_logic := '0';

  --NormalOpFSM signals--

  signal NormalOpState         : NormalOpFSM := Init;
  signal NormalOpFSM_data      : std_logic_vector(95 downto 0);
  signal NormalOpFSM_numBytes  : integer   := 0;
  signal NormalOpFSM_Serialize : std_logic := '0';
  signal NormalOpFSM_DC        : std_logic := '0';
  signal NormalOpWait_s        : std_logic := '0';

  --ShutDownFSM signals --

  signal ShutDownState             : ShutDownFSM := Init;
  signal ShutDownFSM_data          : std_logic_vector(95 downto 0);
  signal ShutDownFSM_numBytes      : integer   := 0;
  signal ShutDownFSM_delayMaxCount : integer   := fpga_clock;
  signal ShutDownFSM_VCCEN         : std_logic := '0';
  signal ShutDownFSM_delay_EN      : std_logic := '0';
  signal ShutDownFSM_Serialize     : std_logic := '0';
  signal ShutDownFSM_DC            : std_logic := '0';

  --Serializer signals -- 
  signal NumofBytes    : integer;
  signal NumberofBits  : integer                       := 0;
  signal msgDone       : std_logic                     := '0';
  signal SerializerReg : std_logic_vector(95 downto 0) := (others => '0');
  signal CopiedData    : std_logic                     := '0';
  signal CS_s          : std_logic;
  signal Wait1Cycle    : std_logic := '0';

  --Debug Signals --
  signal CurrState    : integer := 0;
  signal CurrStateBuf : unsigned(7 downto 0);
  signal locked_s     : std_logic;

  component clk_wiz_0
    port (
      clk_in1  : in std_logic;
      reset    : in std_logic;
      clk_out1 : out std_logic;
      locked   : out std_logic
    );
  end component;

begin

  -- p_delayDone <= delayDone;
  -- p_SPI_start <= Start_SPI;
  -- p_CurrState <= CurrStateBuf;
  -- p_Serialize <= Serialize;
  CurrStateBuf <= TO_UNSIGNED(CurrState, 8);
  --Generate Serial Clock at 5 MHz

  Serial_Clock : clk_wiz_0
  port map
  (
    clk_in1  => CLK,
    reset    => Reset,
    clk_out1 => sclk_signal,
    locked   => locked_s
  );

  Delay : entity work.pulseGenerator
    port map
    (
      clk      => CLK,
      reset    => Reset,
      maxCount => to_unsigned(delayMaxCount, 27),
      pulseOut => delayDone,
      EN       => Delay_EN
    );

  --This will prevent multiple driven nets across common ports used by FSMs
  ManageFSMports : process (PowerUpState, OffDevice)
  begin
    if (PowerUpState = Done and OffDevice = '0') then
      --Redirect serializer data in port to look at Data_in
      serializer_data_in <= NormalOpFSM_data;
      NumofBytes         <= NormalOpFSM_numBytes;
      Serialize          <= NormalOpFSM_Serialize;
      Data_Command       <= NormalOpFSM_DC;
    elsif (PowerUpState = Done and OffDevice = '1') then
      --Stop all others FSM, going to shut down OLED screen
      --PowerUpState       <= Done;
      --NormalOpState      <= Done;
      serializer_data_in <= ShutDownFSM_data;
      NumofBytes         <= ShutDownFSM_numBytes;
      delayMaxCount      <= ShutDownFSM_delayMaxCount;
      VCCEnable          <= ShutDownFSM_VCCEN;
      delay_EN           <= ShutDownFSM_delay_EN;
      Serialize          <= ShutDownFSM_Serialize;
      Data_Command       <= ShutDownFSM_DC;
    else
      serializer_data_in <= PowerUpFSM_data;
      NumofBytes         <= PowerUpFSM_numBytes;
      delayMaxCount      <= PowerUpFSM_delayMaxCount;
      VCCEnable          <= PowerUpFSM_VCCEN;
      delay_EN           <= PowerUpFSM_delay_EN;
      Serialize          <= PowerUpFSM_Serialize;
      Data_Command       <= PowerUpFSM_DC;
    end if;
  end process ManageFSMports;

  PowerUpFSMproc : process (sclk_signal, Reset)
  begin
    if (Reset = '1') then
      PowerUpState <= Init;
    elsif (rising_edge(sclk_signal)) then
      case PowerUpState is
        when Init =>
          PowerUpFSM_DC        <= '0'; --Command Mode
          SlaveReset           <= '1';
          PowerUpFSM_VCCEN     <= '0';
          PMODEnable           <= '1';
          PowerUpFSM_Serialize <= '0';
          Wait_s               <= '0';
          CurrState            <= 1;
          PowerUpState         <= Wait20ms;
        when Wait20ms =>
          PowerUpFSM_delay_EN      <= '1';
          PowerUpFSM_delayMaxCount <= (MxCnt1ms * 20);
          CurrState                <= 2;
          if (delayDone = '1') then
            --delayReset <= '1';
            PowerUpState <= ResetToggle;
          else
            PowerUpState <= Wait20ms;
          end if;
        when ResetToggle =>
          delayReset               <= '0';
          PowerUpFSM_delayMaxCount <= (MxCnt1us * 3);
          SlaveReset               <= '0';
          CurrState                <= 3;
          if (delayDone = '1') then
            SlaveReset   <= '1';
            PowerUpState <= SPIUnlock;
          else
            PowerUpState <= ResetToggle;
          end if;
        when SPIUnlock =>
          PowerUpFSM_delay_EN  <= '0';
          delayReset           <= '1';
          PowerUpFSM_Serialize <= '1';
          PowerUpFSM_data      <= x"FD1200000000000000000000";
          CurrState            <= 4;
          PowerUpFSM_numBytes  <= 2;
          if (msgDone = '1') then
            PowerUpState         <= DisplayOff;
            PowerUpFSM_Serialize <= '0';
            Wait_s               <= '1';
          else
            PowerUpState <= SPIUnlock;
          end if;
        when BreakState =>
          CurrState <= 32;
          if (msgDone = '1') then
            PowerUpState <= BreakState;
          else
            PowerUpState <= PrevPwrUpState;
            Wait_s       <= '0';
          end if;
        when DisplayOff =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= DisplayOff;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"AE0000000000000000000000";
            PowerUpFSM_numBytes  <= 1;
            PowerUpFSM_Serialize <= '1';
            CurrState            <= 5;
            if (msgDone = '1') then
              PowerUpState         <= DisplayRemap;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= DisplayOff;
            end if;
          end if;
        when DisplayRemap =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= DisplayRemap;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"A07200000000000000000000";
            PowerUpFSM_numBytes  <= 2;
            PowerUpFSM_Serialize <= '1';
            CurrState            <= 6;
            if (msgDone = '1') then
              PowerUpState         <= SetStartLine;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= DisplayRemap;
            end if;
          end if;
        when SetStartLine =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetStartLine;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"A10000000000000000000000";
            PowerUpFSM_numBytes  <= 2;
            PowerUpFSM_Serialize <= '1';
            CurrState            <= 7;
            if (msgDone = '1') then
              PowerUpState         <= SetVertOffset;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetStartLine;
            end if;
          end if;
        when SetVertOffset =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetVertOffset;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"A20000000000000000000000";
            PowerUpFSM_numBytes  <= 2;
            PowerUpFSM_Serialize <= '1';
            CurrState            <= 8;
            if (msgDone = '1') then
              PowerUpState         <= SetNormalDisplay;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetVertOffset;
            end if;
          end if;
        when SetNormalDisplay =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetNormalDisplay;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"A40000000000000000000000";
            PowerUpFSM_numBytes  <= 1;
            PowerUpFSM_Serialize <= '1';
            CurrState            <= 9;
            if (msgDone = '1') then
              PowerUpState         <= SetMultiplexRatio;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetNormalDisplay;
            end if;
          end if;
        when SetMultiplexRatio =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetMultiplexRatio;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"A83F00000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 10;
            if (msgDone = '1') then
              PowerUpState         <= SetVCCSupply;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetMultiplexRatio;
            end if;
          end if;
        when SetVCCSupply =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetVCCSupply;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"AD8E00000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 11;
            if (msgDone = '1') then
              PowerUpState         <= DisablePwrSaving;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetVCCSupply;
            end if;
          end if;
        when DisablePwrSaving =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= DisablePwrSaving;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"B00B00000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 12;
            if (msgDone = '1') then
              PowerUpState         <= SetChrgDschrgPhase;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= DisablePwrSaving;
            end if;
          end if;
        when SetChrgDschrgPhase =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetChrgDschrgPhase;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"B13100000000000000000000";
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 13;
            PowerUpFSM_Serialize <= '1';
            if (msgDone = '1') then
              PowerUpState         <= SetDisplayClkDivideRatio;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetChrgDschrgPhase;
            end if;
          end if;
        when SetDisplayClkDivideRatio =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetDisplayClkDivideRatio;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"B3F000000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 14;
            if (msgDone = '1') then
              PowerUpState         <= SetPreChrgSpeedClrA;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetDisplayClkDivideRatio;
            end if;
          end if;
        when SetPreChrgSpeedClrA =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetPreChrgSpeedClrA;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"8A6400000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 15;
            if (msgDone = '1') then
              PowerUpState         <= SetPreChrgSpeedClrB;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetPreChrgSpeedClrA;
            end if;
          end if;
        when SetPreChrgSpeedClrB =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetPreChrgSpeedClrB;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"8B7800000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 16;
            if (msgDone = '1') then
              PowerUpState         <= SetPreChrgSpeedClrC;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetPreChrgSpeedClrB;
            end if;
          end if;
        when SetPreChrgSpeedClrC =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetPreChrgSpeedClrC;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"8C6400000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 17;
            if (msgDone = '1') then
              PowerUpState         <= SetPreChrgVolt;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetPreChrgSpeedClrC;
            end if;
          end if;
        when SetPreChrgVolt =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetPreChrgVolt;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"BB3A00000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 18;
            if (msgDone = '1') then
              PowerUpState         <= SetVCOMH;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetPreChrgVolt;
            end if;
          end if;
        when SetVCOMH =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetVCOMH;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"BE3E00000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 19;
            if (msgDone = '1') then
              PowerUpState         <= SetMasterAtten;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetVCOMH;
            end if;
          end if;
        when SetMasterAtten =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetMasterAtten;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"870600000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 20;
            if (msgDone = '1') then
              PowerUpState         <= SetAContrast;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetMasterAtten;
            end if;
          end if;
        when SetAContrast =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetAContrast;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"819100000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 21;
            if (msgDone = '1') then
              PowerUpState         <= SetBContrast;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetAContrast;
            end if;
          end if;
        when SetBContrast =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetBContrast;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"825000000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 22;
            if (msgDone = '1') then
              PowerUpState         <= SetCContrast;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetBContrast;
            end if;
          end if;
        when SetCContrast =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= SetCContrast;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"837D00000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 2;
            CurrState            <= 23;
            if (msgDone = '1') then
              PowerUpState         <= DisableScrolling;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= SetCContrast;
            end if;
          end if;
        when DisableScrolling =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= DisableScrolling;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"2E0000000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 1;
            CurrState            <= 24;
            if (msgDone = '1') then
              PowerUpState         <= ClearScreen;
              PowerUpFSM_Serialize <= '0';
              Wait_s               <= '1';
            else
              PowerUpState <= DisableScrolling;
            end if;
          end if;
        when ClearScreen =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= ClearScreen;
            PowerUpState   <= BreakState;
          else
            PowerUpFSM_data      <= x"2500005F3F00000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 5;
            CurrState            <= 25;
            if (msgDone = '1') then
              PowerUpState         <= ENVCC;
              PowerUpFSM_Serialize <= '0';
            else
              PowerUpState <= ClearScreen;
            end if;
          end if;
        when ENVCC =>
          PowerUpFSM_VCCEN         <= '1';
          PowerUpFSM_delay_EN      <= '1';
          PowerUpFSM_delayMaxCount <= (MxCnt1ms * 25);
          CurrState                <= 26;
          if (delayDone = '1') then
            PowerUpState <= OnDisplay;
            Wait_s       <= '1';
          else
            PowerUpState <= ENVCC;
          end if;
        when OnDisplay =>
          if (msgDone = '1' and Wait_s = '1') then
            PrevPwrUpState <= OnDisplay;
            PowerUpState   <= BreakState;
          else
            delayReset           <= '1';
            PowerUpFSM_data      <= x"AF0000000000000000000000";
            PowerUpFSM_Serialize <= '1';
            PowerUpFSM_numBytes  <= 1;
            CurrState            <= 27;
            if (msgDone = '1') then
              PowerUpState         <= OLEDReady;
              PowerUpFSM_Serialize <= '0';
            else
              PowerUpState <= OnDisplay;
            end if;
          end if;
        when OLEDReady =>
          delayReset               <= '0';
          PowerUpFSM_delay_EN      <= '1';
          CurrState                <= 28;
          PowerUpFSM_delayMaxCount <= (MxCnt1ms * 100);
          if (delayDone = '1') then
            PowerUpFSM_delay_EN <= '0';
            --Wait_s <= '1';
            PowerUpFSM_Serialize <= '0';
            PowerUpState         <= Done;
          else
            PowerUpState <= OLEDReady;
          end if;
          -- when testState0 =>
          --     if(msgDone = '1' and Wait_s = '1') then
          --         PrevPwrUpState <= testState0;
          --         PowerUpState <= BreakState;
          --     else
          --         delayReset <= '1';
          --         PowerUpFSM_data <= x"260000000000000000000000";
          --         PowerUpFSM_Serialize <= '1';
          --         PowerUpFSM_numBytes <= 2;
          --         CurrState <= 29;
          --         if(msgDone = '1') then
          --             PowerUpFSM_Serialize <= '0';
          --             Wait_s <= '1';
          --             PowerUpState <= testState;
          --         else
          --             PowerUpState <= testState0;
          --         end if;
          --     end if;
          -- when testState =>
          --     if(msgDone = '1' and Wait_s = '1') then
          --         PrevPwrUpState <= testState;
          --         PowerUpState <= BreakState;
          --     else
          --         delayReset <= '1';
          --         PowerUpFSM_data <= x"223F2B5E3FFFFFFFFFFFFF00";
          --         PowerUpFSM_Serialize <= '1';
          --         PowerUpFSM_numBytes <= 11;
          --         CurrState <= 30;
          --         if(msgDone = '1') then
          --             PowerUpFSM_Serialize <= '0';
          --             PowerUpState <= Done;
          --         else
          --             PowerUpState <= testState;
          --         end if;
          --     end if;
        when Done =>
          Start_SPI <= '1';
      end case;
    end if;
  end process PowerUpFSMproc;

  NormalOpFSMproc : process (sclk_signal, Reset)
  begin
    if (Reset = '1') then
      NormalOpState         <= Init;
      NormalOpFSM_Serialize <= '0';
      SPIReady              <= '0';
      --Start_SPI <= '0';
    elsif (rising_edge(sclk_signal)) then
      case NormalOpState is
        when Init =>
          SPIReady <= '0';
          --CurrState <= 29;
          if (Start_SPI = '1') then
            NormalOpState <= WaitforSPImsg;
          end if;
        when WaitforSPImsg =>
          if(msgDone = '1' and NormalOpWait_s = '1') then
            NormalOpState <= BreakState;
          else
            NormalOpFSM_Serialize <= '0';
            SPIReady              <= '1';
          --CurrState <= 30;
            if (msgReady = '1') then
              NormalOpFSM_DC        <= '0'; --Command Mode
              SPIReady              <= '0';
              NormalOpFSM_Serialize <= '1';
              NormalOpFSM_data      <= Data_in;
              NormalOpFSM_numBytes  <= NumberofBytes;
              NormalOpState         <= SendSPImsg;
            end if;
          end if;
        when SendSPImsg =>
          --CurrState <= 31;        
          if (msgDone = '1') then
            NormalOpFSM_Serialize <= '0';
            NormalOpState         <= WaitforSPImsg;
            NormalOpWait_s <= '0';
          end if;
        when BreakState =>
          if (msgDone = '1') then
            NormalOpState <= BreakState;
          else
            NormalOpState <= WaitforSPImsg;
            NormalOpWait_s       <= '0';
          end if;
        when Done =>
          NormalOpFSM_Serialize <= '0';
          SPIReady              <= '0';
      end case;
    end if;
  end process NormalOpFSMproc;

  ShutDownFSMproc : process (sclk_signal, Reset)
  begin
    if (Reset = '1') then
      ShutDownState <= Init;
    elsif (rising_edge(sclk_signal)) then
      case ShutDownState is
        when Init =>
          if (OffDevice = '1' and PowerUpState = Done) then
            ShutDownFSM_delay_EN <= '0';
            ShutDownState        <= DisplayOff;
          else
            ShutDownState <= Init;
          end if;
        when DisplayOff =>
          ShutDownFSM_Serialize <= '1';
          ShutDownFSM_numBytes  <= 1;
          ShutDownFSM_data      <= x"AE0000000000000000000000";
          if (msgDone = '1') then
            ShutDownState         <= ENVCC_off;
            ShutDownFSM_Serialize <= '0';
          else
            ShutDownState <= DisplayOff;
          end if;
        when ENVCC_off =>
          ShutDownFSM_VCCEN         <= '0'; --Need to resolve this
          ShutDownFSM_delay_EN      <= '1';
          ShutDownFSM_delayMaxCount <= (MxCnt1ms * 400);
          if (delayDone = '1') then
            ShutDownState <= Done;
          else
            ShutDownState <= ENVCC_off;
          end if;
        when Done =>
          ShutDownState <= Done;
      end case;
    end if;
  end process ShutDownFSMproc;

  Serializer : process (sclk_signal, reset)
  begin
    if (reset = '1') then
      SerializerReg <= (others => '0');
      CS_s          <= '1';
      CopiedData    <= '0';
      msgDone       <= '0';
      Wait1Cycle    <= '0';
    elsif (falling_edge(sclk_signal)) then
      if (Serialize = '1' and CopiedData = '0') then
        SerializerReg <= serializer_data_in;
        NumberofBits  <= NumofBytes * 8;
        CopiedData    <= '1';
        CS_s          <= '0';
        msgDone       <= '0';
      elsif (Serialize = '1' and CopiedData = '1') then
        if (NumberofBits > 0) then
          SerializerReg <= std_logic_vector(unsigned(SerializerReg) sll 1);
          NumberofBits  <= NumberofBits - 1;
          msgDone       <= '0';
        else
          CS_s       <= '1'; --Must be done with command so pull CS high
          msgDone    <= '1';
          CopiedData <= '0';
          Wait1Cycle <= '0';
        end if;
      else
        SerializerReg <= (others => '0');
        msgDone       <= '0';
      end if;
    end if;
  end process Serializer;

  SCLK <= sclk_signal when (CS_s = '0') else '1';
  SCLK_sig <= sclk_signal;
  CS       <= CS_s;

  MOSI <= SerializerReg(95);

end Behavioral;
