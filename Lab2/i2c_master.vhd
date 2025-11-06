-- filepath: c:\csad2526KI409HarvatDmytro05\Lab2\i2c_master.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
  port (
    clk      : in  std_logic;                 -- system clock
    rst      : in  std_logic;
    start    : in  std_logic;                 -- pulse to start a transfer
    addr     : in  std_logic_vector(6 downto 0);
    rw       : in  std_logic;                 -- '0' = write, '1' = read
    data_tx  : in  std_logic_vector(7 downto 0); -- data to write
    data_rx  : out std_logic_vector(7 downto 0); -- data read
    busy     : out std_logic;
    ack      : out std_logic;

    scl      : out std_logic;                 -- driven by master
    sda      : inout std_logic                -- open-drain style
  );
end entity;

architecture rtl of i2c_master is
  type state_t is (IDLE, START_COND, SEND_BYTE, BIT_WAIT, ACK_WAIT, READ_BYTE, SEND_STOP, DONE);
  signal state     : state_t := IDLE;
  signal bit_cnt   : integer range 0 to 7 := 0;
  signal byte_reg  : std_logic_vector(7 downto 0) := (others => '0');
  signal sda_drive : std_logic := '0';
  signal sda_out   : std_logic := '1'; -- drive low ('0') or release ('Z')
  signal scl_reg   : std_logic := '1';
  signal clk_div   : integer := 0;
  constant CLK_DIV_MAX : integer := 3; -- slow down SCL relative to clk
  signal addr_rw_byte : std_logic_vector(7 downto 0);
  signal read_shift : std_logic_vector(7 downto 0) := (others => '0');
begin

  -- emulate open-drain SDA: drive '0' to pull low, otherwise release (Z)
  sda <= '0' when sda_drive = '1' and sda_out = '0' else 'Z';

  scl <= scl_reg;

  process(clk, rst)
  begin
    if rst = '1' then
      state <= IDLE;
      busy  <= '0';
      ack   <= '0';
      sda_drive <= '0';
      sda_out <= '1';
      scl_reg <= '1';
      data_rx <= (others => '0');
      byte_reg <= (others => '0');
      read_shift <= (others => '0');
      bit_cnt <= 0;
      clk_div <= 0;
    elsif rising_edge(clk) then
      -- simple clock divider for SCL timing
      if clk_div < CLK_DIV_MAX then
        clk_div <= clk_div + 1;
      else
        clk_div <= 0;
        scl_reg <= not scl_reg;
      end if;

      case state is
        when IDLE =>
          busy <= '0';
          ack  <= '0';
          sda_drive <= '0'; -- released
          sda_out <= '1';
          scl_reg <= '1';
          if start = '1' then
            busy <= '1';
            addr_rw_byte <= addr & rw;
            state <= START_COND;
          end if;

        when START_COND =>
          -- generate start: SDA goes low while SCL high
          sda_drive <= '1';
          sda_out <= '0';
          if clk_div = 0 then
            state <= SEND_BYTE;
            byte_reg <= addr_rw_byte;
            bit_cnt <= 7;
          end if;

        when SEND_BYTE =>
          -- send bits MSB first on SCL falling edge; set SDA during SCL low phase so slave can sample on rising
          sda_drive <= '1';
          sda_out <= byte_reg(bit_cnt);
          if clk_div = 0 and scl_reg = '0' then -- on falling edge preparation
            -- wait for next edges; shift on rising->falling sequence
            -- decrement when bit transmitted
            if scl_reg = '0' then
              -- nothing
              null;
            end if;
          end if;
          -- when SCL rising edge we move to next bit on subsequent falling
          if clk_div = 0 and scl_reg = '1' and bit_cnt = 0 then
            state <= ACK_WAIT;
            sda_drive <= '0'; -- release SDA to allow ACK from slave
          elsif clk_div = 0 and scl_reg = '1' then
            if bit_cnt > 0 then
              bit_cnt <= bit_cnt - 1;
              -- prepare next bit
              byte_reg <= byte_reg;
            end if;
          end if;

        when ACK_WAIT =>
          -- master releases SDA and samples ACK during SCL high
          if clk_div = 0 and scl_reg = '1' then
            if sda = '0' then
              ack <= '1';
            else
              ack <= '0';
            end if;
            if rw = '0' then
              -- write: send data byte
              byte_reg <= data_tx;
              bit_cnt <= 7;
              sda_drive <= '1';
              sda_out <= data_tx(7);
              state <= SEND_BYTE;
            else
              -- read: prepare to read
              read_shift <= (others => '0');
              bit_cnt <= 7;
              sda_drive <= '0'; -- release SDA so slave can drive
              state <= READ_BYTE;
            end if;
          end if;

        when READ_BYTE =>
          -- sample SDA on SCL rising edges
          if clk_div = 0 and scl_reg = '1' then
            read_shift(bit_cnt) <= sda;
            if bit_cnt = 0 then
              data_rx <= read_shift;
              -- send NACK (release SDA) then STOP
              sda_drive <= '0';
              state <= SEND_STOP;
            else
              bit_cnt <= bit_cnt - 1;
            end if;
          end if;

        when SEND_STOP =>
          -- generate stop: SDA goes high while SCL high
          sda_drive <= '1';
          sda_out <= '0';
          if clk_div = 0 and scl_reg = '1' then
            sda_out <= '1';
            sda_drive <= '0'; -- release
            state <= DONE;
          end if;

        when DONE =>
          busy <= '0';
          state <= IDLE;

        when others =>
          state <= IDLE;
      end case;
    end if;
  end process;

end architecture;