/*
 table to translate from FPGA Compantions key codes into
 key codes for the terminal. The incoming FPGA Companion codes
 are mainly the USB HID key codes with the modifier keys
 mapped into the 0x68+ range.
*/

module keymap (
  input [6:0]  code,
  output [15:0] ps2
);

assign ps2 = 
                           // 00: NoEvent
                           // 01: Overrun Error
                           // 02: POST fail
                           // 03: ErrorUndefined
  // characters
  (code == 7'h04)?16'h001C: // 04: a
  (code == 7'h05)?16'h0032: // 05: b
  (code == 7'h06)?16'h0021: // 06: c
  (code == 7'h07)?16'h0023: // 07: d
  (code == 7'h08)?16'h0024: // 08: e
  (code == 7'h09)?16'h002B: // 09: f
  (code == 7'h0a)?16'h0034: // 0a: g
  (code == 7'h0b)?16'h0033: // 0b: h
  (code == 7'h0c)?16'h0043: // 0c: i
  (code == 7'h0d)?16'h003B: // 0d: j
  (code == 7'h0e)?16'h0042: // 0e: k
  (code == 7'h0f)?16'h004B: // 0f: l
  (code == 7'h10)?16'h003A: // 10: m
  (code == 7'h11)?16'h0031: // 11: n
  (code == 7'h12)?16'h0044: // 12: o
  (code == 7'h13)?16'h004D: // 13: p
  (code == 7'h14)?16'h0015: // 14: q
  (code == 7'h15)?16'h002D: // 15: r
  (code == 7'h16)?16'h001B: // 16: s
  (code == 7'h17)?16'h002C: // 17: t
  (code == 7'h18)?16'h003C: // 18: u
  (code == 7'h19)?16'h002A: // 19: v
  (code == 7'h1a)?16'h001D: // 1a: w
  (code == 7'h1b)?16'h0022: // 1b: x
  (code == 7'h1c)?16'h0035: // 1c: y
  (code == 7'h1d)?16'h001A: // 1d: z
  // top number key row
  (code == 7'h1e)?16'h0016: // 1e: 1
  (code == 7'h1f)?16'h001E: // 1f: 2
  (code == 7'h20)?16'h0026: // 20: 3
  (code == 7'h21)?16'h0025: // 21: 4
  (code == 7'h22)?16'h002E: // 22: 5
  (code == 7'h23)?16'h0036: // 23: 6
  (code == 7'h24)?16'h003D: // 24: 7
  (code == 7'h25)?16'h003E: // 25: 8
  (code == 7'h26)?16'h0046: // 26: 9
  (code == 7'h27)?16'h0045: // 27: 0
  // other keys
  (code == 7'h28)?16'h005A: // 28: return
  (code == 7'h29)?16'h0076: // 29: esc
  (code == 7'h2a)?16'h0066: // 2a: backspace
  (code == 7'h2b)?16'h000D: // 2b: tab		  
  (code == 7'h2c)?16'h0029: // 2c: space
  (code == 7'h2d)?16'h004E: // - (Minus)
  (code == 7'h2e)?16'h0055: // = (Equals)
  (code == 7'h2f)?16'h0054: // [ (Left Bracket)
  (code == 7'h30)?16'h005B: // ] (Right Bracket)
  (code == 7'h31)?16'h005D: // \ (Backslash)
  (code == 7'h32)?16'h002F: // # (non-US keyboard hash)
  (code == 7'h33)?16'h004C: // ; (Semicolon)
  (code == 7'h34)?16'h0052: // ' (Quote)
  (code == 7'h35)?16'h000E: // ` (Grave)
  (code == 7'h36)?16'h0041: // , (Comma)
  (code == 7'h37)?16'h0049: // . (Period)
  (code == 7'h38)?16'h004A: // / (Slash)
  (code == 7'h39)?16'h0058: // Caps Lock
  // function keys
  (code == 7'h3a)?16'h0005: // 3a: F1
  (code == 7'h3b)?16'h0006: // 3b: F2
  (code == 7'h3c)?16'h0004: // 3c: F3
  (code == 7'h3d)?16'h000C: // 3d: F4
  (code == 7'h3e)?16'h0003: // 3e: F5
  (code == 7'h3f)?16'h000B: // 3f: F6
  (code == 7'h40)?16'h0083: // 40: F7
  (code == 7'h41)?16'h000A: // 41: F8
  (code == 7'h42)?16'h0001: // 42: F9
  (code == 7'h43)?16'h0009: // 43: F10
  (code == 7'h44)?16'h0078: // 44: F11
//(code == 7'h45)?16'h0007: // 45: F12 OSD
//(code == 7'h46)?16'hE012: // 46: PrtScr 0xE0, 0x12, 0xE0, 0x7C
  (code == 7'h47)?16'h007E: // 47: Scroll Lock 
//(code == 7'h48)?16'hE114: // 48: Pause/Break {0xE1, 0x14, 0x77, 0xE1, 0xF0, 0x14, 0xE0, 0x77}}
  (code == 7'h49)?16'hE070: // 49: Insert
  (code == 7'h4a)?16'hE06C: // 4a: Home
  (code == 7'h4b)?16'hE07D: // 4b: PageUp
  (code == 7'h4c)?16'hE071: // 4c: Delete
  (code == 7'h4d)?16'hE069: // 4d: End
  (code == 7'h4e)?16'hE07A: // 4e: PageDown
  (code == 7'h4f)?16'hE074: // 4f: right
  (code == 7'h50)?16'hE06B: // 50: left
  (code == 7'h51)?16'hE072: // 51: down
  (code == 7'h52)?16'hE075: // 52: up
  (code == 7'h53)?16'h0077: // 53:// Keyboard Num Lock and Clear
  // keypad
  (code == 7'h54)?16'hE04A: // 54: KP /
  (code == 7'h55)?16'h007C: // 55: KP *
  (code == 7'h56)?16'h007B: // 56: KP -
  (code == 7'h57)?16'h0079: // 57: KP +
  (code == 7'h58)?16'hE05A: // 58: KP Enter
  (code == 7'h59)?16'h0069: // 59: KP 1
  (code == 7'h5a)?16'h0072: // 5a: KP 2
  (code == 7'h5b)?16'h007A: // 5b: KP 3
  (code == 7'h5c)?16'h006B: // 5c: KP 4
  (code == 7'h5d)?16'h0073: // 5d: KP 5
  (code == 7'h5e)?16'h0074: // 5e: KP 6
  (code == 7'h5f)?16'h006C: // 5f: KP 7
  (code == 7'h60)?16'h0075: // 60: KP 8
  (code == 7'h61)?16'h007D: // 61: KP 9
  (code == 7'h62)?16'h0070: // 62: KP 0
  (code == 7'h63)?16'h0071: // 63: KP .
  (code == 7'h64)?16'hE078: // 64: Keyboard non-us \ and |
//(code == 7'h65)?16'hE02F: // 65: App break E0F02F
//(code == 7'h66)?16'hE037: // 66: Keyboard Power break E0F037
  (code == 7'h67)?16'hE077: // 67: Keypad =

  // remapped modifier keys
  (code == 7'h68)?16'h0014: // left ctrl
  (code == 7'h69)?16'h0012: // left shift
  (code == 7'h6a)?16'h0011: // left alt
  (code == 7'h6b)?16'hE01F: // left meta
  (code == 7'h6c)?16'hE014: // right ctrl
  (code == 7'h6d)?16'h0059: // right shift
  (code == 7'h6e)?16'hE011: // right alt
  (code == 7'h6f)?16'hE027: // right meta
  16'h0000;

endmodule

