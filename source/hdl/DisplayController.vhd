library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity displaycontroller is
  port (
    clk          : in    std_logic; -- Main system clock (e.g., 100MHz)
    reset        : in    std_logic;
    frame_tick   : in    std_logic;
    notes_y      : in    std_logic_vector(16 * 8 - 1 downto 0);
    notes_lane   : in    std_logic_vector(16 * 2 - 1 downto 0);
    notes_active : in    std_logic_vector(15 downto 0);

    -- SPI Interface --
    spi_data  : out   std_logic_vector(95 downto 0);
    spi_bytes : out   integer;
    spi_send  : out   std_logic;
    spi_ready : in    std_logic -- Signal from SPI_master indicating it's ready for a command
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
  constant lane_width            : integer := 32;
  constant hitbox_y1             : integer := 54;
  constant hitbox_y2             : integer := 62;
  constant screen_w              : integer := 96;
  constant screen_h              : integer := 64;
  constant max_col               : natural := screen_w - 1; -- 95
  constant max_row               : natural := screen_h - 1; -- 63
  constant note_height           : natural := 3;            -- Height of note
  constant note_erase_lookbehind : natural := 1;            -- How many pixels behind the current pos to erase

  -- FSM states 

  type displayfsm is (
    idle,
    disable_fill_init,   -- Ensure fill is off before clearing
    clear_background,    -- Use 0x25 Clear Window command
    draw_hitboxes,       -- Draw hitboxes first (fill should be off)
    enable_notes_fill,   -- Enable fill before erasing/drawing notes
    load_note,
    erase_prev_note_pos, -- Erase where the note was *before* drawing
    draw_rectangle,      -- Draw note in current position
    wait_send            -- Waits for SPI transaction to finish
  );

  signal state, prev_state : displayfsm := idle;

  -- Internal signals
  signal frame_req        : std_logic                     := '0';
  signal sending          : std_logic                     := '0';             
  signal note_index       : integer range 0 to 15         := 0;
  signal draw_hitbox_lane : integer range 0 to 2          := 0;
  signal data_out         : std_logic_vector(95 downto 0) := (others => '0'); 
  signal bytes_out        : integer                       := 0;               
  -- Signals to store current note parameters between erase and draw states
  signal current_note_x1    : integer range 0 to max_col                           := 0;
  signal current_note_x2    : integer range 0 to max_col                           := 0;
  signal current_note_y     : integer range -note_height to screen_h + note_height := 0;
  signal current_note_color : std_logic_vector(23 downto 0)                        := (others => '0');

begin

  -- Latch frame_tick to create a frame request signal
  process (clk, reset) is
  begin

    if (reset = '1') then
      frame_req <= '0';
    elsif rising_edge(clk) then
      if (frame_tick = '1') then
        frame_req <= '1';
      elsif (state = idle) then
        frame_req <= '0';
      end if;
    end if;

  end process;

  -- SPI handshake logic (controls spi_send and monitors spi_ready)
  process (clk, reset) is
  begin

    if (reset = '1') then
      spi_send  <= '0';
      sending   <= '0';
      spi_data  <= (others => '0');
      spi_bytes <= 0;
    elsif rising_edge(clk) then
      spi_send <= '0';
      if (sending = '0' and spi_ready = '1' and state /= idle and state /= wait_send and state /= load_note) then
        spi_data  <= data_out;
        spi_bytes <= bytes_out;
        spi_send  <= '1';
        sending   <= '1';
      elsif (sending = '1' and spi_ready = '0') then
        sending <= '0';
      end if;
      if (sending = '1' and spi_ready = '1') then
        spi_send <= '1';
      end if;
    end if;

  end process;

  -- Main FSM: Controls the drawing sequence and prepares data in data_out/bytes_out
  process (clk, reset) is


    variable erase_y1, erase_y2 : integer range -note_erase_lookbehind to max_row + 1;
    variable draw_y1, draw_y2   : integer range 0 to max_row;
    variable temp_x1, temp_x2   : integer range 0 to max_col;
    -- Variables for load_note calculation
    variable lane       : integer range 0 to 2;
    variable ypos       : integer range -note_height to screen_h + note_height;
    variable x1         : integer range -2 to max_col + 2;
    variable x2         : integer range -2 to max_col + 2;
    variable temp_color : std_logic_vector(23 downto 0);

  begin

    if (reset = '1') then
      state              <= idle;
      prev_state         <= idle;
      note_index         <= 0;
      draw_hitbox_lane   <= 0;
      data_out           <= (others => '0');
      bytes_out          <= 0;
      current_note_x1    <= 0;
      current_note_x2    <= 0;
      current_note_y     <= 0;
      current_note_color <= (others => '0');
    elsif(rising_edge(clk)) then

      case state is

        -- IDLE: Wait for a frame request
        when idle =>

          note_index       <= 0;
          draw_hitbox_lane <= 0;
          if (frame_req = '1') then
            state <= disable_fill_init;                                                         -- Start frame sequence
          end if;

        -- Disable fill before clearing screen AND before drawing hitboxes
        when disable_fill_init =>

          if ((sending = '0') and (spi_ready = '1')) then
            data_out   <= x"26" & x"00" & (79 downto 0 => '0');                                 -- Pad to 96 bits
            bytes_out  <= 2;
            prev_state <= disable_fill_init;
            state      <= wait_send;
          end if;

        -- Clear the entire background using Clear Window command
        when clear_background =>

          if ((sending = '0') and (spi_ready = '1'))  then
            data_out   <= x"25" & x"00" & x"00" & x"5F" & x"3F" & (55 downto 0 => '0');         -- Pad to 96 bits
            bytes_out  <= 5;
            prev_state <= clear_background;
            state      <= wait_send;
          end if;

        -- Draw hitbox outlines 
        when draw_hitboxes =>

          if ((sending = '0') and (spi_ready = '1'))  then
            -- Calculate coordinates using temporary variables
            temp_x1 := draw_hitbox_lane * lane_width;
            temp_x2 := (draw_hitbox_lane + 1) * lane_width - 1;
            if (temp_x2 > max_col) then
              temp_x2 := max_col;
            end if;
            draw_y1 := hitbox_y1;
            draw_y2 := hitbox_y2;

            data_out   <= x"22" &
                          std_logic_vector(to_unsigned(temp_x1, 8)) &
                          std_logic_vector(to_unsigned(draw_y1, 8)) &
                          std_logic_vector(to_unsigned(temp_x2, 8)) &
                          std_logic_vector(to_unsigned(draw_y2, 8)) &
                          color_white & color_black & x"00";                                    -- Pad to 96 bits
            bytes_out  <= 11;
            prev_state <= draw_hitboxes;
            state      <= wait_send;
          end if;

        -- Enable fill for drawing/erasing notes (Fill should be ON after this)
        when enable_notes_fill =>

          if ((sending = '0') and (spi_ready = '1'))  then
            data_out   <= x"26" & x"01" & (79 downto 0 => '0');                                 -- Pad to 96 bits
            bytes_out  <= 2;
            prev_state <= enable_notes_fill;
            state      <= wait_send;
          end if;

        -- Load data for the next active note 
        when load_note =>

          --Check if all notes processed 
          if (note_index >= 16) then
            state <= idle;                                                                      -- *** FRAME DONE, go back to idle ***
          elsif (notes_active(note_index) = '1') then
            -- Active note found, calculate parameters using process variables
            lane := to_integer(unsigned(notes_lane(note_index * 2 + 1 downto note_index * 2)));
            ypos := to_integer(unsigned(notes_y(note_index * 8 + 7 downto note_index * 8)));
            x1   := lane * lane_width + 2;
            x2   := (lane + 1) * lane_width - 2;

            case lane is

              when 0 => temp_color := color_red;
              when 1 => temp_color := color_blue;
              when 2 => temp_color := color_green;
              when others => temp_color := color_white; --fallback if no valid lane value is found

            end case;

            -- Basic clamping for x coordinates
            if (x1 < 0) then
              x1 := 0;
            end if;
            if (x2 > max_col) then
              x2 := max_col;
            end if;

            -- Check if note is potentially visible before trying to erase/draw
            if ((ypos < screen_h + note_height) and (ypos >= -note_height) and (x1 <= x2)) then
              -- Store calculated & clamped values 
              current_note_x1    <= x1;
              current_note_x2    <= x2;
              current_note_y     <= ypos;                                                       -- Store current Y
              current_note_color <= temp_color;
              state              <= erase_prev_note_pos;                                        -- *** Go to erase state FIRST ***
            else
              -- Note is too far off-screen or invalid, skip erasing/drawing 
              note_index <= note_index + 1;
              state      <= load_note;                                                          -- Check next note index
            end if;
          else
            -- Note is not active, check the next one
            note_index <= note_index + 1;
            state      <= load_note;                                                            -- Stay in load_note state to check next index
          end if;

        -- Erase the area where the note was in the previous frame(s)
        when erase_prev_note_pos =>

          if ((sending = '0') and (spi_ready = '1'))  then
            -- Calculate erase coordinates based on stored current position using process variables
            erase_y1 := current_note_y - note_erase_lookbehind;
            erase_y2 := current_note_y - 1;                                                     -- Erase up to the pixel just before the current note starts

            -- Clamp erase coordinates
            if (erase_y1 < 0) then
              erase_y1 := 0;
            end if;
            if (erase_y2 < 0) then
              erase_y2 := -1;
            end if;                                                                             -- Make it invalid if start is off screen
            if (erase_y1 > max_row) then
              erase_y1 := max_row + 1;
            end if;                                                                             -- Make it invalid
            if (erase_y2 > max_row) then
              erase_y2 := max_row;
            end if;

            -- Only send erase command if erase area is valid and on screen
            if (erase_y1 <= erase_y2 and erase_y1 <= max_row and erase_y2 >= 0) then
              data_out   <= x"22" &
                            std_logic_vector(to_unsigned(current_note_x1, 8)) &
                            std_logic_vector(to_unsigned(erase_y1, 8)) &
                            std_logic_vector(to_unsigned(current_note_x2, 8)) &
                            std_logic_vector(to_unsigned(erase_y2, 8)) &
                            color_black & color_black & x"00";                                  -- Pad to 96 bits
              bytes_out  <= 11;
              prev_state <= erase_prev_note_pos;
              state      <= wait_send;
            else
              -- Erase area is off-screen or invalid, skip straight to drawing the current note
              state <= draw_rectangle;
            end if;
          end if;

        -- Draw the loaded note rectangle 
        when draw_rectangle =>

          if ((sending = '0') and (spi_ready = '1'))  then
            -- Calculate note's current bounding box using process variables
            draw_y1 := current_note_y;
            draw_y2 := current_note_y + note_height - 1;

            -- Clamp Y coordinates for drawing
            if (draw_y1 < 0) then
              draw_y1 := 0;
            end if;
            if (draw_y2 > max_row) then
              draw_y2 := max_row;
            end if;

            -- Only draw if the rectangle is valid and at least partially on screen
            if ((draw_y1 <= draw_y2) and (draw_y1 <= max_row) and (draw_y2 >= 0)) then
              -- Prepare data (11 bytes + 1 padding byte = 96 bits)
              data_out   <= x"22" &
                            std_logic_vector(to_unsigned(current_note_x1, 8)) &
                            std_logic_vector(to_unsigned(draw_y1, 8)) &
                            std_logic_vector(to_unsigned(current_note_x2, 8)) &
                            std_logic_vector(to_unsigned(draw_y2, 8)) &
                            current_note_color & current_note_color & x"00";                    -- Pad to 96 bits
              bytes_out  <= 11;
              prev_state <= draw_rectangle;
              state      <= wait_send;                                                          -- Go wait for SPI, then load next note
            else
              -- Note is completely off-screen now, skip drawing/erasing and move to next note
              note_index <= note_index + 1;
              state      <= load_note;
            end if;
          end if;

        -- REMOVED disable_fill_redraw and redraw_hitboxes states

        -- Wait for the current SPI transaction to complete
        when wait_send =>

          if ((sending = '0') and (spi_ready = '1'))  then

            case prev_state is

              -- Initial part of frame
              when disable_fill_init => state <= clear_background;
              when clear_background =>  state <= draw_hitboxes;
              when draw_hitboxes =>                                      -- After drawing a hitbox (first pass)
                if (draw_hitbox_lane < 2) then
                  draw_hitbox_lane <= draw_hitbox_lane + 1;
                  state            <= draw_hitboxes;
                else
                  draw_hitbox_lane <= 0;                                  -- Reset counter for next frame
                  state            <= enable_notes_fill;                  -- Done first pass, enable fill for notes
                end if;

              when enable_notes_fill => state <= load_note;
              when erase_prev_note_pos => state <= draw_rectangle;                                                        
              when draw_rectangle =>      
                note_index <= note_index + 1;
                state      <= load_note;
              when others => state <= idle;
            end case;
          end if;
        when others => state <= idle;
      end case;
    end if;
  end process;
end architecture behavioral;
