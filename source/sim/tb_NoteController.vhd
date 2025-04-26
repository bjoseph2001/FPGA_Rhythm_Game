library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_notecontroller is
end tb_notecontroller;

architecture sim of tb_notecontroller is
    constant NUM_NOTES     : integer := 16;
    constant SCREEN_HEIGHT : integer := 64;

    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal frame_tick     : std_logic := '0';
    signal start          : std_logic := '0';
    signal enable         : std_logic := '0';
    signal hit_note_mask  : std_logic_vector(NUM_NOTES - 1 downto 0) := (others => '0');
    signal notes_y        : std_logic_vector(NUM_NOTES * 8 - 1 downto 0);
    signal notes_lane     : std_logic_vector(NUM_NOTES * 2 - 1 downto 0);
    signal notes_active   : std_logic_vector(NUM_NOTES - 1 downto 0);

begin

    uut: entity work.notecontroller
        generic map (
            num_notes => NUM_NOTES,
            screen_height => SCREEN_HEIGHT
        )
        port map (
            clk => clk,
            reset => reset,
            frame_tick => frame_tick,
            start => start,
            enable => enable,
            hit_note_mask => hit_note_mask,
            notes_y => notes_y,
            notes_lane => notes_lane,
            notes_active => notes_active
        );

    -- Clock generation
    clk_process: process
    begin
        while true loop
            clk <= not clk;
            wait for 5 ns;
        end loop;
    end process;

    -- Stimulus process
    stimulus: process
    begin
        wait for 20 ns;
        reset <= '0';
        wait for 20 ns;
        start <= '1';
        wait for 10 ns;
        start <= '0';

        -- Begin moving notes with enable + frame_tick
        wait for 50 ns;
        enable <= '1';
        for i in 0 to 5 loop
            frame_tick <= '1';
            wait for 10 ns;
            frame_tick <= '0';
            wait for 100 ns;
        end loop;

        -- Simulate hitting a note
        hit_note_mask(0) <= '1';
        frame_tick <= '1';
        wait for 10 ns;
        frame_tick <= '0';
        hit_note_mask(0) <= '0';

        wait;
    end process;

end sim;
