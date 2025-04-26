----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/22/2025 06:02:11 PM
-- Design Name: 
-- Module Name: Testbench_GameLogic - Behavioral
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

entity Testbench_GameLogic is
--  Port ( );
end Testbench_GameLogic;

architecture Behavioral of Testbench_GameLogic is

    signal clk : std_logic;
    signal reset : std_logic := '0';
    
    signal btnc : std_logic := '0';
    signal btnl : std_logic := '0';
    signal btnr : std_logic := '0';
    
    signal an : std_logic_vector(7 downto 0);
    signal seg7_cath : std_logic_vector(7 downto 0);

    signal cs         : std_logic;
    signal mosi       : std_logic;
    signal dat_cmd    : std_logic; -- Data/Command Bit 1 = Data. 0 = Command
    signal sclk       : std_logic; -- Minimum Period is 150ns
    signal oled_reset : std_logic;
    signal vcc_en     : std_logic;
    signal pmod_en    : std_logic;

    signal gamestate : integer;
    signal spidata : std_logic_vector(95 downto 0);
    signal numberofbytes : integer;
    signal blueindex : integer;
    signal tempindexb : integer;
    signal bluesquares_one : std_logic_vector(95 downto 0);
    signal blue_reg : std_logic_vector(7 downto 0);
    signal bluevector : std_logic_vector(7 downto 0); 

    -- signal currstate : unsigned(7 downto 0);
    -- signal delayDone : std_logic;

begin

    --DUT
    Logic_DUT : entity work.rhythmgame_top port map(
        clk100mhz => clk,
        reset_b => reset,
        btnc => btnc,
        btnl => btnl,
        btnr => btnr,
        an => an,
        seg7_cath => seg7_cath,
        cs => cs,
        mosi => mosi,
        dat_cmd => dat_cmd,
        sclk => sclk,
        oled_reset => oled_reset,
        vcc_en => vcc_en,
        pmod_en => pmod_en,

        gamestate_out => gamestate,
        spidata_out => spidata,
        NumberofBytes_out => numberofbytes,
        blueindex_out => blueindex,
        tempindexb_out => tempindexb,
        bluesquares_one_out => bluesquares_one,
        blue_reg_out => blue_reg,
        bluevector_out => bluevector

        -- CurrState => currstate,
        -- delayDone => delayDone

    );

    --100MHz clock
    process
    begin
        clk <= '0';
        wait for 1 ns;
        clk <= '1';
        wait for 1 ns;
    end process;

    process
    begin
    reset <= '1';
    wait for 100ns;
    reset <= '0';
    wait;
    end process;




end Behavioral;
