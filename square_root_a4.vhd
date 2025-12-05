library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a4 is
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
end entity square_root_a4;

architecture rtl of square_root_a4 is
    type u2N_array is array (0 to N) of unsigned(2*N-1 downto 0);
    type uN_array  is array (0 to N) of unsigned(N-1 downto 0);

    signal D_s     : u2N_array;
    signal R_s     : u2N_array;
    signal Z_s     : uN_array;
    signal valid_s : std_logic_vector(0 to N);
begin
    process(clk)
        variable nextR : unsigned(2*N-1 downto 0);
        variable nextZ : unsigned(N-1 downto 0);
        variable nextD : unsigned(2*N-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- clear pipeline
                for k in 0 to N loop
                    D_s(k)     <= (others => '0');
                    R_s(k)     <= (others => '0');
                    Z_s(k)     <= (others => '0');
                    valid_s(k) <= '0';
                end loop;

            else
                -- Stage 0: load input when start=1
                if start = '1' then
                    D_s(0)     <= unsigned(A);
                    R_s(0)     <= (others => '0');
                    Z_s(0)     <= (others => '0');
                    valid_s(0) <= '1';
                else
                    valid_s(0) <= '0';
                end if;

                -- Pipeline stages 0..N-1 -> 1..N
                for k in 0 to N-1 loop
                    if valid_s(k) = '1' then
                        -- Start from R_s(k), Z_s(k), D_s(k)
                        nextR := R_s(k);
                        nextZ := Z_s(k);
                        nextD := D_s(k);

                        if signed(nextR) >= 0 then
                            nextR := shift_left(nextR, 2) + shift_right(nextD, 2*N-2) - (shift_left(nextZ, 2) + 1);
                        else
                            nextR := shift_left(nextR, 2) + shift_right(nextD, 2*N-2) + (shift_left(nextZ, 2) + 3);
                        end if;

                        if signed(nextR) >= 0 then
                            nextZ := shift_left(nextZ, 1) + 1;
                        else
                            nextZ := shift_left(nextZ, 1);
                        end if;

                        nextD := shift_left(nextD, 2);

                        -- ******** REGISTER THE RESULTS TO STAGE k+1 ********
                        R_s(k+1)     <= nextR;
                        Z_s(k+1)     <= nextZ;
                        D_s(k+1)     <= nextD;
                        valid_s(k+1) <= '1';
                    else
                        valid_s(k+1) <= '0';
                    end if;
                end loop;
            end if;
        end if;
    end process;

    result   <= std_logic_vector(Z_s(N));
    finished <= valid_s(N);

end architecture rtl;