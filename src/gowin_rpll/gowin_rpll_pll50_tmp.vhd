--Copyright (C)2014-2023 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.11 Education
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Sat Jul 22 23:22:18 2023

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_rPLL_pll50
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: Gowin_rPLL_pll50
    port map (
        clkout => clkout_o,
        clkin => clkin_i
    );

----------Copy end-------------------
