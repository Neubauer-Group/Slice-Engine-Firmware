----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/01/2021 07:12:09 PM
-- Design Name:
-- Module Name: slice_engine_RAM_wrapper - Behavioral
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



entity slice_engine_RAM_wrapper is
  Port (
  clk         : in std_logic;
  reset       : in std_logic;
  write_mode  : in std_logic;
  read_mode   : in std_logic;

  event_data  : in STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
  event_word  : in INTEGER := 0;
  head_we     : in STD_LOGIC := '0';
  foot_we     : in STD_LOGIC := '0';

  raw_data    : in STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  raw_address : in STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '1');
  raw_we      : in STD_LOGIC := '0';
  cnt_data    : in STD_LOGIC_VECTOR(CNT_width-1 downto 0) := (others => '0');
  cnt_address : in STD_LOGIC_VECTOR(CNT_address_bits-1 downto 0) := (others => '0');
  cnt_we      : in STD_LOGIC := '0';

  slice_data  : in STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0) := (others => '0');
  read_done   : out STD_LOGIC := '0';
  increment_module : out STD_LOGIC := '0';

  data_out : out STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  valid_data : out STD_LOGIC := '0'
  );
end slice_engine_RAM_wrapper;

architecture Behavioral of slice_engine_RAM_wrapper is

  COMPONENT RAW_RAM_element
    PORT (
      clka  : IN STD_LOGIC;
      wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(RAW_address_bits-1 DOWNTO 0);
      dina  : IN STD_LOGIC_VECTOR(RAW_width-1 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(RAW_width-1 DOWNTO 0)
    );
  END COMPONENT;


  COMPONENT CNT_RAM_element
    PORT (
      clka  : IN STD_LOGIC;
      wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(CNT_address_bits-1 DOWNTO 0);
      dina  : IN STD_LOGIC_VECTOR(CNT_width-1 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(CNT_width-1 DOWNTO 0)
    );
  END COMPONENT;


  COMPONENT CNT_Buffer_FIFO
    PORT (
      clk : IN STD_LOGIC;
      srst : IN STD_LOGIC;
      din : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
      wr_en : IN STD_LOGIC;
      rd_en : IN STD_LOGIC;
      dout : OUT STD_LOGIC_VECTOR(19 DOWNTO 0);
      full : OUT STD_LOGIC;
      empty : OUT STD_LOGIC;
      data_count : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      wr_rst_busy : OUT STD_LOGIC;
      rd_rst_busy : OUT STD_LOGIC
    );
  END COMPONENT;


  COMPONENT Status_RAM_element
    PORT (
      clka : IN STD_LOGIC;
      wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      dina : IN STD_LOGIC_VECTOR(1023 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(1023 DOWNTO 0)
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


  component slice_engine_fifo
  generic (
    FIFO_WIDTH       : integer := 32;
    FIFO_DEPTH       : integer := 2048;
    FIFO_COUNT_WIDTH : integer := 12;
    FIFO_LATENCY     : integer := 0;
    FIFO_MODE        : string;
    FIFO_PRIMITIVE   : string
  );
  port (
    clk         : IN  STD_LOGIC;
    srst        : IN  STD_LOGIC;
    din         : IN  STD_LOGIC_VECTOR(FIFO_WIDTH-1 DOWNTO 0);
    wr_en       : IN  STD_LOGIC;
    rd_en       : IN  STD_LOGIC;
    dout        : OUT STD_LOGIC_VECTOR(FIFO_WIDTH-1 DOWNTO 0);
    full        : OUT STD_LOGIC;
    empty       : OUT STD_LOGIC;
    data_count  : OUT STD_LOGIC_VECTOR(FIFO_COUNT_WIDTH-1 DOWNTO 0);
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
  end component slice_engine_fifo;



  type State_t is (Root, Head, Slice, Foot, Reseting);
  signal Read_State : State_t := Root;

  signal raw_we_v : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0');
  signal cnt_we_v : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0');
  signal cnt_we_v2 : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0');
  signal raw_address_i : STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '1');
  signal cnt_address_i : STD_LOGIC_VECTOR(CNT_address_bits-1 downto 0) := (others => '0');
  signal status_address_i : STD_LOGIC_VECTOR(status_bits-1 downto 0) := (others => '0');
  signal status_count : STD_LOGIC_VECTOR(status_bits-1 downto 0) := (others => '0');
  signal status_we_v : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0');

  signal Header : Header_t := (others => (others => '0'));
  signal Footer : Footer_t := (others => (others => '0'));

  signal raw_data_o    : STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  signal cnt_data_o    : STD_LOGIC_VECTOR(CNT_width-1 downto 0) := (others => '0');
  signal cnt_buff_o    : STD_LOGIC_VECTOR(CNT_width-1 downto 0) := (others => '0');
  signal read_mode_i   : std_logic := '0';
  signal module_status : std_logic := '0';
  signal module_status_2 : std_logic := '0';
  signal valid_cnt_data : std_logic := '0';
  signal increment_module_i : std_logic := '0';
  signal increment_pipe_1 : std_logic := '0';
  signal increment_pipe_2 : std_logic := '0';
  signal increment_pipe_3 : std_logic := '0';
  signal increment_pipe_4 : std_logic := '0';

  signal count_target : integer := 0;
  signal read_count : integer := 0;
  signal read_address : STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '0');
  signal reading : boolean := false;
  signal valid_raw_i : std_logic := '0';
  signal valid_out   : std_logic := '0';

  signal status_in  : STD_LOGIC_VECTOR(status_width-1 downto 0) := (others => '0');
  signal status_out : STD_LOGIC_VECTOR(status_width-1 downto 0) := (others => '0');
  signal status_new : STD_LOGIC_VECTOR(status_width-1 downto 0) := (others => '0');

  signal data_count : STD_LOGIC_VECTOR(4 DOWNTO 0);
  signal data_count_1 : STD_LOGIC_VECTOR(4 DOWNTO 0);
  signal data_count_2 : STD_LOGIC_VECTOR(4 DOWNTO 0);
  signal read_buff   : std_logic := '0';

  signal read_event_count : integer := 0;
  signal event_data_o    : STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  signal event_valid   : std_logic := '0';
  signal slice_count : integer := 0;
  signal slice_count_1 : integer := 0;


begin


  -- RAW_RAM : RAW_RAM_element
  --   PORT MAP (
  --     clka  => clk,
  --     wea   => raw_we_v,
  --     addra => raw_address_i,
  --     dina  => raw_data,
  --     douta => raw_data_o
  --   );
  raw_we_v(0) <= raw_we when write_mode = '1' else
                 '0';
  raw_address_i <= read_address when read_mode = '1' else
                   raw_address;


  slice_engine_spram_raw : slice_engine_spram
  generic map (
   RAM_WIDTH     => RAW_width,
   RAM_DEPTH     => RAW_depth,
   ADDR_BITS     => RAW_address_bits,
   RAM_LATENCY   => 2,
   RAM_MODE      => "no_change",
   RAM_PRIMITIVE => RAM_Type
  )
  port map (
   clka  => clk,
   wea   => raw_we_v,
   addra => raw_address_i,
   dina  => raw_data,
   douta => raw_data_o
  );


  -- CNT_RAM : CNT_RAM_element
  --   PORT MAP (
  --     clka  => clk,
  --     wea   => cnt_we_v,
  --     addra => cnt_address_i,
  --     dina  => cnt_data,
  --     douta => cnt_data_o
  --   );
  cnt_we_v(0) <= cnt_we when write_mode = '1' else
                 '0';
  cnt_address_i <= slice_data(CNT_address_bits-1 downto 0) when read_mode = '1' else
                   cnt_address;


   slice_engine_spram_cnt : slice_engine_spram
   generic map (
    RAM_WIDTH     => CNT_width,
    RAM_DEPTH     => CNT_depth,
    ADDR_BITS     => CNT_address_bits,
    RAM_LATENCY   => 2,
    RAM_MODE      => "no_change",
    RAM_PRIMITIVE => RAM_Type
   )
   port map (
    clka  => clk,
    wea   => cnt_we_v,
    addra => cnt_address_i,
    dina  => cnt_data,
    douta => cnt_data_o
   );


  -- Status_RAM : Status_RAM_element
  --   PORT MAP (
  --     clka  => clk,
  --     wea   => status_we_v,
  --     addra => status_address_i,
  --     dina  => status_in,
  --     douta => status_out
  --   );
  status_address_i <= status_count when Read_State = Reseting else
                      slice_data(Mod_ID_width-1 downto Mod_ID_width - status_bits) when read_mode = '1' else
                      cnt_address(Mod_ID_width-1 downto Mod_ID_width - status_bits);
  status_in <= (others => '0') when Read_State = Reseting else
               status_out or status_new;
  status_we_v <= "1" when Read_State = Reseting else
                 cnt_we_v;

 slice_engine_spram_status : slice_engine_spram
 generic map (
  RAM_WIDTH     => status_width,
  RAM_DEPTH     => status_depth,
  ADDR_BITS     => status_bits,
  RAM_LATENCY   => 2,
  RAM_MODE      => "write_first",
  RAM_PRIMITIVE => RAM_Type
 )
 port map (
  clka  => clk,
  wea   => status_we_v,
  addra => status_address_i,
  dina  => status_in,
  douta => status_out
 );



  -- CNT_Buffer : CNT_Buffer_FIFO
  --   PORT MAP (
  --     clk         => clk,
  --     srst        => reset,
  --     din         => cnt_data_o,
  --     wr_en       => module_status_2 and valid_cnt_data,
  --     rd_en       => read_buff,
  --     dout        => cnt_buff_o,
  --     full        => open,
  --     empty       => open,
  --     data_count  => data_count,
  --     wr_rst_busy => open,
  --     rd_rst_busy => open
  --   );


    slice_engine_fifo_cnt : slice_engine_fifo
    generic map (
      FIFO_WIDTH       => CNT_width,
      FIFO_DEPTH       => 16,
      FIFO_COUNT_WIDTH => 5,
      FIFO_LATENCY     => 0,
      FIFO_MODE        => "fwft",
      FIFO_PRIMITIVE   => RAM_Type
    )
    port map (
      clk         => clk,
      srst        => reset,
      din         => cnt_data_o,
      wr_en       => module_status_2 and valid_cnt_data,
      rd_en       => read_buff,
      dout        => cnt_buff_o,
      full        => open,
      empty       => open,
      data_count  => data_count,
      wr_rst_busy => open,
      rd_rst_busy => open
    );



  write_event : process(clk)
	begin
		if (reset = '1') then
      Header <= (others => (others => '0'));
      Footer <= (others => (others => '0'));
		elsif (rising_edge(clk)) then
      if (head_we = '1' and write_mode = '1') then
        Header(event_word) <= event_data;
      elsif (foot_we = '1' and write_mode = '1') then
        Footer(event_word) <= event_data;
      end if;
		end if;
	end process write_event;


  write_status : process(clk)
	begin
		if (reset = '1') then
      status_new   <= (others => '0');
      status_count <= (others => '0');
		elsif (rising_edge(clk)) then
      status_new <= (others => '0');
      status_new(to_integer(unsigned(cnt_address(Mod_ID_width - status_bits -1 downto 0)))) <= '1';

      status_count <= (others => '0');
      if (Read_State = Reseting) then
        status_count <= std_logic_vector(unsigned(status_count) + 1);
      end if;
		end if;
	end process write_status;


  state_control : process(clk)
	begin
		if (reset = '1') then
      read_mode_i <= '0';
      Read_State <= Root;
      read_done <= '0';
		elsif (rising_edge(clk)) then
      read_mode_i <= read_mode;
      read_done <= '0';
      if (Read_State = Root and read_mode = '1') then
        Read_State <= Head;
      end if;
      if (Read_State = Head and read_event_count = Header_Length-1) then
        Read_State <= Slice;
      end if;

      if (Read_State = Slice and read_count = count_target and unsigned(data_count_2) = 0 and count_target > 0) then
        Read_State <= Foot;
      end if;

      if (Read_State = Foot and read_event_count = Footer_Length-1) then
        Read_State <= Reseting;
      end if;

      if (Read_State = Reseting and to_integer(unsigned(status_count)) = status_depth-1) then
        Read_State <= Root;
      end if;
      if (Read_State = Reseting and to_integer(unsigned(status_count)) = status_depth-3) then
        read_done <= '1';
      end if;
		end if;
	end process state_control;



  read_event : process(clk)
	begin
		if (reset = '1') then
      event_data_o     <= (others => '0');
      event_valid      <= '0';
      read_event_count <= 0;
		elsif (rising_edge(clk)) then
      event_data_o     <= (others => '0');
      event_valid      <= '0';
      read_event_count <= 0;
      if (Read_State = Head) then
        read_event_count <= read_event_count + 1;
        event_data_o     <= Header(read_event_count);
        event_valid      <= '1';
      end if;
      if (Read_State = Foot) then
        read_event_count <= read_event_count + 1;
        event_data_o     <= Footer(read_event_count);
        event_valid      <= '1';
      end if;
		end if;
	end process read_event;


  read_cnt : process(clk)
	begin
		if (reset = '1') then
      increment_module_i <= '0';
      module_status    <= '0';
      module_status_2  <= '0';
      valid_cnt_data   <= '0';
      increment_pipe_1 <= '0';
      increment_pipe_2 <= '0';
      increment_pipe_3 <= '0';
      increment_pipe_4 <= '0';
      slice_count      <= 0;
      slice_count_1    <= 0;
		elsif (rising_edge(clk)) then
      slice_count_1    <= slice_count;
      increment_pipe_1 <= increment_module_i;
      increment_pipe_2 <= increment_pipe_1;
      increment_pipe_3 <= increment_pipe_2;
      increment_pipe_4 <= increment_pipe_3;

      valid_cnt_data <= '0';
      increment_module_i <= '0';
      if (read_mode = '1') then
        module_status <= status_out(to_integer(unsigned(slice_data(Mod_ID_width - status_bits -1 downto 0))));
        module_status_2 <= module_status;
      end if;

      if ((read_mode = '1' and read_mode_i = '0') or (read_mode = '1' and increment_pipe_4 = '1' and slice_count_1 < N_slices)) then
        valid_cnt_data <= '1';
      end if;

      if (read_mode = '1' and unsigned(data_count) < 6 and slice_count < N_slices) then
        increment_module_i <= '1';
      end if;

      if (Read_State = Root) then
        slice_count <= 0;
      end if;
      if (Read_State = Slice and slice_data(Mod_ID_width) = '1') then
        slice_count <= slice_count + 1;
      end if;

      if (Read_State = Reseting) then
        increment_module_i <= '0';
        module_status    <= '0';
        module_status_2  <= '0';
        valid_cnt_data   <= '0';
        increment_pipe_1 <= '0';
        increment_pipe_2 <= '0';
        increment_pipe_3 <= '0';
        increment_pipe_4 <= '0';
        slice_count      <= 0;
        slice_count_1    <= 0;
      end if;
		end if;
	end process read_cnt;
  increment_module <= increment_module_i;


  read_raw : process(clk)
	begin
		if (reset = '1') then
      count_target <= 0;
      read_count <= 0;
      read_address <= (others => '0');
      reading <= false;
      read_buff <= '0';
      data_count_1 <= (others => '0');
      data_count_2 <= (others => '0');
		elsif (rising_edge(clk)) then
      data_count_1 <= data_count;
      data_count_2 <= data_count_1;
      read_buff <= '0';
      valid_raw_i <= '0';
      valid_out <= valid_raw_i;
      if (Read_State = Slice and unsigned(data_count_2) > 0 and not reading) then
      -- if (valid_cnt_data = '1' and module_status = '1') then
        count_target <= to_integer(unsigned(cnt_buff_o(CNT_width-1 downto RAW_address_bits)));
        read_address <= cnt_buff_o(RAW_address_bits-1 downto 0);
        read_count <= 0;
        reading <= true;
        read_buff <= '1';
      end if;
      if (reading) then
        read_count <= read_count + 1;
        read_address <= std_logic_vector(unsigned(read_address) + 1);
        valid_raw_i <= '1';
      end if;
      if (read_count = count_target-1) then
        reading <= false;
        if (read_mode = '1' and unsigned(data_count_2) > 0) then
        -- if (valid_cnt_data = '1' and module_status = '1') then
          count_target <= to_integer(unsigned(cnt_buff_o(CNT_width-1 downto RAW_address_bits)));
          read_address <= cnt_buff_o(RAW_address_bits-1 downto 0);
          read_count <= 0;
          reading <= true;
          read_buff <= '1';
        end if;
      end if;

      if (Read_State = Reseting) then
        count_target <= 0;
        read_count <= 0;
        read_address <= (others => '0');
        reading <= false;
        read_buff <= '0';
        data_count_1 <= (others => '0');
        data_count_2 <= (others => '0');
      end if;
		end if;
	end process read_raw;


  write_output : process(clk)
	begin
		if (reset = '1') then
      data_out   <= (others => '0');
      valid_data <= '0';
		elsif (rising_edge(clk)) then
      data_out   <= (others => '0');
      valid_data <= '0';
      if (event_valid = '1') then
        data_out   <= event_data_o;
        valid_data <= event_valid;
      end if;
      if (valid_out = '1') then
        data_out   <= raw_data_o;
        valid_data <= valid_out;
      end if;
		end if;
	end process write_output;


end Behavioral;
