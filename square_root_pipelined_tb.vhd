library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_pipelined_tb is
end entity;

architecture tb of square_root_pipelined_tb is
    constant N_TB    : positive := 32;
    constant CLK_PER : time     := 10 ns;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal A        : std_logic_vector(2*N_TB-1 downto 0) := (others => '0');
    signal result   : std_logic_vector(N_TB-1 downto 0);
    signal finished : std_logic;

    --------------------------------------------------------------------------
    -- Test values (same set as non-pipelined TB)
    --------------------------------------------------------------------------
    type slv_array_t is array (natural range <>) of std_logic_vector(2*N_TB-1 downto 0);

    constant TEST_VALS : slv_array_t := (
        std_logic_vector(to_unsigned(0,           2*N_TB)),
        std_logic_vector(to_unsigned(1,           2*N_TB)),
        std_logic_vector(to_unsigned(3,           2*N_TB)),
        std_logic_vector(to_unsigned(15,          2*N_TB)),
        std_logic_vector(to_unsigned(127,         2*N_TB)),
        std_logic_vector(to_unsigned(512,         2*N_TB)),
        std_logic_vector(to_unsigned(5499030,     2*N_TB)),
        std_logic_vector(to_unsigned(1194877489,  2*N_TB)),
        x"00000000FFFFFFFF"  -- 4294967295 = 2^32 - 1
    );

    constant NUM_TESTS : natural := TEST_VALS'length;

    --------------------------------------------------------------------------
    -- Gaps (bubbles) after each input, in clock cycles
    --  e.g. after sending TEST_VALS(1) we wait 1 idle cycle,
    --       after TEST_VALS(2) we wait 2 idle cycles, etc.
    --------------------------------------------------------------------------
    type nat_array_t is array (natural range <>) of natural;
    constant GAPS : nat_array_t(0 to NUM_TESTS-1) := (
        0,  -- after A0
        1,  -- after A1
        2,  -- after A2
        3,  -- after A3
        0,  -- after A4
        1,  -- after A5
        2,  -- after A6
        3,  -- after A7
        0   -- after A8 (last one, gap only creates bubbles while draining)
    );

    --------------------------------------------------------------------------
    -- Integer square root (for values that fit in integer)
    --------------------------------------------------------------------------
    function isqrt(n : natural) return natural is
        variable r : natural := 0;
    begin
        while (r+1)*(r+1) <= n loop
            r := r + 1;
        end loop;
        return r;
    end function;

begin

    --------------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PER/2;
            clk <= '1';
            wait for CLK_PER/2;
        end loop;
    end process;

    --------------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------------
    uut : entity work.square_root_a4
        generic map (
            N => N_TB
        )
        port map (
            clk      => clk,
            reset    => reset,
            start    => start,
            A        => A,
            result   => result,
            finished => finished
        );

    --------------------------------------------------------------------------
    -- Stimulus + pipeline-style checking
    --------------------------------------------------------------------------
    stim_proc : process
        variable idx_in    : natural := 0;  -- how many inputs sent
        variable idx_out   : natural := 0;  -- how many outputs checked
        variable A_nat     : natural;
        variable exp_sqrt  : natural;
        variable got_sqrt  : natural;
        variable error_cnt : natural := 0;

        -- remaining “bubble” cycles before we send the next input
        variable gap_cnt   : natural := 0;
    begin
        ----------------------------------------------------------------------
        -- Reset phase
        ----------------------------------------------------------------------
        reset <= '1';
        start <= '0';
        wait for 3*CLK_PER;
        reset <= '0';
        wait for CLK_PER;

        ----------------------------------------------------------------------
        -- Streaming phase: feed inputs with bubbles between them,
        -- while collecting outputs whenever finished = '1'.
        ----------------------------------------------------------------------
        while idx_out < NUM_TESTS loop
            -- Wait for next clock
            wait until rising_edge(clk);

            ------------------------------------------------------------------
            -- 1) Handle input side (inject bubbles using gap_cnt)
            ------------------------------------------------------------------
            if idx_in < NUM_TESTS then
                if gap_cnt = 0 then
                    -- Send a new input this cycle
                    A     <= TEST_VALS(idx_in);
                    start <= '1';

                    -- Set how many idle cycles we want AFTER this input
                    gap_cnt := GAPS(idx_in);

                    idx_in := idx_in + 1;
                else
                    -- Bubble: no new input this cycle
                    start   <= '0';
                    gap_cnt := gap_cnt - 1;
                end if;
            else
                -- All inputs already sent: keep start low, let pipeline drain
                start <= '0';
            end if;

            ------------------------------------------------------------------
            -- 2) Handle output side (check whenever finished = '1')
            ------------------------------------------------------------------
            if finished = '1' then
                got_sqrt := to_integer(unsigned(result));

                -- Expected sqrt:
                -- For the LAST big test, avoid integer overflow:
                --   value is 2^32 - 1, so sqrt = 2^16 - 1 = 65535
                if idx_out = TEST_VALS'high then
                    exp_sqrt := 2**(N_TB/2) - 1;  -- safe: 65535 for N_TB=32
                else
                    A_nat    := to_integer(unsigned(TEST_VALS(idx_out)));
                    exp_sqrt := isqrt(A_nat);
                end if;

                -- Report for this test
                if idx_out = TEST_VALS'high then
                    report "Test #" & integer'image(idx_out) &
                           " A = 4294967295" &
                           " expected sqrt = " & integer'image(exp_sqrt) &
                           " got = " & integer'image(got_sqrt)
                           severity note;
                else
                    report "Test #" & integer'image(idx_out) &
                           " A = " & integer'image(A_nat) &
                           " expected sqrt = " & integer'image(exp_sqrt) &
                           " got = " & integer'image(got_sqrt)
                           severity note;
                end if;

                -- Check and count errors
                if got_sqrt /= exp_sqrt then
                    error_cnt := error_cnt + 1;

                    if idx_out = TEST_VALS'high then
                        report "MISMATCH for A = 4294967295" &
                               " expected " & integer'image(exp_sqrt) &
                               " got "      & integer'image(got_sqrt)
                               severity warning;
                    else
                        report "MISMATCH for A = " & integer'image(A_nat) &
                               " expected " & integer'image(exp_sqrt) &
                               " got "      & integer'image(got_sqrt)
                               severity warning;
                    end if;
                end if;

                idx_out := idx_out + 1;
            end if;
        end loop;

        ----------------------------------------------------------------------
        -- Final summary
        ----------------------------------------------------------------------
        if error_cnt = 0 then
            report "SUCCESS: All tests passed (0 mismatches)" severity note;
        else
            report "FAILED: " & integer'image(error_cnt) &
                   " mismatches detected" severity error;
        end if;

        assert false report "End of simulation" severity failure;
        wait;
    end process;

end architecture tb;
