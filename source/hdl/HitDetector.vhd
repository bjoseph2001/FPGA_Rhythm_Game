----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/25/2025 09:59:07 AM
-- Design Name:
-- Module Name: HitDetector - Behavioral
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

  -- Uncomment the following library declaration if using
  -- arithmetic functions with Signed or Unsigned values
  use ieee.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity hitdetector is
  generic (
    num_notes : integer := 16;
    hit_min   : integer := 54;
    hit_max   : integer := 64
  );
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    button_lane   : in    std_logic_vector(1 downto 0);
    button_click  : in    std_logic; -- single-cycle pulse
    notes_y       : in    std_logic_vector(num_notes * 8 - 1 downto 0);
    notes_lane    : in    std_logic_vector(num_notes * 2 - 1 downto 0);
    notes_active  : in std_logic_vector(num_notes - 1 downto 0);
    hit           : out   std_logic;
    hit_note_mask : out   std_logic_vector(num_notes - 1 downto 0)
  );
end entity hitdetector;

architecture behavioral of hitdetector is

begin

  process (clk, reset) is

    variable local_hit : std_logic;
    variable mask      : std_logic_vector(num_notes - 1 downto 0);

  begin

    if (reset = '1') then
      hit           <= '0';
      hit_note_mask <= (others => '0');
    elsif (rising_edge(clk)) then
      local_hit := '0';
      mask      := (others => '0');

      if (button_click = '1') then

        for i in 0 to num_notes - 1 loop

          if ((notes_active(i) = '1') and
              (unsigned(notes_lane(i * 2 + 1 downto i * 2)) = unsigned(button_lane)) and
              (to_integer(unsigned(notes_y(i * 8 + 7 downto i * 8))) >= hit_min) and
              (to_integer(unsigned(notes_y(i * 8 + 7 downto i * 8))) <= hit_max)) then
            mask(i)   := '1';  -- mark as hit
            local_hit := '1';
            exit;
          end if;

        end loop;

      end if;

      hit           <= local_hit;
      hit_note_mask <= mask;
    end if;

  end process;

end architecture behavioral;
