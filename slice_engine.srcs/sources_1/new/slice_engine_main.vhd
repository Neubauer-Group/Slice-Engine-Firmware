----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03/29/2021 07:30:29 PM
-- Design Name:
-- Module Name: slice_engine_main - Behavioral
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
use IEEE.STD_LOGIC_MISC.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.slice_engine_package.all;


entity slice_engine_main is
  Port (
  clk         : in std_logic;
  reset       : in std_logic;
  ready       : out std_logic;

  data_in     : in std_logic_vector(63 downto 0);
  meta_data   : in std_logic;
  valid_data  : in std_logic;

  data_out : out STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  valid_data_out : out STD_LOGIC := '0'
  );
end slice_engine_main;

architecture Behavioral of slice_engine_main is

  component slice_engine_decoder is
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
  end component slice_engine_decoder;


  component slice_engine_RAM_wrapper
    Port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    write_mode  : in  std_logic;
    read_mode   : in  std_logic;

    event_data  : in  STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
    event_word  : in  INTEGER := 0;
    head_we     : in  STD_LOGIC := '0';
    foot_we     : in  STD_LOGIC := '0';

    raw_data    : in  STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
    raw_address : in  STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '1');
    raw_we      : in  STD_LOGIC := '0';
    cnt_data    : in  STD_LOGIC_VECTOR(CNT_width-1 downto 0) := (others => '0');
    cnt_address : in  STD_LOGIC_VECTOR(CNT_address_bits-1 downto 0) := (others => '0');
    cnt_we      : in  STD_LOGIC := '0';

    slice_data  : in STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0) := (others => '0');
    read_done   : out STD_LOGIC := '0';
    increment_module : out STD_LOGIC := '0';

    data_out : out STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
    valid_data : out STD_LOGIC := '0'
    );
  end component slice_engine_RAM_wrapper;


  component slice_engine_controller
    Port (
    clk   : in  std_logic;
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
  end component slice_engine_controller;


  signal event_data  : STD_LOGIC_VECTOR(63 downto 0) := (others => '0');
  signal event_word  : INTEGER := 0;
  signal head_we     : STD_LOGIC := '0';
  signal foot_we     : STD_LOGIC := '0';

  signal event_start : STD_LOGIC := '0';
  signal event_end   : STD_LOGIC := '0';

  signal raw_data    : STD_LOGIC_VECTOR(RAW_width-1 downto 0) := (others => '0');
  signal raw_address : STD_LOGIC_VECTOR(RAW_address_bits-1 downto 0) := (others => '1');
  signal raw_we      : STD_LOGIC := '0';
  signal cnt_data    : STD_LOGIC_VECTOR(CNT_width-1 downto 0) := (others => '0');
  signal cnt_address : STD_LOGIC_VECTOR(CNT_address_bits-1 downto 0) := (others => '0');
  signal cnt_we      : STD_LOGIC := '0';

  signal write_mode  : STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (0 => '1', others => '0');
  signal read_mode   : STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (others => '0');

  signal slice_data  : STD_LOGIC_VECTOR(Slice_width-1 DOWNTO 0) := (others => '0');
  signal read_done   : STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (others => '0');
  signal increment_module : STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (others => '0');

  signal valid_output : STD_LOGIC_VECTOR(N_memory_banks-1 downto 0) := (others => '0');
  type Data_t is array (N_memory_banks-1 downto 0) of std_logic_vector(RAW_width-1 downto 0);
  signal data_output : Data_t := (others => (others => '0'));

begin

  slice_engine_decoder_i : slice_engine_decoder
  port map (
    clk         => clk,
    reset       => reset,

    data_in     => data_in,
    meta_data   => meta_data,
    valid_data  => valid_data,

    event_data  => event_data,
    event_word  => event_word,
    head_we     => head_we   ,
    foot_we     => foot_we   ,

    event_start => event_start ,
    event_end   => event_end ,

    raw_data    => raw_data,
    raw_address => raw_address,
    raw_we      => raw_we,
    cnt_data    => cnt_data,
    cnt_address => cnt_address,
    cnt_we      => cnt_we
  );


  GEN_RAM_wrapper : for i in N_memory_banks-1 downto 0 generate
    slice_engine_RAM_wrapper_i : slice_engine_RAM_wrapper
    port map (
      clk         => clk,
      reset       => reset,

      write_mode  => write_mode(i),
      read_mode   => read_mode(i),

      event_data  => event_data,
      event_word  => event_word,
      head_we     => head_we,
      foot_we     => foot_we,

      raw_data    => raw_data,
      raw_address => raw_address,
      raw_we      => raw_we,
      cnt_data    => cnt_data,
      cnt_address => cnt_address,
      cnt_we      => cnt_we,

      slice_data  => slice_data,
      read_done   => read_done(i),
      increment_module => increment_module(i),
      data_out    => data_output(i),
      valid_data   => valid_output(i)
    );
  end generate GEN_RAM_wrapper;


  slice_engine_controller_i : slice_engine_controller
  port map (
    clk   => clk,
    reset => reset,
    ready => ready,

    event_start => event_start ,
    event_end   => event_end,

    write_mode  => write_mode,
    read_mode   => read_mode,
    slice_data  => slice_data,
    read_done   => or_reduce(read_done),
    increment_module => or_reduce(increment_module)
  );


  data_out <= data_output(0) when valid_output(0) = '1' else
              data_output(1) when valid_output(1) = '1' else
              (others => '0');
  valid_data_out <= or_reduce(valid_output);


end Behavioral;
