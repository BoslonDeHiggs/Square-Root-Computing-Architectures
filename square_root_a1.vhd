library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a1 is
    generic (
        N : positive := 32
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        start    : in  std_logic;
        A        : in  std_logic_vector(2*N-1 downto 0);
        result   : out std_logic_vector(N-1 downto 0);
        finished : out std_logic
    );
end entity square_root_a1;

architecture rtl of square_root_a1 is
    type state_t is (IDLE, RUN, DONE);
    signal state        : state_t;

    signal A_reg        : unsigned(2*N-1 downto 0); -- Input register
    signal result_reg   : unsigned(N-1 downto 0);   -- Result register

    signal x            : unsigned(2*N-1 downto 0);

begin

    process(clk)
        variable x_next : unsigned(2*N-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= IDLE;
                A_reg        <= (others => '0');
                result_reg   <= (others => '0');
            else
                -- Capture input
                if (state = IDLE) and (start = '1') then
                    A_reg <= unsigned(A);
                    x     <= unsigned(A)/2 + to_unsigned(1, x'length);  -- Initial guess
                    state <= RUN;
                elsif state = RUN then
                    if(A_reg = 0 or A_reg = 1) then
                        result_reg <= A_reg(N-1 downto 0); -- Cases where sqrt(0)=0, sqrt(1)=1
                        state <= DONE;
                    else
                        x_next := x - shift_right((resize(x*x, x'length) - A_reg) / x, 1); -- Newton-Raphson update
                        if x_next >= x then -- Convergence check
                            result_reg <= resize(x - to_unsigned(1, x'length), result_reg'length); -- Correct for overshoot
                            state <= DONE;
                        else -- If not converged, continue
                            x <= x_next;
                        end if;
                    end if;
                elsif state = DONE then
                    if start = '0' then
                        state <= IDLE;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Outputs
    result   <= std_logic_vector(result_reg);
    finished <= '1' when state = DONE else '0';

end architecture rtl;