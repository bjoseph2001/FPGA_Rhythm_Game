----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/25/2025 08:31:47 AM
-- Design Name:
-- Module Name: DisplayController - Behavioral
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

entity displaycontroller is
  port (
    clk          : in    std_logic;
    reset        : in    std_logic;
    frame_tick   : in    std_logic;
    notes_y      : in    std_logic_vector(16 * 8 - 1 downto 0); -- why 127 downto 0?
    notes_lane   : in    std_logic_vector(16 * 2 - 1 downto 0); -- why 31 downto 0?
    notes_active : in    std_logic_vector(15 downto 0);         -- why 16 notes?

    -- SPI Interface to SPI master --
    spi_data  : out   std_logic_vector(95 downto 0);
    spi_send  : out   std_logic;
    spi_bytes : out   integer range 1 to 12;
    spi_ready : in    std_logic
  );
end entity displaycontroller;

architecture behavioral of displaycontroller is

  type displayfsm is (idle, clear_background, draw_hitboxes, load_note, draw_rectangle, next_note, wait_send); -- combine set_column, set_row, draw_rectangle into one command
      
  signal state      : displayfsm := idle;
  signal prev_state : displayfsm := idle;

  signal note_index : integer range 0 to 15 := 0;
  signal sending : std_logic := '0'; -- hold spi_send until SPIReady drops

  -- Current drawing parameters
  signal current_x1, current_x2 : integer;
  signal current_y1, current_y2 : integer;
  signal lane                   : integer;
  signal ypos                   : integer;
  signal note_color             : std_logic_vector(23 downto 0);

  constant lane_width    : integer := 32;
  constant note_height   : integer := 6;

  constant hitbox_y1 : integer := 54;
  constant hitbox_y2 : integer := 62;

  -- Colors

  constant color_green   : std_logic_vector(23 downto 0) := x"00FF00";
  constant color_red  : std_logic_vector(23 downto 0) := x"FF0000";
  constant color_blue : std_logic_vector(23 downto 0) := x"0000FF";
  constant color_white : std_logic_vector(23 downto 0) := x"FFFFFF";

  signal draw_hitbox_lane : integer range 0 to 2 := 0;

  -- Internal Output Buffer
  signal data_out  : std_logic_vector(95 downto 0);
  signal bytes_out : integer;

begin

  -- Output handshake logic

  process (clk, reset) is
  begin

    if (reset = '1') then
      spi_send <= '0';
      sending  <= '0';
    elsif rising_edge(clk) then
      if ((sending = '0') and (spi_ready = '1')) then
        spi_data  <= data_out;
        spi_bytes <= bytes_out;
        spi_send  <= '1';
        sending   <= '1';
      elsif ((sending = '1') and (spi_ready = '0')) then
        spi_send <= '0';
        sending  <= '0';
      end if;
    end if;
  end process;

  process (clk, reset) is
  begin

    if (reset = '1') then
      state            <= idle;
      prev_state       <= idle;
      note_index       <= 0;
      draw_hitbox_lane <= 0;
    elsif (rising_edge(clk)) then

      case state is
        when idle =>
          if (frame_tick = '1') then
            state            <= clear_background;
          end if;

        when clear_background =>
          if((sending = '0') and (spi_ready = '1')) then
            data_out <= x"22" &
                        x"00" & x"00" & x"5F" & x"3F" &
                        x"000000" & x"000000" & x"00";                                         -- Border and no fill
            bytes_out <= 11;
            prev_state <= clear_background;
            state <= wait_send;
          end if;

        when draw_hitboxes =>
          if ((sending = '0') and (spi_ready = '1')) then
            current_x1 <= lane_width * draw_hitbox_lane + 2;
            current_x2 <= lane_width * (draw_hitbox_lane + 1) - 2;
            current_y1 <= hitbox_y1;
            current_y2 <= hitbox_y2;

            data_out  <= x"22" &
                         std_logic_vector(to_unsigned(current_x1, 8)) &
                         std_logic_vector(to_unsigned(current_y1, 8)) &
                         std_logic_vector(to_unsigned(current_x2, 8)) &
                         std_logic_vector(to_unsigned(current_y2, 8)) &
                         color_white & x"000000" & x"00";                                         -- Border and no fill
            bytes_out <= 11;
            prev_state <= draw_hitboxes;
            state <= wait_send;
          end if;

        when load_note =>
          if (note_index <= 15) then
            if (notes_active(note_index) = '1') then
              lane <= to_integer(unsigned(notes_lane(note_index * 2 + 1 downto note_index * 2)));
              ypos <= to_integer(unsigned(notes_y(note_index * 8 + 7 downto note_index * 8)));

              -- Select color based on lane
              case lane is
                when 0 =>
                  note_color <= color_red;
                when 1 =>
                  note_color <= color_blue;
                when 2 =>
                  note_color <= color_green;
                when others =>
                  note_color <= color_white; -- safety fallback
              end case;

              current_x1 <= lane * lane_width + 2;
              current_x2 <= (lane + 1) * lane_width - 2;
              current_y1 <= ypos;
              current_y2 <= ypos + note_height;                       

              prev_state <= load_note;
              state      <= draw_rectangle;
            else
              note_index <= note_index + 1;
              state <= load_note;
            end if;
          else
            state <= idle;                                                                        -- all notes done
          end if;
        
        when draw_rectangle =>
          if ((sending = '0') and (spi_ready = '1')) then
            data_out   <= x"22" &
                          std_logic_vector(to_unsigned(current_x1, 8)) &
                          std_logic_vector(to_unsigned(current_y1, 8)) &
                          std_logic_vector(to_unsigned(current_x2, 8)) &
                          std_logic_vector(to_unsigned(current_y2, 8)) &
                          note_color & note_color & x"00";
            bytes_out  <= 11;
            prev_state <= draw_rectangle;
            state      <= wait_send;
          end if;

        when wait_send =>

          if (sending = '1') then
            -- wait until spi_send is cleared again
            null;
          elsif(prev_state = clear_background) then
            draw_hitbox_lane <= 0;
            state <= draw_hitboxes;
          elsif (prev_state = draw_hitboxes) then
            if (draw_hitbox_lane = 2) then
                draw_hitbox_lane <= 0;
                note_index <= 0;
                state <= load_note;
            else
                draw_hitbox_lane <= draw_hitbox_lane + 1;
                state <= draw_hitboxes;
            end if;
          elsif (prev_state = draw_rectangle) then
            state <= next_note;
          end if;

        when next_note =>

          if (note_index < 15) then
            note_index <= note_index + 1;
            state      <= load_note;
          else
            state <= idle;
          end if;

      end case;

    end if;

  end process;

end architecture behavioral;
