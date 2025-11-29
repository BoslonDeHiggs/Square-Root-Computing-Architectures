library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a1 is
    generic (
        N : positive := 32  -- result width in bits; input A is 2*N bits
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;  -- active high synchronous reset
        start    : in  std_logic;
        A        : in  std_logic_vector(2*N-1 downto 0);
        result   : out std_logic_vector(N-1 downto 0);
        finished : out std_logic
    );
end entity square_root_a1;

architecture rtl of square_root_a1 is
    type state_t is (IDLE, RUN, DONE);
    signal state        : state_t;

    signal A_reg        : unsigned(2*N-1 downto 0);
    signal result_reg   : unsigned(N-1 downto 0);
    signal finished_reg : std_logic;

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
                finished_reg <= '0';
            else
                -- capture input when starting
                if (state = IDLE) and (start = '1') then
                    A_reg <= unsigned(A);
                    x     <= unsigned(A)/2 + to_unsigned(1, x'length);  -- initial guess
                    finished_reg <= '0';
                    state <= RUN;
                elsif state = RUN then
                    if(A_reg = 0 or A_reg = 1) then
                        result_reg <= A_reg(N-1 downto 0);
                        state <= DONE;
                    else
                        x_next := x - (resize(x*x, x'length) - A_reg) / (2*x);
                        if x_next = x then
                            result_reg <= resize(x - to_unsigned(1, x'length), result_reg'length);
                            state <= DONE;
                        else
                            x <= x_next;
                        end if;
                    end if;
                elsif state = DONE then
                    finished_reg <= '1';
                    state <= IDLE;
                end if;
            end if;
        end if;
    end process;

    -- Output assignments
    result   <= std_logic_vector(result_reg);
    finished <= finished_reg;

end architecture rtl;