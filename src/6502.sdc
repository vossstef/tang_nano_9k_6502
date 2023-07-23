//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.11 Education
//Created Time: 2023-07-23 10:41:23
create_clock -name clk -period 37 -waveform {0 18} [get_ports {clk}]
