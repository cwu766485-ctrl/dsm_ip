## =============================================================
## cartesian_dsm.xdc
## Target: RFSoC 4x2 (xczu48dr-ffvg1517-2-e)
## Top module: adtx_rfsoc4x2_top
## =============================================================

## -------------------------------------------------------------
## Clock: 100 MHz differential PL clock (HP bank pair, AM15/AN15)
## SYS_CLK_100M_P = AM15 / SYS_CLK_100M_N = AN15
## Internal 100 ohm differential termination is enabled in the top-level IBUFDS.
## -------------------------------------------------------------
set_property PACKAGE_PIN AM15 [get_ports SYS_CLK_100M_P]
set_property PACKAGE_PIN AN15 [get_ports SYS_CLK_100M_N]
set_property IOSTANDARD LVDS  [get_ports SYS_CLK_100M_P]
set_property IOSTANDARD LVDS  [get_ports SYS_CLK_100M_N]

create_clock -name sysclk100 -period 10.000 [get_ports SYS_CLK_100M_P]

## -------------------------------------------------------------
## Reset: PB_4 port mapped to AN12 / URST_B, active-low (HP bank, LVCMOS18)
## -------------------------------------------------------------
set_property PACKAGE_PIN AN12    [get_ports PB_4]
set_property IOSTANDARD LVCMOS18 [get_ports PB_4]

## -------------------------------------------------------------
## Enable: SW_0 slide-switch on AN13 (HP bank, LVCMOS18)
## -------------------------------------------------------------
set_property PACKAGE_PIN AN13    [get_ports SW_0]
set_property IOSTANDARD LVCMOS18 [get_ports SW_0]

## -------------------------------------------------------------
## RF output lanes: SYZYGY_D0..D3 (Bank 84, HD, LVCMOS18 pseudo-differential)
## NOTE: HD bank does NOT support OBUFDS+LVDS.
##       SYZYGY_D*_P/N are driven as complementary single-ended LVCMOS18 outputs.
## -------------------------------------------------------------
set_property PACKAGE_PIN AU2     [get_ports SYZYGY_D0_P]
set_property IOSTANDARD LVCMOS18 [get_ports SYZYGY_D0_P]
set_property SLEW FAST           [get_ports SYZYGY_D0_P]
set_property DRIVE 8             [get_ports SYZYGY_D0_P]

set_property PACKAGE_PIN AU1     [get_ports SYZYGY_D0_N]
set_property IOSTANDARD LVCMOS18 [get_ports SYZYGY_D0_N]
set_property SLEW FAST           [get_ports SYZYGY_D0_N]
set_property DRIVE 8             [get_ports SYZYGY_D0_N]

## Output timing: unconstrained (RF bitstream, not a system I/F)
set_output_delay -clock sysclk100 0.0 [get_ports SYZYGY_D0_P]
set_output_delay -clock sysclk100 0.0 [get_ports SYZYGY_D0_N]

foreach {port pin} {
  SYZYGY_D1_P A7
  SYZYGY_D1_N A6
  SYZYGY_D2_P AV3
  SYZYGY_D2_N AV2
  SYZYGY_D3_P C8
  SYZYGY_D3_N C7
} {
  set p [get_ports -quiet $port]
  if {[llength $p]} {
    set_property PACKAGE_PIN $pin $p
    set_property IOSTANDARD LVCMOS18 $p
    set_property SLEW FAST $p
    set_property DRIVE 8 $p
    set_output_delay -clock sysclk100 0.0 $p
  }
}

## -------------------------------------------------------------
## LEDs on HP banks (LVCMOS18)
## -------------------------------------------------------------
set_property PACKAGE_PIN AR11    [get_ports W_LED_0]
set_property IOSTANDARD LVCMOS18 [get_ports W_LED_0]

set_property PACKAGE_PIN AW10    [get_ports W_LED_1]
set_property IOSTANDARD LVCMOS18 [get_ports W_LED_1]

## -------------------------------------------------------------
## Bitstream config
## -------------------------------------------------------------
set_property BITSTREAM.CONFIG.UNUSEDPIN     PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS     TRUE   [current_design]
