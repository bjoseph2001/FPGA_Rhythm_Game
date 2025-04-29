library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity notecontroller is
  generic (
    NUM_NOTES       : integer := 16;     -- Total available note slots
    SCREEN_HEIGHT   : integer := 64;
    SPAWN_INTERVAL_FRAMES : integer := 30 -- Spawn a new note every X frames (e.g., 30 frames = 0.5 seconds at 60Hz)
  );
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    frame_tick    : in  std_logic; -- Input tick at the desired frame rate (e.g., 60Hz)
    start         : in  std_logic; -- Signal to reset/initiate spawning sequence
    enable        : in  std_logic; -- Represents 'playing': Enables movement & spawning
    hit_note_mask : in  std_logic_vector(NUM_NOTES - 1 downto 0); -- Indicates which notes were hit
    notes_y       : out std_logic_vector(NUM_NOTES * 8 - 1 downto 0);
    notes_lane    : out std_logic_vector(NUM_NOTES * 2 - 1 downto 0);
    notes_active  : out std_logic_vector(NUM_NOTES - 1 downto 0)
  );
end entity notecontroller;

architecture behavioral of notecontroller is

  -- Note record
  type note_t is record
    y      : integer range -1 to SCREEN_HEIGHT; -- y=-1 when inactive but ready
    lane   : integer range 0 to 2;
    active : std_logic;
  end record note_t;

  -- Note array
  type note_array_t is array(0 to NUM_NOTES - 1) of note_t;
  signal notes : note_array_t;


  signal spawn_timer    : integer range 0 to SPAWN_INTERVAL_FRAMES := 0;
  signal next_inactive_note_idx : integer range 0 to NUM_NOTES - 1 := 0; 

  -- LFSR for random note generation
  signal lfsr : std_logic_vector(7 downto 0) := x"A3"; 

  -- Hold next states
  signal spawn_timer_next : integer range 0 to SPAWN_INTERVAL_FRAMES;
  signal lfsr_next : std_logic_vector(7 downto 0);
  signal next_inactive_note_idx_next : integer range 0 to NUM_NOTES - 1;


begin

  process (clk, reset)
    variable current_check_idx : integer range 0 to NUM_NOTES - 1;
    variable found_slot : boolean;
    variable feedback : std_logic;
    variable notes_var : note_array_t;
  begin
    if (reset = '1') then
      -- Initialize all notes to inactive state on reset
      for i in 0 to NUM_NOTES - 1 loop
        notes(i).y      <= -1;
        notes(i).lane   <= i mod 3;
        notes(i).active <= '0';
      end loop;
      spawn_timer <= 0;
      lfsr <= x"A3";
      next_inactive_note_idx <= 0;

    elsif (rising_edge(clk)) then
      -- Default assignments: Hold current state unless updated below
      notes_var := notes;
      spawn_timer_next <= spawn_timer;
      lfsr_next <= lfsr;
      next_inactive_note_idx_next <= next_inactive_note_idx;

      if(start = '1')then
          -- Reset all notes to inactive when start is pressed
          for i in 0 to NUM_NOTES - 1 loop
              notes_var(i).y      := -1;
              notes_var(i).active := '0';
          end loop;
          spawn_timer_next <= 0; -- Reset timer 
          next_inactive_note_idx_next <= 0; -- Reset search index
          lfsr_next <= x"A3"; -- Reset LFSR
      else
          -- Handle note movement and deactivation on frame_tick if playing
          if ((enable = '1') and (frame_tick = '1')) then
              -- Movement/Deactivation loop
              for i in 0 to NUM_NOTES - 1 loop
                  if (notes(i).active = '1') then -- Check registered state
                      -- Deactivate if hit
                      if (hit_note_mask(i) = '1') then
                          notes_var(i).active := '0';
                          notes_var(i).y      := -1;
                      -- Move note down
                      else
                          notes_var(i).y := notes(i).y + 1;
                          -- Deactivate if off-screen
                          if (notes_var(i).y >= SCREEN_HEIGHT) then
                              notes_var(i).active := '0';
                              notes_var(i).y      := -1;
                          end if;
                      end if;
                  end if;
              end loop; 
          end if;

          -- Spawns notes when playing
          if((enable = '1') and (frame_tick = '1')) then
              if(spawn_timer > 0)then
                  spawn_timer_next <= spawn_timer - 1; 
              else
                  -- Timer reached zero, try to spawn a note
                  spawn_timer_next <= SPAWN_INTERVAL_FRAMES; 
                  -- Find the next available inactive note slot using the intermediate state (notes_var)
                  found_slot := false;
                  current_check_idx := next_inactive_note_idx; -- Start searching from where we left off

                  for i in 0 to NUM_NOTES - 1 loop
                     -- Check notes_var which includes updates from movement/deactivation in this cycle
                     if((not found_slot) and (notes_var(current_check_idx).active = '0')) then
                         -- If inactive slot, note placed here in intermediate state
                         notes_var(current_check_idx).y      := 0; 
                         -- Use lower 2 bits of LFSR for lane 0, 1, 2. Remap 3 to 2.
                         case lfsr(1 downto 0) is
                             when "00"   => notes_var(current_check_idx).lane := 0;
                             when "01"   => notes_var(current_check_idx).lane := 1;
                             when "10"   => notes_var(current_check_idx).lane := 2;
                             when "11"   => notes_var(current_check_idx).lane := 2; -- Map 3 to 2
                             when others => notes_var(current_check_idx).lane := 0;
                         end case;
                         notes_var(current_check_idx).active := '1';
                         found_slot := true;
                         next_inactive_note_idx_next <= (current_check_idx + 1) mod NUM_NOTES;
                     end if;
                     current_check_idx := (current_check_idx + 1) mod NUM_NOTES;
                  end loop; 

                  -- If a slot found, update LFSR for next random lane
                  if(found_slot) then
                      feedback := lfsr(7) xor lfsr(5) xor lfsr(4) xor lfsr(3);
                      lfsr_next <= lfsr(6 downto 0) & feedback;
                  end if;
                  -- If no slot found, LFSR doesn't update this cycle
              end if;
            elsif(enable = '0') then
              --Reset timer if game not in playing state
              spawn_timer_next <= 0;
          end if; 
      end if;
      notes <= notes_var;
      spawn_timer <= spawn_timer_next;
      lfsr <= lfsr_next;
      next_inactive_note_idx <= next_inactive_note_idx_next;
    end if; 
  end process;

  process(clk, reset)
  begin
    if (reset = '1') then
      notes_y      <= (others => '0');
      notes_lane   <= (others => '0');
      notes_active <= (others => '0');
    elsif(rising_edge(clk)) then
      for i in 0 to NUM_NOTES - 1 loop
         -- Output 0 if note is inactive (y=-1), otherwise output actual y
         if notes(i).active = '1' then
             -- Check if y is valid before converting (should be >= 0 if active)
             if notes(i).y >= 0 then
                notes_y(i * 8 + 7 downto i * 8) <= std_logic_vector(to_unsigned(notes(i).y, 8));
             else
                notes_y(i * 8 + 7 downto i * 8) <= (others => '0'); -- Should not happen if active is '1'
             end if;
             notes_active(i) <= '1';
         else
             notes_y(i * 8 + 7 downto i * 8) <= (others => '0'); -- Output 0 for Y if inactive
             notes_active(i) <= '0';
         end if;
         -- Always output the lane, even if inactive (display controller ignores inactive notes)
         notes_lane(i * 2 + 1 downto i * 2) <= std_logic_vector(to_unsigned(notes(i).lane, 2));
      end loop;
    end if;
  end process;

end architecture behavioral;
