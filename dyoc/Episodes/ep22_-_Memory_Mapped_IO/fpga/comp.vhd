library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

Library xpm;
use xpm.vcomponents.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute all instructions.
--
-- Additionally, the CPU registers are shown on the VGA display.
-- The registers shown are:
-- * WREN (1 byte) and DATA OUT (1 byte)
-- * ADDR (2 bytes)
-- * HI (1 byte) and LO (1 byte)
-- * DATA IN (1 byte) and 'A' register (1 byte)
-- * PC (2 bytes)
-- * Instruction Register (1 byte) and Instruction Cycle Count (1 bytes)
--
-- The speed of the execution is controlled by the slide switches.

entity comp is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);
      led_o     : out std_logic_vector(7 downto 0);
      rstn_i    : in  std_logic;

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture structural of comp is

   constant C_OVERLAY_BITS : integer := 176;
   constant C_FONT_FILE    : string := "font8x8.txt";

   -- MAIN Clock domain
   signal main_clk      : std_logic;
   signal main_rst      : std_logic;
   signal main_wait     : std_logic;
   signal main_overlay  : std_logic_vector(C_OVERLAY_BITS-1 downto 0);
   signal main_memio_wr : std_logic_vector(8*32-1 downto 0);
   signal main_memio_rd : std_logic_vector(8*32-1 downto 0);

   -- VGA Clock doamin
   signal vga_clk           : std_logic;
   signal vga_rst           : std_logic;
   signal vga_overlay_en    : std_logic;
   signal vga_overlay       : std_logic_vector(C_OVERLAY_BITS-1 downto 0);
   signal vga_char_addr     : std_logic_vector( 12 downto 0);
   signal vga_char_data     : std_logic_vector(  7 downto 0);
   signal vga_col_addr      : std_logic_vector( 12 downto 0);
   signal vga_col_data      : std_logic_vector(  7 downto 0);
   signal vga_memio_palette : std_logic_vector(127 downto 0);
   signal vga_memio_pix_x   : std_logic_vector( 15 downto 0);
   signal vga_memio_pix_y   : std_logic_vector( 15 downto 0);

begin
   
   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   clk_inst : entity work.clk_wiz_0_clk_wiz
   port map (
      clk_in1  => clk_i,
      eth_clk  => open, -- Not needed yet.
      vga_clk  => vga_clk,
      main_clk => main_clk
   ); -- clk_inst


   --------------------------------------------------
   -- Generate Reset
   --------------------------------------------------

   main_rst_proc : process (main_clk)
   begin
      if rising_edge(main_clk) then
         main_rst <= not rstn_i;
      end if;
   end process main_rst_proc;
   
   vga_rst_proc : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_rst <= not rstn_i;
      end if;
   end process vga_rst_proc;
   
   
   --------------------------------------------------
   -- Instantiate Waiter
   --------------------------------------------------

   waiter_inst : entity work.waiter
   port map (
      clk_i  => main_clk,
      sw_i   => sw_i,
      wait_o => main_wait
   ); -- waiter_inst


   --------------------------------------------------
   -- Instantiate main
   --------------------------------------------------

   main_inst : entity work.main
   generic map (
      G_OVERLAY_BITS => C_OVERLAY_BITS
   )
   port map (
      main_clk_i      => main_clk,
      main_rst_i      => main_rst,
      main_wait_i     => main_wait,
      main_led_o      => led_o,
      main_overlay_o  => main_overlay,
      main_memio_wr_o => main_memio_wr,
      main_memio_rd_i => main_memio_rd,
      --
      vga_clk_i       => vga_clk,
      vga_char_addr_i => vga_char_addr,
      vga_char_data_o => vga_char_data,
      vga_col_addr_i  => vga_col_addr,
      vga_col_data_o  => vga_col_data
   ); -- main_inst


   --------------------------------------------------
   -- Instantiate clock crossing from MAIN to VGA
   --------------------------------------------------

   cdc_overlay_inst : entity work.cdc
   generic map (
      G_WIDTH => C_OVERLAY_BITS
   )
   port map (
      src_clk_i  => main_clk,
      src_rst_i  => main_rst,
      src_data_i => main_overlay,
      dst_clk_i  => vga_clk,
      dst_data_o => vga_overlay
   ); -- cdc_overlay_inst


   vga_overlay_en <= not sw_i(7);

   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   vga_inst : entity work.vga
   generic map (
      G_OVERLAY_BITS => C_OVERLAY_BITS,
      G_FONT_FILE    => C_FONT_FILE
   )
   port map (
      clk_i           => vga_clk,
      overlay_i       => vga_overlay_en,
      digits_i        => vga_overlay,
      --
      char_addr_o     => vga_char_addr,
      char_data_i     => vga_char_data,
      col_addr_o      => vga_col_addr,
      col_data_i      => vga_col_data,
      --
      memio_palette_i => vga_memio_palette,
      memio_pix_x_o   => vga_memio_pix_x,
      memio_pix_y_o   => vga_memio_pix_y,
      --
      vga_hs_o        => vga_hs_o,
      vga_vs_o        => vga_vs_o,
      vga_col_o       => vga_col_o
   ); -- vga_inst


   --------------------------------------------------
   -- Memory Mapped I/O
   -- This must match the mapping in prog/include/memorymap.h
   --------------------------------------------------

   -- 7FC0 - 7FCF : VGA_PALETTE
   cdc_vga_memio_palette_inst : entity work.cdc
   generic map (
      G_WIDTH => 128
   )
   port map (
      src_clk_i  => main_clk,
      src_rst_i  => main_rst,
      src_data_i => main_memio_wr(15*8+7 downto 0*8),
      dst_clk_i  => vga_clk,
      dst_data_o => vga_memio_palette
   ); -- cdc_vga_memio_palette

   -- 7FD0 - 7FDF : Not used
   --                     memio_wr(31*8+7 downto 16*8);      -- Not used


   -- 7FE0 - 7FE1 : VGA_PIX_X
   cdc_vga_memio_pix_x_inst : entity work.cdc
   generic map (
      G_WIDTH => 16
   )
   port map (
      src_clk_i  => vga_clk,
      src_rst_i  => vga_rst,
      src_data_i => vga_memio_pix_x,
      dst_clk_i  => main_clk,
      dst_data_o => main_memio_rd(1*8+7 downto 0*8)
   ); -- cdc_vga_memio_pix_x

   -- 7FE2 - 7FE3 : VGA_PIX_Y
   cdc_vga_memio_pix_y : entity work.cdc
   generic map (
      G_WIDTH => 16
   )
   port map (
      src_clk_i  => vga_clk,
      src_rst_i  => vga_rst,
      src_data_i => vga_memio_pix_y,
      dst_clk_i  => main_clk,
      dst_data_o => main_memio_rd(3*8+7 downto 2*8)
   ); -- cdc_vga_memio_pix_y

   -- 7FE4 - 7FFF : Not used
   main_memio_rd(31*8+7 downto  4*8) <= (others => '0');   -- Not used

end architecture structural;

