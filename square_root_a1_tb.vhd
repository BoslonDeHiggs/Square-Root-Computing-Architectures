library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a1_tb is
end entity;

architecture tb of square_root_a1_tb is
    -- Choose a smaller N for simulation speed
    constant N_TB    : positive := 8;
    constant CLK_PER : time     := 10 ns;
    constant MAX_A   : natural  := 200;  -- max value to test

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal A        : std_logic_vector(2*N_TB-1 downto 0) := (others => '0');
    signal result   : std_logic_vector(N_TB-1 downto 0);
    signal finished : std_logic;

    -- Integer square root (floor) for checking
    function isqrt(n : natural) return natural is
        variable r : natural := 0;
    begin
        -- simple O(sqrt(n)) loop is fine for small MAX_A
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
    uut : entity work.square_root_a1
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
    -- Stimulus
    --------------------------------------------------------------------------
    stim_proc : process
        variable A_nat   : natural;
        variable exp_sqrt: natural;
        variable got_sqrt: natural;
    begin
        -- Initial reset
        reset <= '1';
        start <= '0';
        wait for 3*CLK_PER;
        reset <= '0';
        wait for CLK_PER;

        -- Loop over a set of test values
        for i in 0 to MAX_A loop
            A_nat := i;

            -- Apply input A (2*N bits)
            A <= std_logic_vector(to_unsigned(A_nat, A'length));

            -- Start pulse
            start <= '1';
            wait for CLK_PER;
            start <= '0';

            -- Wait for finished signal
            wait until finished = '1';

            -- Sample result
            got_sqrt := to_integer(unsigned(result));
            exp_sqrt := isqrt(A_nat);

            -- Report
            report "Test A=" & integer'image(A_nat) &
                   " expected sqrt=" & integer'image(exp_sqrt) &
                   " got=" & integer'image(got_sqrt);

            -- Check
            assert got_sqrt = exp_sqrt
                report "MISMATCH for A=" & integer'image(A_nat) &
                       " expected " & integer'image(exp_sqrt) &
                       " got "      & integer'image(got_sqrt)
                severity error;

            -- Give 1 extra cycle before next test
            wait for CLK_PER;
        end loop;

        report "All tests completed" severity note;
        wait;  -- stop simulation
    end process;

end architecture tb;
