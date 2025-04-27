----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/25/2025 10:50:29 AM
-- Design Name:
-- Module Name: NoteController - Behavioral
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

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity notecontroller is
  generic (
    num_notes     : integer := 16;
    screen_height : integer := 64
  );
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    frame_tick    : in    std_logic;
    start         : in    std_logic;
    enable        : in    std_logic;
    hit_note_mask : in    std_logic_vector(num_notes - 1 downto 0);
    notes_y       : out   std_logic_vector(num_notes * 8 - 1 downto 0);
    notes_lane    : out   std_logic_vector(num_notes * 2 - 1 downto 0);
    notes_active  : out   std_logic_vector(num_notes - 1 downto 0)
  );
end entity notecontroller;

architecture behavioral of notecontroller is

  type note_t is record
    y      : integer range 0 to 96;
    lane   : integer range 0 to 2;
    active : std_logic;
  end record note_t;

  type note_array_t is array(0 to NUM_NOTES - 1) of note_t;

  signal notes : note_array_t;

  -- constant init_lanes : std_logic_vector(num_notes * 2 - 1 downto 0) :=
  --       "10011001100110011001100110011001";

begin

  process (clk, reset) is
  begin

    if (reset = '1') then

      for i in 0 to num_notes - 1 loop

        notes(i).y      <= 0;
        notes(i).lane    <= i mod 3; -- 0,1,2 repeating
        notes(i).active <= '0';

      end loop;

    elsif (rising_edge(clk)) then
      if (start = '1') then

        for i in 0 to num_notes - 1 loop

          notes(i).y      <= 0;
          notes(i).lane   <= i mod 3; -- 0,1,2 repeating
          notes(i).active <= '1';

        end loop;

      elsif ((enable = '1') and (frame_tick = '1')) then

        for i in 0 to num_notes - 1 loop

          if (hit_note_mask(i) = '1') then
            notes(i).active <= '0';
          elsif (notes(i).active = '1') then
            notes(i).y <= notes(i).y + 1;
            if (notes(i).y >= screen_height) then
              notes(i).active <= '0';
            end if;
          end if;

        end loop;

      end if;
    end if;

  end process;

  -- Registered Outputs
  process(clk, reset)
  begin
    if (reset = '1') then
      notes_y <= (others => '0');
      notes_lane <= (others => '0');
      notes_active <= (others => '0');
    elsif(rising_edge(clk)) then
      for i in 0 to num_notes - 1 loop
        notes_y(i * 8 + 7 downto i * 8) <= std_logic_vector(to_unsigned(notes(i).y, 8));
        notes_lane(i * 2 + 1 downto i * 2) <= std_logic_vector(to_unsigned(notes(i).lane, 2));
        notes_active(i) <= notes(i).active;
      end loop;
    end if;
  end process;

end architecture behavioral;
