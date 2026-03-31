-- This file is copyright by Grant Searle 2014
-- You are free to use this file in your own projects but must never charge for it nor use it without
-- acknowledgement.
-- Please ask permission from Grant Searle before republishing elsewhere.
-- If you use this file or any part of it, please add an acknowledgement to myself and
-- a link back to my main web site http://searle.hostei.com/grant/    
-- and to the "multicomp" page at http://searle.hostei.com/grant/Multicomp/index.html
--
-- Please check on the above web pages to see if there are any updates before using this file.
-- If for some reason the page is no longer available, please search for "Grant Searle"
-- on the internet to see if I have moved to another web hosting service.
--
-- Grant Searle
-- eMail address available on my main web page link above.

library ieee;
use ieee.std_logic_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity Microcomputer is
port(
    reset           : in std_logic;
    clk             : in std_logic;
    tmds_clk_p      : out std_logic;
    tmds_clk_n      : out std_logic;
    tmds_d_p        : out std_logic_vector(2 downto 0);
    tmds_d_n        : out std_logic_vector(2 downto 0);
    LED             : out std_logic_vector(5 downto 0);
    user_button     : in std_logic;
    -- SPI connection to onboard BL616
    spi_sclk        : in std_logic;
    spi_csn         : in std_logic;
    spi_dir         : out std_logic;
    spi_dat         : in std_logic;
    spi_irqn        : out std_logic;
    --
    sd_clk          : out std_logic;
    sd_cmd          : inout std_logic;
    sd_dat          : inout std_logic_vector(3 downto 0);

    ws2812          : out std_logic
  );
end Microcomputer;

architecture struct of Microcomputer is

signal	sdCS		: std_logic;
signal	sdMOSI		:  std_logic;
signal	sdMISO		:  std_logic;
signal	sdSCLK		:  std_logic;

signal n_WR: std_logic;
signal n_RD: std_logic;
signal cpuAddress: std_logic_vector(23 downto 0);
signal cpuDataOut: std_logic_vector(7 downto 0);
signal cpuDataIn: std_logic_vector(7 downto 0);

signal basRomData: std_logic_vector(7 downto 0);
signal internalRam1DataOut: std_logic_vector(7 downto 0);
signal internalRam2DataOut: std_logic_vector(7 downto 0);
signal interface1DataOut: std_logic_vector(7 downto 0);
signal interface2DataOut: std_logic_vector(7 downto 0);
signal sdCardDataOut: std_logic_vector(7 downto 0);

signal n_memWR: std_logic :='1';
signal n_memRD : std_logic :='1';

signal n_ioWR: std_logic :='1';
signal n_ioRD : std_logic :='1';

signal n_MREQ: std_logic :='1';
signal n_IORQ: std_logic :='1';

signal n_int1: std_logic :='1';
signal n_int2: std_logic :='1';

signal n_externalRamCS: std_logic :='1';
signal n_internalRam1CS: std_logic :='1';
signal n_internalRam2CS: std_logic :='1';
signal n_basRomCS: std_logic :='1';
signal n_interface1CS: std_logic :='1';
signal n_interface2CS: std_logic :='1';
signal n_sdCardCS: std_logic :='1';

signal serialClkCount: std_logic_vector(15 downto 0);
signal cpuClkCount: std_logic_vector(5 downto 0); 
signal sdClkCount: std_logic_vector(5 downto 0); 
signal cpuClock: std_logic;
signal serialClock: std_logic;
signal sdClock: std_logic;

signal videoG0      : std_logic;
signal videoG         : std_logic_vector(3 downto 0);
signal hSync          : std_logic;
signal vSync          : std_logic;
signal vblank         : std_logic;
signal hblank         : std_logic;

signal uartrx       : std_logic;
signal uarttx       : std_logic;
signal rts1         : std_logic;

signal clk_pixel_x10  : std_logic;
signal clk_pixel_x5   : std_logic;
signal clk_pixel_x2   : std_logic;
signal clk_pixel      : std_logic;
signal pll_lock       : std_logic;
signal spi_io_din     : std_logic;
signal spi_io_ss      : std_logic;
signal spi_io_clk     : std_logic;
signal spi_io_dout    : std_logic;
signal int_out_n      : std_logic;
signal mcu_data_out   : std_logic_vector(7 downto 0);
signal hid_data_out   : std_logic_vector(7 downto 0);
signal osd_data_out   : std_logic_vector(7 downto 0) :=  X"55";
signal sys_data_out   : std_logic_vector(7 downto 0);
signal sdc_data_out   : std_logic_vector(7 downto 0);
signal hid_int        : std_logic;
signal usb_kbd        : std_logic_vector(7 downto 0);
signal int_ack        : std_logic_vector(7 downto 0);
signal mcu_sys_strobe : std_logic;
signal mcu_hid_strobe : std_logic;
signal mcu_osd_strobe : std_logic;
signal mcu_start      : std_logic;
signal kbd_strobe     : std_logic;
signal ws2812_color   : std_logic_vector(23 downto 0);
signal sdc_int        : std_logic :='0';
signal sdc_iack       : std_logic;
signal mcu_sdc_strobe : std_logic;
signal system_reset   : std_logic_vector(1 downto 0);
signal system_scanlines : std_logic_vector(1 downto 0);
signal ps2_key        : std_logic_vector(10 downto 0);
signal ps2_kbd_clk    : std_logic;
signal ps2_kbd_data   : std_logic;
signal reset_counter  : unsigned(15 downto 0) := (others => '0');
signal reset_n_internal : std_logic := '0';

