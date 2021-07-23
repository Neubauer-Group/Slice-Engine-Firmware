----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03/30/2021 03:48:26 PM
-- Design Name:
-- Module Name: slice_engine_decoder - Behavioral
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


entity slice_engine_decoder is
  Port (
  clk         : in std_logic;
  reset       : in std_logic;

  data_in     : in std_logic_vector(63 downto 0);
  meta_data   : in std_logic;
  valid_data  : in std_logic;

  event_data  : out STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
  event_word  : out INTEGER := 0;
  head_we     : out STD_LOGIC := '0';
  foot_we     : out STD_LOGIC := '0';

  event_start : out STD_LOGIC := '0';
  event_end   : out STD_LOGIC := '0';

  raw_data    : out STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  raw_address : out STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '1');
  raw_we      : out STD_LOGIC := '0';
  cnt_data    : out STD_LOGIC_VECTOR(CNT_width-1 downto 0) := (others => '0');
  cnt_address : out STD_LOGIC_VECTOR(CNT_address_bits-1 downto 0) := (others => '0');
  cnt_we      : out STD_LOGIC := '0'
  );
end slice_engine_decoder;

architecture Behavioral of slice_engine_decoder is

  type Data_t is (Header, Footer, Modual, Idle);
  signal Data_type : Data_t := Idle;

  signal data_i : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
  signal meta_i : STD_LOGIC := '0';
  signal meta_i2 : STD_LOGIC := '0';
  signal word_count : INTEGER := 0;
  signal raw_we_i : STD_LOGIC := '0';
  signal raw_address_i : STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '1');


begin

  raw_we <= raw_we_i;
  raw_address <= raw_address_i;

  data_pipe : process(clk)
	begin
		if (reset = '1') then
			word_count <= 0;
			Data_type <= Idle;
			data_i <= (others => '0');
      meta_i <= '0';
      meta_i2 <= '0';
		elsif (rising_edge(clk)) then
			data_i <= data_in;
      meta_i <= meta_data;
      meta_i2 <= meta_i;
			if (valid_data = '1') then
				word_count <= word_count + 1;
				if (meta_data = '1') then
					word_count <= 0;
					if ( data_in( Flag_Bit + Flag_Length - 1 downto Flag_Bit) = Header_Flag) then
						Data_type <= Header;
					elsif ( data_in( Flag_Bit + Flag_Length - 1 downto Flag_Bit) = Footer_Flag) then
						Data_type <= Footer;
					elsif ( data_in( Flag_Bit + Flag_Length - 1 downto Flag_Bit) = Modual_Flag) then
						Data_type <= Modual;
					end if;
				end if;
			else
				if (Data_type = Footer and word_count = Footer_Length - 1) then
					word_count <= 0;
					Data_type <= Idle;
				end if;
			end if;
		end if;
	end process data_pipe;


  write_raw : process(clk)
	begin
		if (reset = '1') then
      raw_address_i   <= (others => '1');
      raw_we_i      <= '0';
      raw_data      <= (others => '0');
		elsif (rising_edge(clk)) then
      if (Data_type = Modual) then
        raw_address_i <= std_logic_vector(unsigned(raw_address_i) + 1);
        raw_we_i    <= '1';
        raw_data    <= data_i;
      else
        raw_address_i <= (others => '1');
  	    raw_we_i    <= '0';
        raw_data    <= (others => '0');
      end if;
		end if;
	end process write_raw;


  write_cnt : process(clk)
	begin
		if (reset = '1') then
      cnt_address   <= (others => '0');
			cnt_we        <= '0';
      cnt_data      <= (others => '0');
		elsif (rising_edge(clk)) then
      cnt_we        <= '0';
      if (meta_i = '1') then
        cnt_address <= data_in(Mod_ID_width + Mod_ID_location -1 downto Mod_ID_location);
      end if;
      if (meta_i2 = '1' and raw_we_i = '1') then
        cnt_data(RAW_address_bits-1 downto 0) <= raw_address_i;
      end if;
      if (meta_data = '1' and raw_we_i = '1') then
        cnt_data(Mod_count_width + RAW_address_bits-1 downto RAW_address_bits) <= std_logic_vector(to_unsigned(word_count + 1, Mod_count_width));
        cnt_we      <= '1';
      end if;
		end if;
	end process write_cnt;


  write_event : process(clk)
	begin
		if (reset = '1') then
      event_data    <= (others => '0');
      event_word    <= 0;
      head_we       <= '0';
      foot_we       <= '0';
      event_start   <= '0';
      event_end     <= '0';
		elsif (rising_edge(clk)) then
      event_start   <= '0';
      event_end     <= '0';
      if (Data_type = Header) then
        event_data  <= data_i;
        event_word  <= word_count;
        head_we     <= '1';
        foot_we     <= '0';
        if (word_count = 0) then
          event_start <= '1';
        end if;
      elsif (Data_type = Footer) then
        event_data  <= data_i;
        event_word  <= word_count;
        head_we     <= '0';
        foot_we     <= '1';
        if (word_count = Footer_Length - 1) then
          event_end <= '1';
        end if;
      else
        event_data  <= (others => '0');
        event_word  <= 0;
        head_we     <= '0';
        foot_we     <= '0';
      end if;
		end if;
	end process write_event;


end Behavioral;
