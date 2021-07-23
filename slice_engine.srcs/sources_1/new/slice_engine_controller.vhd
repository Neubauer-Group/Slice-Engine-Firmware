----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/08/2021 04:28:19 PM
-- Design Name:
-- Module Name: slice_engine_controller - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.slice_engine_package.all;


entity slice_engine_controller is
  Port (
  clk         : in std_logic;
  reset       : in std_logic;
  ready       : out std_logic := '0';

  event_start : in STD_LOGIC;
  event_end   : in STD_LOGIC;

  write_mode  : out STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (0 => '1', others => '0');
  read_mode   : out STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (others => '0');

  slice_data  : out STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0) := (others => '0');
  read_done   : in STD_LOGIC := '0';
  increment_module : in STD_LOGIC := '0'

  );
end slice_engine_controller;

architecture Behavioral of slice_engine_controller is

  COMPONENT Slice_RAM_element
    PORT (
      clka  : IN STD_LOGIC;
      wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(Slice_address_bits-1 DOWNTO 0);
      dina  : IN STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0)
    );
  END COMPONENT;


  component slice_engine_spram
  generic (
    RAM_WIDTH     : integer := 32;
    RAM_DEPTH     : integer := 64;
    ADDR_BITS     : integer := 6;
    RAM_LATENCY   : integer := 2;
    RAM_MODE      : string := "no_change";
    RAM_PRIMITIVE : string := "block"
  );
  port (
    clka  : IN  STD_LOGIC;
    wea   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN  STD_LOGIC_VECTOR(ADDR_BITS-1 DOWNTO 0);
    dina  : IN  STD_LOGIC_VECTOR(RAM_WIDTH-1 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(RAM_WIDTH-1 DOWNTO 0)
  );
  end component slice_engine_spram;


  signal slice_data_in  : STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0) := (others => '0');
  signal slice_we_v     : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0');
  signal slice_address  : STD_LOGIC_VECTOR(Slice_address_bits-1 DOWNTO 0) := (others => '0');

  type State_t is (Root, Idle, Writing, Reading);
  signal State_0 : State_t := Root;
  signal State_1 : State_t := Root;

begin

  -- Slice_RAM : Slice_RAM_element
  --   PORT MAP (
  --     clka  => clk,
  --     wea   => slice_we_v,
  --     addra => slice_address,
  --     dina  => slice_data_in,
  --     douta => slice_data
  --   );


  slice_engine_spram_slice : slice_engine_spram
  generic map (
   RAM_WIDTH     => Slice_width,
   RAM_DEPTH     => Slice_depth,
   ADDR_BITS     => Slice_address_bits,
   RAM_LATENCY   => 2,
   RAM_MODE      => "no_change",
   RAM_PRIMITIVE => RAM_Type
  )
  port map (
   clka  => clk,
   wea   => slice_we_v,
   addra => slice_address,
   dina  => slice_data_in,
   douta => slice_data
  );



  state_control : process(clk)
	begin
		if (reset = '1') then
      State_0 <= Root;
      State_1 <= Root;
      ready <= '0';
		elsif (rising_edge(clk)) then
      ready <= '0';
      if (State_0 = Idle or State_1 = Idle) then
        ready <= '1';
      end if;

      if (State_0 = Root and State_1 = Root) then
        State_0 <= Idle;
      end if;

      if (event_start = '1') then
        if (State_0 = Idle) then
          State_0 <= Writing;
        elsif (State_1 = Idle) then
          State_1 <= Writing;
        end if;
      end if;

      if (event_end = '1' and State_1 = Root) then
          State_0 <= Reading;
          State_1 <= Idle;
      end if;

      if (read_done = '1') then
        if (State_0 = Reading) then
          State_0 <= Idle;
          State_1 <= Reading;
        elsif (State_1 = Reading) then
          State_0 <= Reading;
          State_1 <= Idle;
        end if;
      end if;

		end if;
	end process state_control;


  write_control : process(clk)
	begin
		if (reset = '1') then
      write_mode    <= "00";
		elsif (rising_edge(clk)) then
      if (State_0 = Idle or State_0 = Writing) then
        write_mode    <= "01";
      elsif (State_1 = Idle or State_1 = Writing) then
        write_mode    <= "10";
      else
        write_mode    <= "00";
      end if;
		end if;
	end process write_control;


  read_control : process(clk)
	begin
		if (reset = '1') then
      read_mode    <= "00";
      slice_address <= (others => '0');
		elsif (rising_edge(clk)) then
      if (State_0 = Reading) then
        read_mode    <= "01";
      elsif (State_1 = Reading) then
        read_mode    <= "10";
      else
        read_mode    <= "00";
      end if;

      if (increment_module = '1') then
        slice_address <= std_logic_vector(unsigned(slice_address) + 1);
      end if;
      if (read_done = '1') then
        slice_address <= (others => '0');
      end if;
		end if;
	end process read_control;


end Behavioral;
