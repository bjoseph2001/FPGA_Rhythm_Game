library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity displaycontroller is
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    frame_tick   : in  std_logic;
    notes_y      : in  std_logic_vector(16*8-1 downto 0);
    notes_lane   : in  std_logic_vector(16*2-1 downto 0);
    notes_active : in  std_logic_vector(15 downto 0);

    -- SPI Interface --
    spi_data  : out std_logic_vector(95 downto 0);
    spi_bytes : out integer;
    spi_send  : out std_logic;
    spi_ready : in  std_logic
  );
end entity displaycontroller;

architecture behavioral of displaycontroller is
  -- Color constants
  constant color_red   : std_logic_vector(23 downto 0) := x"1F0000";
  constant color_blue  : std_logic_vector(23 downto 0) := x"00001F";
  constant color_green : std_logic_vector(23 downto 0) := x"003F00";
  constant color_white : std_logic_vector(23 downto 0) := x"1F3F1F";
  constant color_black : std_logic_vector(23 downto 0) := x"000000";

  -- Geometry
  constant lane_width  : integer := 32;
  constant hitbox_y1   : integer := 54;
  constant hitbox_y2   : integer := 62;

  -- FSM states
  type displayfsm is (
    idle,
    fill_enable,
    clear_background,
    disable_fill,
    draw_hitboxes,
    enable_notes_fill,
    load_note,
    draw_rectangle,
    wait_send
  );
  signal state, prev_state : displayfsm := idle;

  -- Internal signals
  signal frame_req        : std_logic := '0';
  signal fill_enabled     : std_logic := '0';
  signal sending          : std_logic := '0';
  signal note_index       : integer range 0 to 15 := 0;
  signal draw_hitbox_lane : integer range 0 to 2  := 0;
  signal data_out         : std_logic_vector(95 downto 0) := (others => '0');
  signal bytes_out        : integer := 0;
  signal current_x1, current_x2 : integer := 0;
  signal current_y1, current_y2 : integer := 0;
  signal lane                  : integer := 0;
  signal ypos                  : integer := 0;
  signal note_color            : std_logic_vector(23 downto 0) := (others => '0');

