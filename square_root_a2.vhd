library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a2 is
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
end entity square_root_a2;

architecture rtl of square_root_a2 is
    type state_t is (IDLE, RUN, DONE);
    signal state        : state_t;

    signal result_reg   : unsigned(N-1 downto 0);
    signal finished_reg : std_logic;

    signal D            : unsigned(2*N-1 downto 0);
    signal Z            : unsigned(N-1 downto 0);

begin

    process(clk)
        variable i : integer range 0 to N;
        variable R : unsigned(2*N-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= IDLE;
                D            <= (others => '0');
                Z            <= (others => '0');
                R            := (others => '0');
                result_reg   <= (others => '0');
                finished_reg <= '0';
            else
                -- capture input when starting
                if (state = IDLE) and (start = '1') then
                    D <= unsigned(A);
                    Z <= (others => '0');
                    R := (others => '0');
                    i := N;
                    finished_reg <= '0';
                    state <= RUN;
                elsif state = RUN then
                    if (i > 0) then
                        if (signed(R) >= 0) then
                            R := shift_left(R, 2) + shift_right(D, 2*N-2) - (shift_left(Z, 2) + 1);
                        else
                            R := shift_left(R, 2) + shift_right(D, 2*N-2) + (shift_left(Z, 2) + 3);
                        end if;
                        if (signed(R) >= 0) then
                            Z <= shift_left(Z, 1) + 1;
                        else
                            Z <= shift_left(Z, 1);
                        end if;
                        i := i - 1;
                        D <= shift_left(D, 2);
                    else
                        result_reg <= Z;
                        state <= DONE;
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