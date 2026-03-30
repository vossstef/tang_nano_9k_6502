# tang_nano_9k_6502
A [6502](https://en.wikipedia.org/wiki/MOS_Technology_6502) SBC in a [Gowin](https://www.gowinsemi.com/en/product/detail/49/) FPGA on a [Sipeed Tang Nano 9k](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html) and [Sipeed Tang Nano 20k](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html).  
<br>
Ported [ricktw](https://github.com/riktw) project [6502_HDMI](https://github.com/riktw/tang4Kramblings) to a Tang Nano 9k/20k<br>
Further description of the original project over [here](https://justanotherelectronicsblog.com/?p=986) using sources from [display_controller](https://github.com/projf/display_controller) and [vt52](https://github.com/AndresNavarro82/vt52-fpga) <br>

Features
* HDMI Video Output 640x480
* VT52 Terminal 80x25
* [MS BASIC](https://github.com/mist64/msbasic)
* PS/2 Keyboard
* RAM 4K
* **TN20k** uses [FPGA-Companion](https://github.com/MiSTle-Dev/FPGA-Companion) for USB Keyboard Input 

## ToDo at Startup
A green blinking cursor will apear.<br>
Cold[C] or warm [W] start ?<br>
Answer by a 'c' keypress<br>
MEMORY SIZE?<br>
Answer by typing 4095<br>
TERMINAL WIDTH?<br>
Answer by typing 80<br>
System shall response with BASIC xy and OK promt<br>

## Tang Push Button utilization
* S1 push button Reset

## Powering
TN9k and Keyboard can be powered by Tang USB-C connector from PC or a Power Supply Adapter.  
TN20k need PD USB Hub.  

## Synthesis
Source code can be synthesized, fitted and programmed with GOWIN IDE Windows or Linux.

## Pin mapping 
see pin configuration in .cst configuration file

## TN9k HW circuit considerations
- PS/2 keyboard has to be connected to 3.3V tolerant FPGA via level shifter to avoid damage of inputs ! Use e.g. 2 pcs SN74LVC1G17DBVR 5V to 3V3 level shifter. My Keyboard has internal pull-up resistors to 5V for Clock and Data Signals so didn't needed external ones. 
- Tang Nano 5V output connected to Keyboard supply. Tang 3V3 output to level shifter supply.


**Pinmap PS2 Interface TN9k** <br>
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