----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/11/2024 09:09:47 PM
-- Design Name: 
-- Module Name: seg7_controller - Behavioral
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

entity seg7_controller is
--generics for pulse gen counter calculation
generic(
    desiredfreq1kHz : integer := 1000; -- desired freq in Hz
    fpga_clock : integer := 100000000 -- clock of fpga board
    );

 Port (clk100 : in std_logic;
       rst : in std_logic;
       char0 : in std_logic_vector(3 downto 0);
       char1 : in std_logic_vector(3 downto 0);
       char2 : in std_logic_vector(3 downto 0);
       char3 : in std_logic_vector(3 downto 0);
       char4 : in std_logic_vector(3 downto 0);
       char5 : in std_logic_vector(3 downto 0);
       char6 : in std_logic_vector(3 downto 0);
       char7 : in std_logic_vector(3 downto 0);
       an    : out std_logic_vector(7 downto 0);
       seg7_cath : out std_logic_vector(7 downto 0));
       
end seg7_controller;

architecture Behavioral of seg7_controller is
--output of char mux to decoder
signal char_signal : std_logic_vector(3 downto 0);
--1kHz pulse
signal pulse : std_logic;
--choose which 7seg display to turn on
signal anode : unsigned (3 downto 0) := "0000";
--1 kHz pulse gen counter calculation
signal MxCnt1kHz : integer := (fpga_clock/desiredfreq1kHz);

begin
    --7 seg takes 4 bit input and output 8 bit decoded for 7 seg display
    seg7disp : entity work.seg7_hex port map(
            digit => char_signal(3 downto 0),
            seg7 => seg7_cath(7 downto 0)
        );
    --Outputs a 1 kHz pulse
    --maxCount expects a 27 bit wide unsigned, so integer must be converted    
    OnekHzpulseGen : entity work.pulseGenerator port map(
            clk => clk100,
            reset => rst,
            maxCount => to_unsigned(MxCnt1kHz,27),
            pulseOut => pulse,
            EN => '1'
        );
    
    --decides which 7seg display to turn on based on the pulse and counter 
    --happens fast enough where we will see all displays on at the same time      
    calcAnode : process(clk100,rst)
    begin
            if (rst = '1') then 
                anode <= "1111";
            elsif(rising_edge(clk100)) then
                if(pulse = '1') then
                   anode <= anode + 1;
                    if(anode >= "1000") then
                        anode <= "0000";
                    end if;
                end if;
            end if;
    end process calcAnode;    
    
    --choose which display to turn on based on anode value from calcAnode
    anode_sel : process(anode)
    begin
        case anode is 
            when "0000" =>
                an(7 downto 0) <= not(x"01");
            when "0001" =>
                an(7 downto 0) <= not(x"02");
            when "0010" => 
                an(7 downto 0) <= not(x"04");
            when "0011" =>
                an(7 downto 0) <= not(x"08");
            when "0100" => 
                an(7 downto 0) <= not(x"10");
            when "0101" => 
                an(7 downto 0) <= not(x"20");
            when "0110" =>
                an(7 downto 0) <= not(x"40");
            when "0111" => 
                an(7 downto 0) <= not(x"80");
            when "1111" =>
                an(7 downto 0) <= not(x"FF");
            when others =>
                --if this happens then a bit was flipped erroneously
                an(7 downto 0) <= not(x"00");
            end case;
    end process anode_sel;
    
    --decides which character to send to the decoder based on anode counter value
    char_mux : process(anode,char0,char1,char2,char3,char4,char5,char6,char7)
    begin
        case anode is 
            when "0000" =>
                char_signal <= char0;
            when "0001" =>
                char_signal <= char1;
            when "0010" => 
                char_signal <= char2;
            when "0011" =>
                char_signal <= char3;
            when "0100" => 
                char_signal <= char4;
            when "0101" => 
                char_signal <= char5;
            when "0110" =>
                char_signal <= char6;
            when "0111" => 
                char_signal <= char7;
            when others =>
                char_signal <= "0000";
        end case;
 
    end process char_mux;    
    


end Behavioral;
