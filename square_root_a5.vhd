library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

----------------- Entities and architectures for components -----------------

-- Adder/subtractor (Used for R update)

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

-- Normal register (Used for R)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg is
    generic ( WIDTH : positive := 32 );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        en    : in  std_logic;
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
            if en = '1' then
                q <= d;
            end if;
        end if;
    end process;
end architecture;

-- Shift left register (Modified for D and Z)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shift_left_reg is
    generic (
        WIDTH : positive := 32;
        SHIFT : integer  := 1
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        load     : in  std_logic; 
        shift_en : in  std_logic;
        d_in     : in  std_logic_vector(WIDTH-1 downto 0); 
        lsb_in   : in  std_logic_vector(SHIFT-1 downto 0); 
        q        : out std_logic_vector(WIDTH-1 downto 0)
    );
end entity shift_left_reg;

architecture rtl of shift_left_reg is
    signal q_int : std_logic_vector(WIDTH-1 downto 0);
begin
    process(clk, reset)
    begin
        if reset = '1' then
            q_int <= (others => '0');
        elsif rising_edge(clk) then
            if load = '1' then
                q_int <= d_in;
            elsif shift_en = '1' then
                -- Shift left and insert lsb_in at the bottom
                q_int <= std_logic_vector(shift_left(unsigned(q_int), SHIFT));
                q_int(SHIFT-1 downto 0) <= lsb_in;
            end if;
        end if;
    end process;
    q <= q_int;
end architecture;

-- Counter (from loop n-1 downto 0)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic ( WIDTH : positive := 8 );
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        load   : in  std_logic;
        en     : in  std_logic;
        d_in   : in  unsigned(WIDTH-1 downto 0);
        q      : out unsigned(WIDTH-1 downto 0)
    );
end entity counter;

architecture rtl of counter is
    signal count : unsigned(WIDTH-1 downto 0);
begin
    process(clk, reset)
    begin
        if reset = '1' then
            count <= (others => '0');
        elsif rising_edge(clk) then
            if load = '1' then
                count <= d_in;
            elsif en = '1' then
                count <= count - 1;
            end if;
        end if;
    end process;
    q <= count;
end architecture;


----------------- Structural square root module using the components -----------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity square_root_a5 is
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
end entity square_root_a5;

architecture rtl of square_root_a5 is

    -- Register Widths
    constant R_WIDTH : positive := N + 2;

    -- Control Signals
    type state_t is (IDLE, CALC, DONE);
    signal current_state : state_t;
    signal next_state    : state_t;
    
    signal load_regs     : std_logic;
    signal shift_regs    : std_logic;
    signal count_en      : std_logic;
    signal update_R      : std_logic;
    signal clear_R       : std_logic;

    -- Datapath Signals
    signal D_q           : std_logic_vector(2*N-1 downto 0);
    signal Z_q           : std_logic_vector(N-1 downto 0);
    signal R_q           : std_logic_vector(R_WIDTH-1 downto 0);
    signal R_next        : std_logic_vector(R_WIDTH-1 downto 0);
    signal R_in          : std_logic_vector(R_WIDTH-1 downto 0); -- Input to R Reg
    
    signal loop_counter  : unsigned(7 downto 0); 
    
    -- Arithmetic Signals
    signal adder_a       : std_logic_vector(R_WIDTH-1 downto 0);
    signal adder_b       : std_logic_vector(R_WIDTH-1 downto 0);
    signal adder_out     : std_logic_vector(R_WIDTH-1 downto 0);
    signal adder_sub_cmd : std_logic; -- '0' = add, '1' = subtract
    
    signal z_lsb_in      : std_logic_vector(0 downto 0);

begin

    -- Control logic FSM
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    process(current_state, start, loop_counter)
    begin
        -- Default values
        next_state <= current_state;
        load_regs  <= '0';
        shift_regs <= '0';
        update_R   <= '0';
        count_en   <= '0';
        clear_R    <= '0';
        finished   <= '0';

        case current_state is
            when IDLE =>
                if start = '1' then
                    load_regs  <= '1'; -- Load A into D
                    clear_R    <= '1'; -- Force R to 0
                    update_R   <= '1'; -- Write 0 into R
                    next_state <= CALC;
                end if;

            when CALC =>
                update_R   <= '1'; -- Capture adder result
                shift_regs <= '1'; -- Shift D and Z
                count_en   <= '1'; -- Decrement counter
                
                if loop_counter = 0 then
                    next_state <= DONE;
                end if;

            when DONE =>
                finished <= '1';
                if start = '0' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;

    
    -- From here on, datapath components instantiation and wiring

    -- Register D
    u_reg_D : entity work.shift_left_reg
        generic map ( WIDTH => 2*N, SHIFT => 2 )
        port map (
            clk      => clk,
            reset    => reset,
            load     => load_regs,
            shift_en => shift_regs, 
            d_in     => A,
            lsb_in   => "00", 
            q        => D_q
        );

    -- Register Z
    z_lsb_in(0) <= not R_next(R_WIDTH-1);  -- Lsb is determined by the sign of (R_next)

    u_reg_Z : entity work.shift_left_reg
        generic map ( WIDTH => N, SHIFT => 1 )
        port map (
            clk      => clk,
            reset    => reset,
            load     => load_regs, -- Loads 0s
            shift_en => shift_regs,
            d_in     => (others => '0'),
            lsb_in   => z_lsb_in,
            q        => Z_q
        );

    -- Register R
    R_in <= (others => '0') when clear_R = '1' else R_next; -- Mux to select input : 0 (during Start) or Adder Result (during Calc)

    u_reg_R : entity work.reg
        generic map ( WIDTH => R_WIDTH )
        port map (
            clk   => clk,
            reset => reset, 
            en    => update_R, 
            d     => R_in, -- Connected to Mux output
            q     => R_q
        );

    -- Counter
    u_counter : entity work.counter
        generic map ( WIDTH => 8 )
        port map (
            clk    => clk,
            reset  => reset,
            load   => load_regs,
            en     => count_en,
            d_in   => to_unsigned(N-1, 8), 
            q      => loop_counter
        );

    -- From here, combinational logic for R update
    
    -- Equivalent to shift_left(nextR, 2) + shift_right(nextD, 2*N-2)
    adder_a <= R_q(R_WIDTH-3 downto 0) & D_q(2*N-1 downto 2*N-2);

    process(R_q, Z_q)
    begin
        if R_q(R_WIDTH-1) = '0' then -- if R >= 0
            adder_sub_cmd <= '1'; -- Subtract (4*Z + 1)
            adder_b <= std_logic_vector(resize(unsigned(Z_q), R_WIDTH-2)) & "01";
        else -- R < 0
            adder_sub_cmd <= '0'; -- Add (4*Z + 3)
            adder_b <= std_logic_vector(resize(unsigned(Z_q), R_WIDTH-2)) & "11";
        end if;
    end process;

    -- Adder/Subtractor
    u_adder : entity work.adder_sub
        generic map ( WIDTH => R_WIDTH )
        port map (
            a      => adder_a,
            b      => adder_b,
            sub    => adder_sub_cmd,
            result => adder_out
        );
        
    R_next <= adder_out;

    -- Output Assignment
    result <= Z_q;

end architecture rtl;