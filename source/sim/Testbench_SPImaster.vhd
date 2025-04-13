----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/17/2025 10:35:27 PM
-- Design Name: 
-- Module Name: Testbench_SPImaster - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
use work.all;

entity Testbench_SPImaster is
--  Port ( );
end Testbench_SPImaster;

architecture Behavioral of Testbench_SPImaster is

    signal CLK : std_logic;
    signal reset : std_logic:= '0';
    signal MISO : std_logic := '0';
    signal Data_in : STD_LOGIC_VECTOR(95 downto 0):= (others=>'0');
    signal NumberofBytes : integer;
    signal delayDone: STD_LOGIC;
    signal SPI_start: STD_LOGIC;
    signal CurrState: unsigned(7 downto 0);
    signal Serialize: STD_LOGIC;
    signal msgReady : STD_LOGIC;
    signal OffDevice : STD_LOGIC;
    signal SPIReady : STD_LOGIC;
    

    --SPI Control Signals
    signal CS,MOSI, Data_Command, VCCEnable, SlaveReset, SCLK, PMODEnable : std_logic;

begin
    --100MHz clock
    process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;

    --PowerUpFSM testbench process
    -- process
    -- begin
    -- reset <= '1';
    -- wait for 100ns;
    -- reset <= '0';
    -- wait;
    -- end process;

    --NormalOpFSM testbench process
    process
    begin
        reset <= '1';
        wait for 100ns;
        reset <= '0';
        wait for 50ns;
        msgReady <= '1';
        Data_in <= x"22002B1F3FFFFFFFFFFFFF00";
        NumberofBytes <= 11;
        wait for 1ns;
        msgReady <= '0';
        wait for 500ns;
    end process;


    --DUT
    SPI_DUT : entity SPI_master port map(
        CLK => CLK,
        Data_in => Data_in,
        NumberofBytes => NumberofBytes,
        Reset => reset,
        msgReady => msgReady,
        OffDevice => OffDevice,
        SPIReady => SPIReady,
        CS => CS,
        MOSI => MOSI,
        MISO => MISO,
        SCLK => SCLK,
        Data_Command => Data_Command,
        PMODEnable => PMODEnable,
        VCCEnable => VCCEnable,
        SlaveReset => SlaveReset,
        p_delayDone => delayDone,
        p_SPI_start => SPI_start,
        p_CurrState => CurrState,
        p_Serialize => Serialize
    );

end Behavioral;
