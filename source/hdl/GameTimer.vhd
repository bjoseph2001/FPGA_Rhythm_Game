----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/25/2025 09:45:27 AM
-- Design Name: 
-- Module Name: GameTimer - Behavioral
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

entity GameTimer is
    Port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        enable     : in  std_logic; -- From FSM
        frame_tick : in  std_logic;
        game_done  : out std_logic
    );
end GameTimer;

architecture Behavioral of GameTimer is
    constant GAME_DURATION : integer := 2400; --30 seconds @ 60 fps = 1800 ticks
    signal counter : integer range 0 to GAME_DURATION;
begin

    process(clk, reset)
    begin
        if(reset = '1') then
            counter <= 0;
        elsif(rising_edge(clk)) then
            if((enable = '1') and (frame_tick = '1')) then
                if(counter < GAME_DURATION) then
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;

    game_done <= '1' when counter >= GAME_DURATION else '0';

end Behavioral;
