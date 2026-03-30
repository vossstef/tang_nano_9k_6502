module keyboard(
   input clk,
   input reset,
   input [7:0] usb_kbd,
   input kbd_strobe,
   output reg [7:0] data,
   output reg valid,
   input ready
   );

   reg old_kbd_strobe;
   reg [7:0] usb_kbd_d, usb_kbd_d1;

   always @(posedge clk) begin
      old_kbd_strobe <= kbd_strobe;
      if (old_kbd_strobe != kbd_strobe) 
           usb_kbd_d <= usb_kbd;
   end

   wire [15:0] ps2keycode;
   keymap keymap (
   .code ( usb_kbd_d[6:0] ),
   .ps2 ( ps2keycode )
   );

   // state: one hot encoding
   // idle is the normal state, reading the ps/2 bus
   // key up/down (long and short) are for key events
   // keymap_read is for reading the keymap rom
   // esc_char is for sending ESC- prefixed chars
   localparam state_idle        = 5'b00001;
   localparam state_keymap      = 5'b00010;
   localparam state_key_down    = 5'b00100;
   localparam state_key_up      = 5'b01000;
   localparam state_esc_char    = 5'b10000;

   localparam esc = 8'h1b;

   localparam keycode_regular = 2'b0x;
   localparam keycode_modifier = 2'b10;
   localparam keycode_escaped = 2'b11;

   reg [4:0] state;
   reg [7:0]  ps2_byte;
   // we are processing a break_code (key up)
   reg ps2_break_keycode;
   // we are processing a long keycode (two bytes)
   reg ps2_long_keycode;
   // shift, control & meta key status, bit order:
   // lshift, lcontrol, lmeta, rmeta, rcontrol, rshift
   // alt/meta key status, vt52 doesn't have meta, but I want to use
   // emacs & can't stand that Esc- business, so alt sends esc+keypress
   reg [5:0] modifier_pressed;
   wire shift_pressed = modifier_pressed[5] || modifier_pressed[0];
   wire control_pressed = modifier_pressed[4] || modifier_pressed[1];
   wire meta_pressed = modifier_pressed[3] || modifier_pressed[2];
   // caps lock
   reg caps_lock_active;
   // keymap
   wire [10:0] keymap_address;
   wire [7:0] keymap_data;
   // special char to send after ESC
   reg [7:0] special_data;

   // ps2_byte is the actual keycode, we use long/short keycode, caps lock &
   // shift to determine the plane we need
   assign keymap_address = { ps2_long_keycode, caps_lock_active, shift_pressed, ps2_byte };

   // address is 3 bits for longkeycode/capslock/shift + 8 bits for keycode
   // data is on of
   // 0xxxxxxx: regular ASCII key
   // 10xxxxxx: control/meta/shift or caps lock, each bit is a key, all 0 for caps lock
   // 11xxxxxx: special key, ESC + upper case ASCII (clear msb to get char)
   keymap_rom keymap_rom(.clk(clk),
                         .addr(keymap_address),
                         .dout(keymap_data)
                         );

reg old_kbd_strobe_d;
   // we don't need to do this on the pixel clock, we could use
   // something way slower, but it works
   always @(posedge clk) begin
      if (reset) begin
         state <= state_idle;

         data <= 0;
         valid <= 0;

         ps2_byte <= 0;

         ps2_break_keycode <= 0;
         ps2_long_keycode <= 0;

         modifier_pressed = 6'h00;
         caps_lock_active <= 1;  // default caps lock active to get capital characters
         special_data <= 0;
      end
      else if (valid && ready) begin
         // as soon as data is transmitted, clear valid
         valid <= 0;
      end
      else begin
        old_kbd_strobe_d <= old_kbd_strobe;
        usb_kbd_d1 <= usb_kbd_d;
        case (state)
          state_idle: begin
            if (old_kbd_strobe != old_kbd_strobe_d) begin
                  ps2_byte <= ps2keycode[7:0];
                  if (ps2keycode[15:8] == 8'hE0) begin
                     ps2_break_keycode <= 0;
                     ps2_long_keycode <= 1;
                  end
                  else if ( usb_kbd_d1[7] ) begin
                     ps2_break_keycode <= 1;
                     state <= state_key_up;
                  end
                  else begin
                     ps2_break_keycode <= 0;
                     state <= state_key_down;
                  end
             end
          end
          state_key_up: begin
             // on key up we only care about released modifiers
             ps2_break_keycode <= 0;
             ps2_long_keycode <= 0;
             state <= state_idle;
             if (keymap_data[7:6] == keycode_modifier) begin
                // the released modifier is in keymap_data[5:0]
                // or 0 for caps lock
                modifier_pressed <= modifier_pressed & ~keymap_data[5:0];
             end
          end
          state_key_down: begin
             ps2_long_keycode <= 0;
             if (keymap_data == 0) begin
                // unrecognized key, just go back to idle
                state <= state_idle;
             end
             else begin
                casex (keymap_data[7:6])
                  keycode_regular: begin
                     // regular key, apply modifiers:
                     // control turns off 7th & 6th bits
                     // meta sends an ESC prefix
                     if (meta_pressed) begin
                        data <= esc;
                        valid <= 1;
                        state <= state_esc_char;
                        special_data <= {
                                         1'b0,
                                         control_pressed? 2'b00 : keymap_data[6:5],
                                         keymap_data[4:0]
                                         };
                     end
                     else begin
                        data <= {
                                 1'b0,
                                 control_pressed? 2'b00 : keymap_data[6:5],
                                 keymap_data[4:0]
                                 };
                        valid <= 1;
                        state <= state_idle;
                     end
                  end
                  keycode_escaped: begin
                     // escaped char, send Esc- and then the ascii value
                     // including the leading 1 (only uppercase and some symbols)
                     data <= esc;
                     valid <= 1;
                     state <= state_esc_char;
                     special_data <= {
                                      1'b0,
                                      control_pressed? 2'b00 : keymap_data[6:5],
                                      keymap_data[4:0]
                                      };
                  end
                  keycode_modifier: begin
                     // the pressed modifier is in keymap_data[5:0], or 0 for caps lock
                     state <= state_idle;
                     modifier_pressed <= modifier_pressed | keymap_data[5:0];
                     caps_lock_active <= caps_lock_active ^ ~|keymap_data[5:0];
                  end
                endcase
             end // else: !if(keymap_data == 0)
          end // case: state_keymap_down
          state_esc_char: begin
             // only send special char after ESC was successfully sent
             if (valid == 0) begin
                state <= state_idle;
                data <= {
                         1'b0,
                         control_pressed? 2'b00 : special_data[6:5],
                         special_data[4:0]
                         };
                valid <= 1;
             end
          end
        endcase // case (state)
      end // else: !if(valid && ready)
   end // always @ (posedge clk)
endmodule
