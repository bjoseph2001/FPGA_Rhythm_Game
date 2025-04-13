----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/11/2024 09:57:56 PM
-- Design Name: 
-- Module Name: pulseGenerator - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pulseGenerator is

    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           maxCount : in unsigned(26 downto 0);
           EN : in STD_LOGIC;
           pulseOut : out STD_LOGIC);
end pulseGenerator;

architecture Behavioral of pulseGenerator is
    --will increment every rising edge clk and reset once it matches maxCount
    signal Cntr : unsigned(26 downto 0);
    --clear Counter
    signal clear : std_logic;
begin
    --Pulse Generator
    process(clk, reset)
    begin
        if(reset = '1') then
            Cntr <= (others => '0');
        elsif(rising_edge(clk)) then
            if(EN = '1') then
                if (clear = '1') then
                    Cntr <= (others => '0');
                else
                    Cntr <= Cntr + 1;
                end if;
            end if;
        end if;
    end process;
    
    clear <= '1' when (Cntr = maxCount) else '0';
    pulseOut <= clear;
end Behavioral;
