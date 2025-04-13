----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/21/2024 09:56:10 PM
-- Design Name: 
-- Module Name: Debounce - Behavioral
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

entity Debounce is
    Port ( BTNI : in STD_LOGIC;
           BTNO : out STD_LOGIC;
           CLK : in STD_LOGIC);
end Debounce;

architecture Behavioral of Debounce is
signal counter : integer := 400000;

begin
    --debounces button input
    --When rising edge of clk is received, decrement a counter
    --Only output the button input value if counter hits 0(~250ms)
    debounce : process(clk) 
        begin
        if rising_edge(clk) then
            if(BTNI = '1') then
                counter <= (counter - 1);
                if(counter = 0) then
                    BTNO <= BTNI;
                else
                    BTNO <= '0';
                end if;
            else
                counter <= 400000;
            end if;             
        end if;
   end process debounce;

end Behavioral;