component CLKDIV
    generic (
        DIV_MODE : STRING := "2";
        GSREN: in string := "false"
    );
    port (
        CLKOUT: out std_logic;
        HCLKIN: in std_logic;
        RESETN: in std_logic;
        CALIB: in std_logic
    );
end component;

begin

  -- map output data onto both spi outputs
  spi_io_din  <= spi_dat;
  spi_io_ss   <= spi_csn;
  spi_io_clk  <= spi_sclk;
  spi_dir     <= spi_io_dout;
  spi_irqn    <= int_out_n;

-- 252Mhz and 126Mhz
pll_inst: entity work.Gowin_rPLL_126mhz
    port map (
        reset   => reset,
        clkout  => clk_pixel_x10,
        clkoutd => clk_pixel_x5,
        lock    => pll_lock,
        clkin   => clk
    );

-- 252Mhz to 50.4Mhz
div_inst: CLKDIV
generic map(
    DIV_MODE => "5",
    GSREN    => "false"
)
port map(
    CLKOUT => clk_pixel_x2,
    HCLKIN => clk_pixel_x10,
    RESETN => pll_lock,
    CALIB  => '0'
);

-- 126Mhz to 25.2 Mhz
div3_inst: CLKDIV
generic map(
    DIV_MODE => "5",
    GSREN    => "false"
)
port map(
    CLKOUT => clk_pixel,
    HCLKIN => clk_pixel_x5,
    RESETN => pll_lock,
    CALIB  => '0'
);

led_ws2812: entity work.ws2812
  port map
  (
   clk    => clk_pixel,
   color  => ws2812_color,
   data   => ws2812
  );


mcu_spi_inst: entity work.mcu_spi 
port map (
  clk            => clk_pixel,
  reset          => not pll_lock,
  -- SPI interface to BL616 MCU
  spi_io_ss      => spi_io_ss,      -- SPI CSn
  spi_io_clk     => spi_io_clk,     -- SPI SCLK
  spi_io_din     => spi_io_din,     -- SPI MOSI
  spi_io_dout    => spi_io_dout,    -- SPI MISO
  -- byte interface to the various core components
  mcu_sys_strobe => mcu_sys_strobe, -- byte strobe for system control target
  mcu_hid_strobe => mcu_hid_strobe, -- byte strobe for HID target  
  mcu_osd_strobe => mcu_osd_strobe, -- byte strobe for OSD target
  mcu_sdc_strobe => mcu_sdc_strobe, -- byte strobe for SD card target
  mcu_start      => mcu_start,
  mcu_sys_din    => sys_data_out,
  mcu_hid_din    => hid_data_out,
  mcu_osd_din    => osd_data_out,
  mcu_sdc_din    => sdc_data_out,
  mcu_dout       => mcu_data_out
);

-- decode SPI/MCU data received for human input devices (HID) 
hid_inst: entity work.hid
 port map 
 (
  clk             => clk_pixel,
  reset           => not pll_lock,
  -- interface to receive user data from MCU (mouse, kbd, ...)
  data_in_strobe  => mcu_hid_strobe,
  data_in_start   => mcu_start,
  data_in         => mcu_data_out,
  data_out        => hid_data_out,

  -- input local db9 port events to be sent to MCU
  db9_port        => 6x"00",
  irq             => hid_int,
  iack            => int_ack(1),

  -- output HID data received from USB
  usb_kbd         => usb_kbd,
  kbd_strobe      => kbd_strobe,
  ps2_key         => ps2_key,
  ps2_kbd_clk     => ps2_kbd_clk,
  ps2_kbd_data    => ps2_kbd_data,
  joystick0       => open,
  joystick1       => open,
  mouse_btns      => open,
  mouse_x         => open,
  mouse_y         => open,
  mouse_strobe    => open,
  joystick0ax     => open,
  joystick0ay     => open,
  joystick1ax     => open,
  joystick1ay     => open,
  joystick_strobe => open,
  extra_button0   => open,
  extra_button1   => open
  );

