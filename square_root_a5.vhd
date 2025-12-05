library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Adder / subtracter
entity adder_sub is
  generic ( WIDTH : positive := 32 );
  port (
    a      : in  std_logic_vector(WIDTH-1 downto 0);
    b      : in  std_logic_vector(WIDTH-1 downto 0);
    sub    : in  std_logic;  -- '0' = a+b, '1' = a-b
    result : out std_logic_vector(WIDTH-1 downto 0)
  );
end entity;

architecture rtl of adder_sub is
begin
  process(a, b, sub)
  begin
    if sub = '1' then
      result <= std_logic_vector(unsigned(a) - unsigned(b));
    else
      result <= std_logic_vector(unsigned(a) + unsigned(b));
    end if;
  end process;
end architecture;

entity reg is
    generic (
        WIDTH : positive := 32
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        d     : in  std_logic_vector(WIDTH-1 downto 0);
        q     : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity reg;

architecture rtl of reg is
begin
    process(clk, reset)
    begin
        if reset = '1' then
            q <= (others => '0');
        elsif rising_edge(clk) then
            q <= d;
        end if;
    end process;
end architecture;

entity shift_left_reg is
    generic (
        WIDTH : positive := 32;
        SHIFT : integer  := 1  -- positive = left, negative = right
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        shift : in  std_logic;  -- '1' = shift, '0' = hold
        d     : in  std_logic_vector(WIDTH-1 downto 0);
        q     : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity shift_left_reg;

architecture rtl of shift_left_reg is
begin
    process(clk, reset)
    begin
        if reset = '1' then
            q <= (others => '0');
        elsif rising_edge(clk) then
            if shift = '1' then
                q <= shift_left(d, SHIFT);
            else
                q <= d;
            end if;
        end if;
    end process;
end architecture;

entity counter is
    generic (
        WIDTH : positive := 8
    );
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        enable : in  std_logic;
        q      : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity counter;

architecture rtl of counter is
    signal count : unsigned(WIDTH-1 downto 0) := (others => '0');
begin
    process(clk, reset)
    begin
        if reset = '1' then
            count <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                count <= count + 1;
            end if;
        end if;
    end process;
    q <= std_logic_vector(count);   
end architecture;

entity splitter is
    generic (
        IN_WIDTH  : positive := 32;
        OUT_WIDTH : positive := 16
    );
    port (
        data_in  : in  std_logic_vector(IN_WIDTH-1 downto 0);
        data_out1 : out std_logic_vector(OUT_WIDTH-1 downto 0);
        data_out2 : out std_logic_vector(OUT_WIDTH-1 downto 0)
    );
end entity splitter;

architecture rtl of splitter is
begin
    process
    begin
        for i in 0 to OUT_WIDTH-1 loop
            data_out1(i) <= data_in(2*i);
            data_out2(i) <= data_in(2*i + 1);
        end loop;
    end process;
end architecture rtl;

entity square_root_a5 is
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
end entity square_root_a5;

architecture rtl of square_root_a5 is
    type state_t is (IDLE, RUN, DONE);
    signal state        : state_t;
    signal result_reg   : unsigned(N-1 downto 0);
    signal A_even     : std_logic_vector(N-1 downto 0);
    signal A_odd      : std_logic_vector(N-1 downto 0);
    signal shift      : std_logic;

begin

    u_split : entity work.splitter(rtl)
        generic map (
          IN_WIDTH  => 2 * N,
          OUT_WIDTH => N
        )
        port map (
          data_in  => A,
          data_out1 => A_even,  -- data_in bits 0,2,4,...  (as implemented)
          data_out2 => A_odd    -- data_in bits 1,3,5,...
        );

    u_shift_left_even : entity work.shift_left_reg(rtl)
        generic map (
          WIDTH => N,
          SHIFT => 1
        )
        port map (
          clk   => clk,
          reset => reset,
          shift => shift,
          d     => A_even,
          q     => A_even
        );

    u_shift_left_odd : entity work.shift_left_reg(rtl)
        generic map (
          WIDTH => N,
          SHIFT => 1
        )
        port map (
          clk   => clk,
          reset => reset,
          shift => shift,
          d     => A_odd,
          q     => A_odd
        );

    u_shift_left_q : entity work.shift_left_reg(rtl)
        generic map (
          WIDTH => N,
          SHIFT => 1
        )
        port map (
          clk   => clk,
          reset => reset,
          shift => shift,
          d     => std_logic_vector(result_reg),
          q     => std_logic_vector(result_reg)
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= IDLE;
                A_reg        <= (others => '0');
                result_reg   <= (others => '0');
            else
                -- capture input when starting
                if (state = IDLE) and (start = '1') then

                    state <= RUN;
                elsif state = RUN then
                   
                elsif state = DONE then
                    if start = '0' then
                        state <= IDLE;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Output assignments
    result   <= std_logic_vector(result_reg);
    finished <= '1' when state = DONE else '0';

end architecture rtl;