begin
  -- Latch frame tick
  process(clk, reset)
  begin
    if reset = '1' then
      frame_req <= '0';
    elsif rising_edge(clk) then
      if frame_tick = '1' then
        frame_req <= '1';
      elsif state = idle then
        frame_req <= '0';
      end if;
    end if;
  end process;

  -- SPI handshake with master
  process(clk, reset)
  begin
    if reset = '1' then
      spi_send <= '0';
      sending  <= '0';
    elsif rising_edge(clk) then
      if sending = '0' and spi_ready = '1' then
        spi_data  <= data_out;
        spi_bytes <= bytes_out;
        spi_send  <= '1';
        sending   <= '1';
      elsif sending = '1' and spi_ready = '0' then
        spi_send <= '0';
        sending  <= '0';
      end if;
    end if;
  end process;

  -- Main FSM: clear -> disable fill -> draw hitboxes -> re-enable fill -> draw notes
  process(clk, reset)
  begin
    if reset = '1' then
      state            <= idle;
      prev_state       <= idle;
      fill_enabled     <= '0';
      note_index       <= 0;
      draw_hitbox_lane <= 0;
    elsif rising_edge(clk) then
      case state is
        -- IDLE: reset counters and wait for frame tick
        when idle =>
          note_index       <= 0;
          draw_hitbox_lane <= 0;
          if frame_req = '1' then
            if fill_enabled = '0' then
              state <= fill_enable;
            else
              state <= clear_background;
            end if;
          end if;

        -- Enable fill once per cycle
        when fill_enable =>
          if sending = '0' and spi_ready = '1' then
            data_out     <= x"26" & x"01" & (79 downto 0 => '0');
            bytes_out    <= 2;
            fill_enabled <= '1';
            prev_state   <= fill_enable;
            state        <= wait_send;
          end if;

        -- Clear the entire screen
        when clear_background =>
          if sending = '0' and spi_ready = '1' then
            -- Correct Clear Window: cmd=0x25, col_start=0, row_start=0, col_end=95, row_end=63
            data_out   <= x"25" & x"00" & x"00" & x"5F" & x"3F" & (55 downto 0 => '0');
            bytes_out  <= 5;
            prev_state <= clear_background;
            state      <= wait_send;
          end if;

        when disable_fill =>
          if sending = '0' and spi_ready = '1' then
            data_out   <= x"26" & x"00" & (79 downto 0 => '0');
            bytes_out  <= 2;
            prev_state <= disable_fill;
            state      <= wait_send;
          end if;

        -- Draw hitbox outlines
        when draw_hitboxes =>
          if sending = '0' and spi_ready = '1' then
            current_x1 <= draw_hitbox_lane * lane_width;
            current_x2 <= (draw_hitbox_lane + 1) * lane_width - 1;
            current_y1 <= hitbox_y1;
            current_y2 <= hitbox_y2;
            data_out   <= x"22" &
                         std_logic_vector(to_unsigned(current_x1,8)) &
                         std_logic_vector(to_unsigned(current_y1,8)) &
                         std_logic_vector(to_unsigned(current_x2,8)) &
                         std_logic_vector(to_unsigned(current_y2,8)) &
                         color_white & color_black & x"00";
            bytes_out  <= 11;
            prev_state <= draw_hitboxes;
            state      <= wait_send;
          end if;

        -- Re-enable fill for notes
        when enable_notes_fill =>
          if sending = '0' and spi_ready = '1' then
            data_out  <= x"26" & x"01" & (79 downto 0 => '0');
            bytes_out <= 2;
            prev_state<= enable_notes_fill;
            state     <= wait_send;
          end if;

        -- Load each active note
        when load_note =>
          if note_index < 16 then
            if notes_active(note_index) = '1' then
              lane <= to_integer(unsigned(notes_lane(note_index*2+1 downto note_index*2)));
              ypos <= to_integer(unsigned(notes_y(note_index*8+7 downto note_index*8)));
              case lane is
                when 0 => note_color <= color_red;
                when 1 => note_color <= color_blue;
                when 2 => note_color <= color_green;
                when others => note_color <= color_white;
              end case;
              current_x1 <= lane * lane_width + 2;
              current_x2 <= (lane + 1) * lane_width - 2;
              current_y1 <= ypos;
              current_y2 <= ypos + 2;
              prev_state <= load_note;
              state      <= draw_rectangle;
            else
              note_index <= note_index + 1;
            end if;
          else
            state <= idle;
          end if;

        -- Draw the note
        when draw_rectangle =>
          if sending = '0' and spi_ready = '1' then
            data_out   <= x"22" &
                         std_logic_vector(to_unsigned(current_x1,8)) &
                         std_logic_vector(to_unsigned(current_y1,8)) &
                         std_logic_vector(to_unsigned(current_x2,8)) &
                         std_logic_vector(to_unsigned(current_y2,8)) &
                         note_color & note_color & x"00";
            bytes_out  <= 11;
            prev_state <= draw_rectangle;
            state      <= wait_send;
          end if;

        -- Wait for SPI, then next state
        when wait_send =>
          if sending = '0' and spi_ready = '1' then
            case prev_state is
              when fill_enable      => state <= clear_background;
              when clear_background => state <= disable_fill;
              when disable_fill     => state <= draw_hitboxes;
              when draw_hitboxes    =>
                if draw_hitbox_lane < 2 then
                  draw_hitbox_lane <= draw_hitbox_lane + 1;
                  state            <= draw_hitboxes;
                else
                  draw_hitbox_lane <= 0;
                  state            <= enable_notes_fill;
                end if;
              when enable_notes_fill=> state <= load_note;
              when load_note        => null;
              when draw_rectangle   =>
                note_index <= note_index + 1;
                state      <= load_note;
              when others           => state <= idle;
            end case;
          end if;

        when others =>
          state <= idle;
      end case;
    end if;
  end process;
end architecture behavioral;
