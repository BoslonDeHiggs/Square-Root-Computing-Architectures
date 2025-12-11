library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_tb is
end entity;

architecture tb of square_root_tb is
    constant N_TB    : positive := 32;
    constant CLK_PER : time     := 10 ns; -- 10ns clock period - 100MHz Freq

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal start    : std_logic := '0';
    signal A        : std_logic_vector(2*N_TB-1 downto 0) := (others => '0');
    signal result   : std_logic_vector(N_TB-1 downto 0);
    signal finished : std_logic;

    -- Array of test values
    type nat_array_t is array (natural range <>) of unsigned(2*N_TB-1 downto 0);
    constant TEST_VALS : nat_array_t := (
        to_unsigned(0, 2*N_TB),
        to_unsigned(1, 2*N_TB),
        to_unsigned(3, 2*N_TB),
        to_unsigned(15, 2*N_TB),
        to_unsigned(127, 2*N_TB),
        to_unsigned(512, 2*N_TB),
        to_unsigned(5499030, 2*N_TB),
        to_unsigned(1194877489, 2*N_TB),
        x"00000000FFFFFFFF" -- 4294967295 = 2^32 - 1
    );

    -- Integer square root function for checking values
    function isqrt(n : unsigned(2*N_TB-1 downto 0)) return natural is
        variable r   : unsigned(N_TB-1 downto 0) := (others => '0');
        variable one : unsigned(N_TB-1 downto 0) := (others => '0');
        variable rsq : unsigned(2*N_TB-1 downto 0);
    begin
        one(0) := '1';  -- constant 1 as unsigned

        -- while (r+1)^2 <= n
        loop
            rsq := (r + one) * (r + one);  -- 64-bit result
            exit when rsq > n;
            r := r + one;
        end loop;

        -- r is small (sqrt), safe to convert to INTEGER/NATURAL
        return to_integer(r);
    end;

begin

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PER/2;
            clk <= '1';
            wait for CLK_PER/2;
        end loop;
    end process;

    -- Architecture to be tested
    uut : entity work.square_root_a3
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

    -- Stimuli generation and checking
    stim_proc : process
        variable A_nat     : unsigned(2*N_TB-1 downto 0);
        variable exp_sqrt  : natural;
        variable got_sqrt  : natural;
        variable error_cnt : natural := 0;
    begin
        -- Initial reset
        reset <= '1';
        start <= '0';
        wait for 3*CLK_PER;
        reset <= '0';
        wait for CLK_PER;

        -- Loop over test values
        for idx in TEST_VALS'range loop
            A_nat := TEST_VALS(idx);

            -- Apply input A
            A <= std_logic_vector(A_nat);

            -- Start pulse
            start <= '1';

            -- Wait for finished signal
            wait until finished = '1';
            wait for CLK_PER;

            start <= '0';

            -- Sample result
            got_sqrt := to_integer(unsigned(result));
            exp_sqrt := isqrt(A_nat);

            -- Report for this test
            report " expected sqrt=" & integer'image(exp_sqrt) &
                   " got=" & integer'image(got_sqrt)
                   severity note;

            -- Check and count errors
            if got_sqrt /= exp_sqrt then
                error_cnt := error_cnt + 1;
                report " expected " & integer'image(exp_sqrt) &
                       " got "      & integer'image(got_sqrt)
                       severity warning;
            end if;

            -- Small gap before next test
            wait for CLK_PER;
        end loop;

        -- Final summary
        if error_cnt = 0 then
            report "SUCCESS: All tests passed (0 mismatches)" severity note;
        else
            report "FAILED: " & integer'image(error_cnt) &
                   " mismatches detected" severity error;
        end if;

        -- Forcefully stop simulation
        assert false report "End of simulation" severity failure;
        wait;  
    end process;

end architecture tb;
