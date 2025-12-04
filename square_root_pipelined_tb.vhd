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

    -- Array of test values
    type nat_array_t is array (natural range <>) of natural;
    constant TEST_VALS : nat_array_t := (
        0,
        1,
        512,
        5499030,
        1194877489
    );
    constant NUM_TESTS : natural := TEST_VALS'length;

    -- Integer square root (floor) for checking
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
        -- Streaming phase: feed inputs every clock while collecting outputs
        ----------------------------------------------------------------------
        -- We stop when we've *checked* all outputs (idx_out = NUM_TESTS)
        while idx_out < NUM_TESTS loop
            -- Wait for next clock
            wait until rising_edge(clk);

            -- 1) Feed next input if there are any left
            if idx_in < NUM_TESTS then
                A_nat := TEST_VALS(idx_in);
                A     <= std_logic_vector(to_unsigned(A_nat, A'length));
                start <= '1';  -- valid input this cycle
                idx_in := idx_in + 1;
            else
                start <= '0';  -- no more inputs, let pipeline drain
            end if;

            -- 2) Check if an output is ready this cycle
            if finished = '1' then
                got_sqrt := to_integer(unsigned(result));
                A_nat    := TEST_VALS(idx_out);
                exp_sqrt := isqrt(A_nat);

                -- Report for this test
                report "Test #" & integer'image(idx_out) &
                       " A=" & integer'image(A_nat) &
                       " expected sqrt=" & integer'image(exp_sqrt) &
                       " got=" & integer'image(got_sqrt)
                       severity note;

                -- Check and count errors
                if got_sqrt /= exp_sqrt then
                    error_cnt := error_cnt + 1;
                    report "MISMATCH for A=" & integer'image(A_nat) &
                           " expected " & integer'image(exp_sqrt) &
                           " got "      & integer'image(got_sqrt)
                           severity warning;
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
