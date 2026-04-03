module keyboard
  (input  wire clk,
   input  wire reset,
   input  wire ps2_data,
   input  wire ps2_clk,
   output reg  [7:0] data,
   output reg        valid,
   input  wire       ready
   );

   // ------------------------------------------------------------
   // State machine
   // ------------------------------------------------------------
   localparam state_idle        = 5'b00001;
   localparam state_keymap      = 5'b00010;
   localparam state_key_down    = 5'b00100;
   localparam state_key_up      = 5'b01000;
   localparam state_esc_char    = 5'b10000;

   localparam esc = 8'h1b;

   localparam keycode_regular  = 2'b0x;
   localparam keycode_modifier = 2'b10;
   localparam keycode_escaped  = 2'b11;

   reg [4:0] state;

   // ------------------------------------------------------------
   // PS/2 receiver signals
   // ------------------------------------------------------------
   reg [1:0]  ps2_sync      = 2'b11;
   reg [1:0]  ps2_clk_filt  = 2'b11;
   reg [10:0] ps2_shift     = 11'd0;
   reg [3:0]  ps2_bitcount  = 4'd0;

   wire ps2_falling_edge;

   reg [7:0] ps2_byte       = 8'd0;
   reg [7:0] new_byte       = 8'd0;

   reg ps2_break_keycode    = 1'b0;
   reg ps2_long_keycode     = 1'b0;

   // ------------------------------------------------------------
   // Modifier state
   // ------------------------------------------------------------
   reg [5:0] modifier_pressed = 6'd0;
   wire shift_pressed   = modifier_pressed[5] || modifier_pressed[0];
   wire control_pressed = modifier_pressed[4] || modifier_pressed[1];
   wire meta_pressed    = modifier_pressed[3] || modifier_pressed[2];

   reg caps_lock_active;

   // ------------------------------------------------------------
   // Keymap ROM
   // ------------------------------------------------------------
   wire [10:0] keymap_address;
   wire [7:0]  keymap_data;

   reg [7:0] special_data = 8'd0;

   assign keymap_address = {
       ps2_long_keycode,
       caps_lock_active,
       shift_pressed,
       ps2_byte
   };

   keymap_rom keymap_rom(
       .clk (clk),
       .addr(keymap_address),
       .dout(keymap_data)
   );

   // ------------------------------------------------------------
   // AXI-style output gating
   // ------------------------------------------------------------
   wire can_send = !valid || ready;

   // ------------------------------------------------------------
   // PS/2 clock synchronizer
   // ------------------------------------------------------------
   always @(posedge clk) begin
       ps2_sync <= { ps2_sync[0], ps2_clk };
   end

   // ------------------------------------------------------------
   // Falling-edge detector
   // ------------------------------------------------------------
   always @(posedge clk) begin
       ps2_clk_filt <= { ps2_clk_filt[0], ps2_sync[1] };
   end

   assign ps2_falling_edge =
       (ps2_clk_filt[1] == 1'b1 && ps2_clk_filt[0] == 1'b0);

   // ------------------------------------------------------------
   // PS/2 parity + framing check
   // ------------------------------------------------------------
   wire start_ok = (ps2_shift[0]  == 1'b0);
   wire stop_ok  = (ps2_shift[10] == 1'b1);

   wire computed_parity =
       ~(ps2_shift[8] ^ ps2_shift[7] ^ ps2_shift[6] ^
         ps2_shift[5] ^ ps2_shift[4] ^ ps2_shift[3] ^
         ps2_shift[2] ^ ps2_shift[1]);

   wire parity_ok = (computed_parity == ps2_shift[9]);

   // ------------------------------------------------------------
   // Main logic
   // ------------------------------------------------------------
   always @(posedge clk) begin
      if (reset) begin
         state <= state_idle;
         data  <= 8'd0;
         valid <= 1'b0;

         ps2_shift    <= 11'd0;
         ps2_bitcount <= 4'd0;
         ps2_byte     <= 8'd0;

         ps2_break_keycode <= 1'b0;
         ps2_long_keycode  <= 1'b0;

         modifier_pressed  <= 6'd0;
         caps_lock_active  <= 1'b1;
         special_data      <= 8'd0;
      end
      else if (valid && ready) begin
         // AXI: clear valid only when transfer completes
         valid <= 1'b0;
      end
      else begin
         // --------------------------------------------------------
         // PS/2 receiver (bit-aligned, parity-checked)
         // --------------------------------------------------------
         if (ps2_falling_edge) begin
            case (ps2_bitcount)
              4'd0: ps2_shift[0]  <= ps2_data; // start
              4'd1: ps2_shift[1]  <= ps2_data; // data0
              4'd2: ps2_shift[2]  <= ps2_data; // data1
              4'd3: ps2_shift[3]  <= ps2_data; // data2
              4'd4: ps2_shift[4]  <= ps2_data; // data3
              4'd5: ps2_shift[5]  <= ps2_data; // data4
              4'd6: ps2_shift[6]  <= ps2_data; // data5
              4'd7: ps2_shift[7]  <= ps2_data; // data6
              4'd8: ps2_shift[8]  <= ps2_data; // data7
              4'd9: ps2_shift[9]  <= ps2_data; // parity
              4'd10: begin
                  ps2_shift[10] <= ps2_data;    // stop
                  ps2_bitcount  <= 4'd0;

                  if (start_ok && stop_ok && parity_ok) begin
                      new_byte  = ps2_shift[8:1];
                      ps2_byte <= new_byte;

                      if (new_byte == 8'hE0) begin
                          ps2_long_keycode  <= 1'b1;
                          ps2_break_keycode <= 1'b0;
                      end
                      else if (new_byte == 8'hF0) begin
                          ps2_break_keycode <= 1'b1;
                      end
                      else begin
                          state <= state_keymap;
                      end
                  end
                  else begin
                      ps2_long_keycode  <= 1'b0;
                      ps2_break_keycode <= 1'b0;
                  end
              end
            endcase

            if (ps2_bitcount != 4'd10)
                ps2_bitcount <= ps2_bitcount + 1'b1;
         end

         // --------------------------------------------------------
         // State machine
         // --------------------------------------------------------
         case (state)

           state_idle: begin
               // idle; PS/2 receiver above will move us to keymap
           end

           state_keymap: begin
               state <= ps2_break_keycode ? state_key_up : state_key_down;
           end

           state_key_up: begin
               ps2_break_keycode <= 1'b0;
               ps2_long_keycode  <= 1'b0;
               state             <= state_idle;

               if (keymap_data[7:6] == keycode_modifier)
                   modifier_pressed <= modifier_pressed & ~keymap_data[5:0];
           end

           state_key_down: begin
               ps2_long_keycode <= 1'b0;

               if (keymap_data == 8'd0) begin
                   state <= state_idle;
               end
               else begin
                   casex (keymap_data[7:6])

                     keycode_regular: begin
                        if (can_send) begin
                           if (meta_pressed) begin
                               data  <= esc;
                               valid <= 1'b1;
                               state <= state_esc_char;
                               special_data <= {
                                   1'b0,
                                   control_pressed ? 2'b00 : keymap_data[6:5],
                                   keymap_data[4:0]
                               };
                           end
                           else begin
                               data  <= {
                                   1'b0,
                                   control_pressed ? 2'b00 : keymap_data[6:5],
                                   keymap_data[4:0]
                               };
                               valid <= 1'b1;
                               state <= state_idle;
                           end
                        end
                     end

                     keycode_escaped: begin
                        if (can_send) begin
                           data  <= esc;
                           valid <= 1'b1;
                           state <= state_esc_char;
                           special_data <= {
                               1'b0,
                               control_pressed ? 2'b00 : keymap_data[6:5],
                               keymap_data[4:0]
                           };
                        end
                     end

                     keycode_modifier: begin
                        state            <= state_idle;
                        modifier_pressed <= modifier_pressed | keymap_data[5:0];
                        caps_lock_active <= caps_lock_active ^ ~|keymap_data[5:0];
                     end

                   endcase
               end
           end

           state_esc_char: begin
               if (valid == 0 && can_send) begin
                   data  <= {
                       1'b0,
                       control_pressed ? 2'b00 : special_data[6:5],
                       special_data[4:0]
                   };
                   valid <= 1'b1;
                   state <= state_idle;
               end
           end

         endcase
      end
   end
endmodule
