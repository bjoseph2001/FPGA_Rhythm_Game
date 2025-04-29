----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/25/2025 11:04:31 AM
-- Design Name: 
-- Module Name: RhythmGameFSM - Behavioral
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

entity RhythmGameFSM is
    port( 
        clk : in std_logic;
        reset : in std_logic;
        start_button : in std_logic;
        game_done  : in std_logic;
        start_game : out std_logic;
        playing    : out std_logic;
        show_score : out std_logic
    );
end RhythmGameFSM;

architecture Behavioral of RhythmGameFSM is
    type state_type is (idle, game_play, game_over);
    signal current_state, next_state : state_type;

    signal start_button_sync : std_logic := '0';
    signal start_counter : integer range 0 to 5 := 0;

begin
    --State Register
    process(clk, reset)
    begin
        if(reset = '1') then
            current_state <= idle;
        elsif(rising_edge(clk)) then
            current_state <= next_state;
        end if;
    end process;

    --Next State Logic
    process(current_state, start_button_sync, game_done)
    begin
        case current_state is 
            when idle =>
                if(start_button_sync = '1') then
                    next_state <= game_play;
                else 
                    next_state <= idle;
                end if;
            
            when game_play =>
                if(game_done = '1') then 
                    next_state <= game_over;
                else
                    next_state <= game_play;
                end if;
            
            when game_over =>
                if(start_button_sync = '1') then
                    next_state <= game_play;
                else
                    next_state <= game_over;
                end if;
            end case;
    end process;

    -- Output Logic (start pulse stretch)
    process(clk, reset)
    begin
        if(reset = '1')then
            start_game <= '0';
            start_counter <= 0;
        elsif(rising_edge(clk))then
            if((current_state = idle) and (next_state = game_play))then
                start_game <= '1';
                start_counter <= 5; -- Hold start pulse for 5 cycles
            elsif((current_state = game_over) and (next_state = game_play))then
                --start next game
                    start_game <= '1';
                    start_counter <= 5; -- Hold start pulse for 5 cycles
            elsif(start_counter > 0) then
                start_counter <= start_counter - 1;
                start_game <= '1';
            else
                start_game <= '0';
            end if;
        end if;
    end process;

    playing <= '1' when (current_state = game_play) else '0';
    show_score <= '1' when (current_state = game_over) else '0';

    --Rising edge detector for start_button
    process(clk, reset)
        variable last_btn : std_logic := '0';
    begin
        if(reset = '1') then
            start_button_sync <= '0';
            last_btn := '0';
        elsif(rising_edge(clk)) then
            if((start_button = '1') and (last_btn = '0')) then
                start_button_sync <= '1';
            else
                start_button_sync <= '0';
            end if;
            last_btn := start_button;
        end if;
    end process;


end Behavioral;
