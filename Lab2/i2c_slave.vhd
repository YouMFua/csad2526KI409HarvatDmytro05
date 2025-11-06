-- filepath: c:\csad2526KI409HarvatDmytro05\Lab2\i2c_slave.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_slave is
  generic (
    SLA_ADDR : std_logic_vector(6 downto 0) := "0000001"
  );
  port (
    clk     : in  std_logic;    -- system clock for internal processes
    rst     : in  std_logic;
    scl     : in  std_logic;    -- SCL from master
    sda     : inout std_logic;  -- open-drain SDA
    data_reg_out : out std_logic_vector(7 downto 0) -- data received from master
  );
end entity;

architecture rtl of i2c_slave is
  type state_t is (IDLE, ADDR_RX, ADDR_ACK, DATA_RX, DATA_ACK, DATA_TX, STOP_WAIT);
  signal state    : state_t := IDLE;
  signal sda_in   : std_logic;
  signal sda_drive: std_logic := '0';
  signal sda_out  : std_logic := '1';
  signal bit_cnt  : integer range 0 to 7 := 0;
  signal shift_reg: std_logic_vector(7 downto 0) := (others => '0');
  signal addr_byte: std_logic_vector(7 downto 0) := (others => '0');
  signal last_scl : std_logic := '1';
begin

  -- open-drain behavior: drive '0' to pull low, otherwise release
  sda <= '0' when sda_drive = '1' and sda_out = '0' else 'Z';
  sda_in <= sda;

  process(clk, rst)
  begin
    if rst = '1' then
      state <= IDLE;
      sda_drive <= '0';
      sda_out <= '1';
      data_reg_out <= (others => '0');
      bit_cnt <= 7;
      shift_reg <= (others => '0');
      addr_byte <= (others => '0');
      last_scl <= '1';
    elsif rising_edge(clk) then
      -- detect start condition: SDA falling while SCL is high
      if last_scl = '1' and scl = '1' and sda_in = '0' and sda_drive = '0' then
        state <= ADDR_RX;
        bit_cnt <= 7;
        shift_reg <= (others => '0');
      end if;
      last_scl <= scl;

      -- sample on SCL rising edges
      if last_scl = '0' and scl = '1' then
        case state is
          when IDLE =>
            null;

          when ADDR_RX =>
            shift_reg(bit_cnt) <= sda_in;
            if bit_cnt = 0 then
              addr_byte <= shift_reg;
              state <= ADDR_ACK;
              sda_drive <= '1'; sda_out <= '0'; -- drive ACK low during ACK cycle
            else
              bit_cnt <= bit_cnt - 1;
            end if;

          when ADDR_ACK =>
            -- release ACK after one clock
            sda_drive <= '0';
            -- check address match
            if addr_byte(7 downto 1) = SLA_ADDR then
              -- if R/W = '0' -> master will write data next
              if addr_byte(0) = '0' then
                state <= DATA_RX;
                bit_cnt <= 7;
                shift_reg <= (others => '0');
              else
                -- master wants to read: prepare data to send
                -- for demo, send 0xA5 (can be customized)
                shift_reg <= x"A5";
                bit_cnt <= 7;
                state <= DATA_TX;
              end if;
            else
              -- address mismatch: ignore until STOP
              state <= STOP_WAIT;
            end if;

          when DATA_RX =>
            shift_reg(bit_cnt) <= sda_in;
            if bit_cnt = 0 then
              data_reg_out <= shift_reg;
              -- ACK
              sda_drive <= '1'; sda_out <= '0';
              state <= DATA_ACK;
            else
              bit_cnt <= bit_cnt - 1;
            end if;

          when DATA_ACK =>
            -- release ACK after one clock cycle
            sda_drive <= '0';
            -- wait for more data or stop (for simplicity go to STOP_WAIT)
            state <= STOP_WAIT;

          when DATA_TX =>
            -- drive data bits onto SDA during SCL low so master can sample rising edge
            -- here we prepare next bit during falling edge; but we use rising-edge sampling simple model:
            -- set SDA to next bit value now (it will be stable for next cycle)
            sda_drive <= '1';
            sda_out <= shift_reg(bit_cnt);
            if bit_cnt = 0 then
              sda_drive <= '0'; -- release for ACK from master
              state <= STOP_WAIT;
            else
              bit_cnt <= bit_cnt - 1;
            end if;

          when STOP_WAIT =>
            -- detect stop: SDA rising while SCL high
            if scl = '1' and sda_in = '1' then
              state <= IDLE;
            end if;

          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture;