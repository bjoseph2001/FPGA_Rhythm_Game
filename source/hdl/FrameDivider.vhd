----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/25/2025 12:23:58 PM
-- Design Name: 
-- Module Name: FrameDivider - Behavioral
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

entity FrameDivider is
    generic (
        CLOCK_FREQ_HZ : integer := 100000000; --Input clock frequency
        FRAME_RATE_HZ : integer := 60       --Target frame rate
    );
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           frame_tick : out STD_LOGIC
    );
end FrameDivider;

architecture Behavioral of FrameDivider is

    constant CYCLES_PER_TICK : integer := CLOCK_FREQ_HZ / FRAME_RATE_HZ;
    signal counter : integer range 0 to CYCLES_PER_TICK := 0;

begin

    process(clk, reset)
    begin
        if(reset = '1') then
            counter <= 0;
            frame_tick <= '0';
        elsif(rising_edge(clk)) then
            if(counter = CYCLES_PER_TICK - 1) then
                frame_tick <= '1';
                counter <= 0;
            else
                frame_tick <= '0';
                counter <= counter + 1;
            end if;
        end if;
    end process;

end Behavioral;
