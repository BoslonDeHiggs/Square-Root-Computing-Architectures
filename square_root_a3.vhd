library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a3 is
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
end entity square_root_a3;

architecture rtl of square_root_a3 is
    -- These registers are put on the boundaries of the combinatorial logic to force an Fmax calculation for Quartus
    signal A_reg        : unsigned(2*N-1 downto 0); -- Input Register
    signal result_reg   : unsigned(N-1 downto 0);   -- Output Register
    signal finished_reg : std_logic;
    
    -- Control signal to delay 'start' by one cycle (to match A_reg latency)
    signal start_delayed : std_logic;

begin

    process(clk)
        -- Variables for the Combinatorial Logic
        variable i : integer range 0 to N;
        variable D : unsigned(2*N-1 downto 0);
        variable R : unsigned(2*N-1 downto 0);
        variable Z : unsigned(N-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                A_reg         <= (others => '0');
                result_reg    <= (others => '0');
                finished_reg  <= '0';
                start_delayed <= '0';
            else
                if start = '1' then -- Capture the input A
                    A_reg <= unsigned(A);
                end if;
                start_delayed <= start; -- Pipeline the start signal to match

                if start_delayed = '1' then 
        
                    D := A_reg;  
                    R := (others => '0');
                    Z := (others => '0');

                    -- Standard algorithm logic (same as a2)
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

                    result_reg   <= Z;
                    finished_reg <= '1';
                else
                    finished_reg <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Output assignments
    result   <= std_logic_vector(result_reg);
    finished <= finished_reg;

end architecture rtl;