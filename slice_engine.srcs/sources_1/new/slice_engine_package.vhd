----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 03/30/2021 01:26:51 AM
-- Design Name:
-- Module Name: slice_engine_package - Behavioral
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



--------------------------------------------------------------------------------
-- 1. Package
--------------------------------------------------------------------------------
package slice_engine_package is

  constant data_width       : integer := 64;
  constant N_slices         : integer := 4;
  constant N_memory_banks   : integer := 2; -- Can't be changed

  constant Mod_ID_width     : integer := 18;
  constant Mod_ID_location  : integer := 14+32;
  constant Mod_count_width  : integer := 4;



  -- RAM dimensions
  constant RAW_address_bits : integer := 16;
  constant RAW_depth        : integer := 2**RAW_address_bits;
  constant RAW_width        : integer := data_width;

  constant CNT_address_bits : integer := Mod_ID_width;
  constant CNT_depth        : integer := 2**Mod_ID_width;
  constant CNT_width        : integer := Mod_count_width + RAW_address_bits;

  constant status_bits      : integer := 8;
  constant status_depth     : integer := 2**(status_bits);
  constant status_width     : integer := 2**(Mod_ID_width - status_bits);

  constant Slice_address_bits : integer := 6;
  constant Slice_depth        : integer := 2**Slice_address_bits;
  constant Slice_width        : integer := Mod_ID_width + 1;

  constant RAM_Type         : string := "auto";


  -- Data Blocks
  constant Header_Length  : integer := 6;
  constant Header_Flag    : std_logic_vector(7 downto 0) := X"AB";
  constant Footer_Length  : integer := 3;
  constant Footer_Flag    : std_logic_vector(7 downto 0) := X"CD";
  constant Modual_Flag    : std_logic_vector(7 downto 0) := X"55";
  constant Flag_Length    : integer := 8;
  constant Flag_Bit       : integer := 56;

  type Header_t is array (Header_Length-1 downto 0) of std_logic_vector(data_width-1 downto 0);
  type Footer_t is array (Footer_Length-1 downto 0) of std_logic_vector(data_width-1 downto 0);
  type Status_t is array (status_depth-1 downto 0) of std_logic_vector(status_width-1 downto 0);



end package slice_engine_package;


--------------------------------------------------------------------------------
-- 2. Package Body
--------------------------------------------------------------------------------
package body slice_engine_package is

end package body slice_engine_package;
