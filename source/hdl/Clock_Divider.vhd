----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/18/2025 09:26:04 PM
-- Design Name: 
-- Module Name: Clock_Divider - Behavioral
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
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Clock_Divider is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           maxCount : in unsigned(26 downto 0);
           clkout : out STD_LOGIC);
end Clock_Divider;

architecture Behavioral of Clock_Divider is
    --will increment every rising edge clk and reset once it matches maxCount
    signal counter : unsigned(26 downto 0);
    --clear Counter
    signal clk_signal : std_logic:= '0';
begin
    --Pulse Generator
    process(clk, reset)
    begin
        if(reset = '1') then
            counter <= (others => '0');
            clk_signal <= '0';
        elsif(rising_edge(clk)) then
            counter <= counter + 1;
            if(counter = maxCount) then
                clk_signal <= not clk_signal;
                counter <= (others =>'0');
            end if;
        end if;
    end process;
    clkout <= clk_signal;


end Behavioral;
