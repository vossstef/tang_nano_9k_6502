# tang_nano_9k_6502
[6502](https://en.wikipedia.org/wiki/MOS_Technology_6502) CPU living in a [Gowin GW1NR-9](https://www.gowinsemi.com/en/product/detail/49/) FPGA on a [Sipeed Tang Nano 9k](https://api.dl.sipeed.com/shareURL/TANG/Nano%209K/1_Specification).<br>
<br>
Port of [ricktw](https://github.com/riktw) project [6502_HDMI](https://github.com/riktw/tang4Kramblings) to Tang Nano 9k<br>
Further description of the original project over here [here](https://justanotherelectronicsblog.com/?p=986)<br>


Features
* HDMI DVI Video Output
* VT52 Terminal
* BASIC Interpreter
* PS/2 Keyboard

be aware to type all interpreter commands in CAPITAL letters ! like  LIST RUN etc.

## Tang Push Button utilization
* S1 push button Reset

## Powering
Prototype circuit with Keyboard and Audio Amp can be powered by Tang USB-C connector from PC or a Power Supply Adapter. 

## Synthesis
Source code can be synthesized, fitted and programmed with GOWIN IDE Windows or Linux.

## Pin mapping 
see pin configuration in .cst configuration file

## HW circuit considerations
- PS/2 keyboard has to be connected to 3.3V tolerant FPGA via level shifter to avoid damage of inputs ! Use e.g. 2 pcs SN74LVC1G17DBVR 5V to 3V3 level shifter. My Keyboard has internal pull-up resistors to 5V for Clock and Data Signals so didn't needed external ones. 
- Tang Nano 5V output connected to Keyboard supply. Tang 3V3 output to level shifter supply.


**Pinmap PS2 Interface** <br>
![pinmap](\.assets/ps2conn.png)

| PS2 pin | Tang Nano pin | FPGA pin | PS2 Function |
| ----------- | ---   | --------  | ----- |
| 1 | J6 10  | 77   | DATA  |
| 2 | n.c.  | - | n.c. |
| 3 | J6 23 | - | GND |
| 4 | J6 18 | - | +5V |
| 5 | J6 11| 76 | CLK |
| 6 | n.c. | - | n.c |

### BOM

[Sipeed Tang Nano 9k](https://api.dl.sipeed.com/shareURL/TANG/Nano%209K/1_Specification)<br> 
PS/2 Keyboard<br>
PS/2 Socket Adapter Module<br>
2 pcs [SN74LVC1G17DBVR](http://www.ti.com/document-viewer/SN74LVC1G17/datasheet) level shifter<br>
Prototype Board<br>