module_inst: entity work.sysctrl 
 port map 
 (
  clk                 => clk_pixel,
  reset               => not pll_lock,
--
  data_in_strobe      => mcu_sys_strobe,
  data_in_start       => mcu_start,
  data_in             => mcu_data_out,
  data_out            => sys_data_out,
  -- values that can be configured by the user
  system_reset        => system_reset,
  system_scanlines    => system_scanlines,
  -- port io (used to expose rs232)
  port_status         => (others=>'0'),
  port_out_available  => (others=>'0'),
  port_out_strobe     => open,
  port_out_data       => (others=>'0'),
  port_in_available   => (others=>'0'),
  port_in_strobe      => open,
  port_in_data        => open,

  int_out_n           => int_out_n,
  int_in              => unsigned'(x"0" & sdc_int & '0' & hid_int & '0'),
  int_ack             => int_ack,

  buttons             => unsigned'(user_button & reset),
  leds                => open,
  color               => ws2812_color
);

videoG  <= "1111" when videoG0 = '1' else "0000";

sdc_iack <= int_ack(3);

sd_card_inst: entity work.sd_card
generic map (
    CLK_DIV  => 0
  )
    port map (
    rstn            => pll_lock,
    clk             => clk_pixel,
  
    -- SD card signals
    sdclk           => sd_clk,
    sdcmd           => sd_cmd,
    sddat           => sd_dat,

    -- mcu interface
    data_strobe     => mcu_sdc_strobe,
    data_start      => mcu_start,
    data_in         => mcu_data_out,
    data_out        => sdc_data_out,

    -- interrupt to signal communication request
    irq             => sdc_int,
    iack            => sdc_iack,

    -- output file/image information. Image size is e.g. used by fdc to 
    -- translate between sector/track/side and lba sector
    image_size      => open,
    image_mounted   => open,

    -- user read sector command interface (sync with clk)
    rstart          => (others=>'0'),
    wstart          => (others=>'0'), 
    rsector         => (others=>'0'),
    rbusy           => open,
    rdone           => open,

    -- sector data output interface (sync with clk)
    inbyte          => (others=>'0'), -- sector data output interface (sync with clk)
    outen           => open, -- when outen=1, a byte of sector content is read out from outbyte
    outaddr         => open, -- outaddr from 0 to 511, because the sector size is 512
    outbyte         => open  -- a byte of sector content
);

video_inst: entity work.video 
port map(
      pll_lock   => pll_lock,
      clk        => clk_pixel,
      clk_pixel_x5 => clk_pixel_x5,
      audio_div  => (others=>'0'),
      ntscmode  => '1',
      vb_in     => vblank,
      hb_in     => hblank,
      hs_in_n   => hSync,
      vs_in_n   => vSync,

      r_in      => "0000",
      g_in      => videoG,
      b_in      => "0010",

      audio_l => (others=>'0'),
      audio_r => (others=>'0'),
      osd_status => open,

      mcu_start => mcu_start,
      mcu_osd_strobe => mcu_osd_strobe,
      mcu_data  => mcu_data_out,

      -- values that can be configure by the user via osd
      system_wide_screen => '0',
      system_scanlines => system_scanlines,
      system_volume => "00",

      tmds_clk_n => tmds_clk_n,
      tmds_clk_p => tmds_clk_p,
      tmds_d_n   => tmds_d_n,
      tmds_d_p   => tmds_d_p
      );

process(clk_pixel_x2)
begin
	if rising_edge(clk_pixel_x2) then
		if pll_lock = '0' then
			reset_counter <= (others => '0');
			reset_n_internal <= '0';
		else
			if reset_counter /= unsigned'(X"FFFF") then
				reset_counter <= reset_counter + 1;
				reset_n_internal <= '0';
			else
				reset_n_internal <= '1';
			end if;
		end if;
	end if;
end process;

-- CPU CHOICE GOES HERE
cpu1 : entity work.T65
port map(
    Enable => '1',
    Mode => "00",
    Res_n => reset_n_internal, -- '0' when pll_lock = '0' or system_reset(0) = '1' else '1',
    Clk => cpuClock,
    Rdy => '1',
    Abort_n => '1',
    IRQ_n => '1',
    NMI_n => '1',
    SO_n => '1',
    R_W_n => n_WR,
    A => cpuAddress,
    DI => cpuDataIn,
    DO => cpuDataOut
);
-- ____________________________________________________________________________________
-- ROM GOES HERE
 -- 8KB BASIC
rom1 : entity work.basicRom
port map(
    ad => cpuAddress(12 downto 0),
    clk => clk_pixel_x2,
    dout => basRomData,
    reset => '0',
    ce => '1',
    oce => '1'
);
-- ____________________________________________________________________________________
-- RAM GOES HERE
ram1: entity work.Gowin_SP
port map
(
    ad => cpuAddress(11 downto 0),
    clk => clk_pixel_x2,
    din => cpuDataOut,
    wre => not(n_memWR or n_internalRam1CS),
    dout => internalRam1DataOut,
    reset => '0',
    ce => '1',
    oce => '1'
);

