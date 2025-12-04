library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a3 is
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
end entity square_root_a3;

architecture rtl of square_root_a3 is
    signal result_reg   : unsigned(N-1 downto 0);

begin

    process(A, start, reset)
        variable i : integer range 0 to N;
        variable D : unsigned(2*N-1 downto 0);
        variable R : unsigned(2*N-1 downto 0);
        variable Z : unsigned(N-1 downto 0);
    begin
        if reset = '1' then
            D            := (others => '0');
            R            := (others => '0');
            Z            := (others => '0');
            result_reg   <= (others => '0');
        else
            if start = '1' then
                D := unsigned(A);
                R := (others => '0');
                Z := (others => '0');
                -- Main computation loop
                for i in N-1 downto 0 loop
                    if (signed(R) >= 0) then
                        R := shift_left(R, 2) + shift_right(D, 2*N-2) - (shift_left(Z, 2) + 1);
                    else
                        R := shift_left(R, 2) + shift_right(D, 2*N-2) + (shift_left(Z, 2) + 3);
                    end if;
                    if (signed(R) >= 0) then
                        Z := shift_left(Z, 1) + 1;
                    else
                        Z := shift_left(Z, 1);
                    end if;
                    D := shift_left(D, 2);
                end loop;
                result_reg <= Z;
                finished <= '1';
            else
                finished <= '0';
            end if;
        end if;
    end process;

    -- Output assignments
    result   <= std_logic_vector(result_reg);

end architecture rtl;