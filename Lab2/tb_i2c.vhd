-- filepath: c:\csad2526KI409HarvatDmytro05\Lab2\tb_i2c.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Testbench for i2c_master and i2c_slave
-- - Generates clock and reset
-- - Drives master inputs to perform a write then a read
-- - Observes data_rx from master (read) and data_reg_out from slave (write)
entity tb_i2c is
end entity;

architecture sim of tb_i2c is

  -- Clock / reset
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';

  -- Master control signals
  signal start_m   : std_logic := '0';
  signal addr_m    : std_logic_vector(6 downto 0) := "0000001"; -- match slave default
  signal rw_m      : std_logic := '0'; -- 0 = write, 1 = read
  signal data_tx_m : std_logic_vector(7 downto 0) := (others => '0');
  signal data_rx_m : std_logic_vector(7 downto 0);
  signal busy_m    : std_logic;
  signal ack_m     : std_logic;

  -- Shared I2C lines (resolved, open-drain behavior in modules)
  signal scl  : std_logic := '1';
  signal sda  : std_logic := 'Z'; -- tri-state initial

  -- Slave outputs
  signal data_reg_out_s : std_logic_vector(7 downto 0);

  -- simple timeout for simulation
  constant TIMEOUT_CYCLES : integer := 20000;

begin

  -- Instantiate master
  uut_master: entity work.i2c_master
    port map (
      clk     => clk,
      rst     => rst,
      start   => start_m,
      addr    => addr_m,
      rw      => rw_m,
      data_tx => data_tx_m,
      data_rx => data_rx_m,
      busy    => busy_m,
      ack     => ack_m,
      scl     => scl,
      sda     => sda
    );

  -- Instantiate slave (uses same sda/scl bus)
  uut_slave: entity work.i2c_slave
    generic map (
      SLA_ADDR => "0000001"
    )
    port map (
      clk => clk,
      rst => rst,
      scl => scl,
      sda => sda,
      data_reg_out => data_reg_out_s
    );

  -- Clock generator: 50 MHz (period = 20 ns)
  clk_proc: process
  begin
    while now < 1 ms loop
      clk <= '0';
      wait for 10 ns;
      clk <= '1';
      wait for 10 ns;
    end loop;
    wait;
  end process;

  -- Reset sequence and test scenario
  stim_proc: process
    variable cycles : integer := 0;
  begin
    -- initial reset
    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    wait for 100 ns;

    -- 1) WRITE transaction: master writes one byte to slave
    report "Starting WRITE transaction";
    rw_m <= '0';                 -- write
    data_tx_m <= x"3C";         -- sample data to write
    start_m <= '1';
    wait for 20 ns;             -- pulse start for one clock period
    start_m <= '0';

    -- wait for busy to clear or timeout
    cycles := 0;
    while busy_m = '1' and cycles < TIMEOUT_CYCLES loop
      wait for 100 ns;
      cycles := cycles + 1;
    end loop;
    if cycles >= TIMEOUT_CYCLES then
      report "Timeout during WRITE transaction" severity ERROR;
      wait;
    else
      report "WRITE finished; slave captured: " & to_hstring(data_reg_out_s);
    end if;

    -- small delay
    wait for 1 us;

    -- 2) READ transaction: master requests one byte from slave
    report "Starting READ transaction";
    rw_m <= '1';                 -- read
    start_m <= '1';
    wait for 20 ns;
    start_m <= '0';

    -- wait for busy to clear or timeout
    cycles := 0;
    while busy_m = '1' and cycles < TIMEOUT_CYCLES loop
      wait for 100 ns;
      cycles := cycles + 1;
    end loop;
    if cycles >= TIMEOUT_CYCLES then
      report "Timeout during READ transaction" severity ERROR;
      wait;
    else
      report "READ finished; master received: " & to_hstring(data_rx_m);
    end if;

    -- End of test
    report "Testbench finished";
    wait for 200 ns;
    wait;
  end process;

end architecture;