-- ____________________________________________________________________________________
-- INPUT/OUTPUT DEVICES GO HERE

vt52inst: entity work.vt52
port map (
    clk         => clk_pixel_x2, -- 50.4Mhz
    clk_pixel   => clk_pixel,    -- 25.2Mhz
    uart_clk    => serialClock, -- 1.8MHz
    pll_lock    => pll_lock,
    hsync       => hSync,
    vsync       => vSync,
    vblank      => vblank,
    hblank      => hblank,
    video       => videoG0,
    led         => open,
    usb_kbd     => usb_kbd,
    kbd_strobe  => kbd_strobe,
    ps2_clk     => ps2_kbd_clk,
    ps2_data    => ps2_kbd_data,
    rxd         => uarttx,
    txd         => uartrx
);

io1 : entity work.bufferedUART
port map(
    clk => clk_pixel_x2,
    n_wr => n_interface1CS or cpuClock or n_WR,
    n_rd => n_interface1CS or cpuClock or (not n_WR),
    n_int => n_int1,
    regSel => cpuAddress(0),
    dataIn => cpuDataOut,
    dataOut => interface1DataOut,
    rxClock => serialClock, -- 16 x baud rate 1.843 MHz, 115200 baud × 16
    txClock => serialClock,
    rxd => uartrx,
    txd => uarttx,
    n_cts => '0',
    n_dcd => '0',
    n_rts => rts1
);

-- Tang nano 9k LED
LED(5 downto 0) <= "111111";

sd1 : entity work.sd_controller
port map(
	sdCS => sdCS,
	sdMOSI => sdMOSI,
	sdMISO => sdMISO,
	sdSCLK => sdSCLK,
	n_wr => n_sdCardCS or cpuClock or n_WR,
	n_rd => n_sdCardCS or cpuClock or (not n_WR),
	n_reset => pll_lock,
	dataIn => cpuDataOut,
	dataOut => sdCardDataOut,
	regAddr => cpuAddress(2 downto 0),
	driveLED => open,
	clk => sdClock -- twice the spi clk
);

-- ____________________________________________________________________________________
-- MEMORY READ/WRITE LOGIC GOES HERE

n_memRD <= not(cpuClock) nand n_WR;
n_memWR <= not(cpuClock) nand (not n_WR);

-- ____________________________________________________________________________________
-- CHIP SELECTS GO HERE

n_basRomCS <= '0' when cpuAddress(15 downto 13) = "111" else '1'; --8K at top of memory
n_interface1CS <= '0' when cpuAddress(15 downto 1) = "111111111101000" else '1'; -- 2 bytes FFD0-FFD1
n_interface2CS <= '0' when cpuAddress(15 downto 1) = "111111111101001" else '1'; -- 2 bytes FFD2-FFD3
n_sdCardCS <= '0' when cpuAddress(15 downto 3) = "1111111111011" else '1'; -- 8 bytes FFD8-FFDF
n_internalRam1CS <= '0' when cpuAddress(15 downto 12) = "0000" else '1';    -- 4K internal RAM
-- ____________________________________________________________________________________
-- BUS ISOLATION GOES HERE
cpuDataIn <=
    interface1DataOut when n_interface1CS = '0' else
    interface2DataOut when n_interface2CS = '0' else
    sdCardDataOut when n_sdCardCS = '0' else
    basRomData when n_basRomCS = '0' else
    internalRam1DataOut when n_internalRam1CS= '0' else
    x"FF";

-- SYSTEM CLOCKS GO HERE

serialClock <= serialClkCount(15); -- 1.843 MHz

process (clk_pixel_x2)
begin
if rising_edge(clk_pixel_x2) then

    if cpuClkCount < 4 then -- 4 = 10MHz, 3 = 12.5MHz, 2=16.6MHz, 1=25MHz
        cpuClkCount <= cpuClkCount + 1;
    else
        cpuClkCount <= (others=>'0');
    end if;
    if cpuClkCount < 2 then -- 2 when 10MHz, 2 when 12.5MHz, 2 when 16.6MHz, 1 when 25MHz
        cpuClock <= '0';
    else
        cpuClock <= '1';
    end if;

    if sdClkCount < 49 then -- 1MHz
        sdClkCount <= sdClkCount + 1;
    else
        sdClkCount <= (others=>'0');
    end if;

    if sdClkCount < 25 then
        sdClock <= '0';
    else
        sdClock <= '1';
    end if;

        serialClkCount <= serialClkCount + 2396;
    end if;
end process;
end;
