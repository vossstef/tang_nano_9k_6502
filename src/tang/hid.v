/*
    hid.v
 
    hid (keyboard, mouse etc) interface to the IO MCU

    c64 core specific variant of hid
  */

module hid (
  input wire          clk,
  input wire          reset,

  input wire          data_in_strobe,
  input wire          data_in_start,
  input [7:0]         data_in,
  output reg [7:0]    data_out,

  // input local db9 port events to be sent to MCU
  input  [5:0]        db9_port,
  output reg          irq,
  input  wire         iack,
  output reg [7:0]    usb_kbd,
  output reg          kbd_strobe,

  // ps2 alternative interface.
  // [10] toggles with every press/release [9] pressed, [8] extended [7:0] key
  output reg [10:0]   ps2_key,
  output wire         ps2_kbd_clk,
  output wire         ps2_kbd_data,

  // output HID data received from USB
  output reg [7:0]    joystick0,
  output reg [7:0]    joystick1,
  output reg [7:0]    numpad,
  output reg [1:0]    mouse_btns,
  output reg [7:0]    mouse_x,
  output reg [7:0]    mouse_y,
  output reg          mouse_strobe,
  output reg [7:0]    joystick0ax,
  output reg [7:0]    joystick0ay,
  output reg [7:0]    joystick1ax,
  output reg [7:0]    joystick1ay,
  output reg          joystick_strobe,
  output reg [7:0]    extra_button0,
  output reg [7:0]    extra_button1
);


reg [3:0] state;
reg [7:0] command;
reg [7:0] device;   // used for joystick
reg irq_enable;
reg [5:0] db9_portD;
reg [5:0] db9_portD2;
reg  [7:0] kbd_data;
reg        kbd_we;

// [10] toggles with every press/release [9] pressed, [8] extended [7:0] key

reg [31:0] ps2_key_raw = 0;
reg ps2skip = 1'b0;
wire pressed  = (ps2_key_raw[15:8] != 8'hf0);
wire extended = (~pressed ? (ps2_key_raw[23:16] == 8'he0) : (ps2_key_raw[15:8] == 8'he0));

//kbd_tx(0x69);   // HID: Shift make
//kbd_tx(0x12);   // PS/2: Shift make

//kbd_tx(0x04);   // HID: A make
//kbd_tx(0x1C);   // PS/2: A make

//kbd_tx(0x84);   // HID: A break
//kbd_tx(0xF0);   // PS/2: break
//kbd_tx(0x1C);   // PS/2: A break

//kbd_tx(0xE9);   // HID: Shift break
//kbd_tx(0xF0);   // PS/2: break
//kbd_tx(0x12);   // PS/2: Shift break


//kbd_tx(0x4F);   // HID make (Right Arrow)
//kbd_tx(0xE0);   // PS/2 E0
//kbd_tx(0x74);   // PS/2 make

//kbd_tx(0xCF);   // HID break
//kbd_tx(0xE0);   // PS/2 E0
//kbd_tx(0xF0);   // PS/2 break
//kbd_tx(0x74);   // PS/2 break


// Right Alt pressed
//kbd_tx(0x6E);   // HID modifier make
//kbd_tx(0xE0);   // PS/2 E0
//kbd_tx(0x11);   // PS/2 make

// Right Alt released
//kbd_tx(0xEE);   // HID modifier break (0x80 | 0x6E)
//kbd_tx(0xE0);   // PS/2 E0
//kbd_tx(0xF0);   // PS/2 break
//kbd_tx(0x11);   // PS/2 code

reg clk_ps2;
reg [11:0] cnt = 0;

always @(posedge clk) begin
    if (cnt >= 1250) begin
        cnt <= 0;
        clk_ps2 <= ~clk_ps2;
    end else begin
        cnt <= cnt + 12'd1;
    end
end

wire ps2_clk, ps2_data;

ps2_device keyboard (
    .clk_sys(clk),
    .reset(reset),

    .wdata(kbd_data),
    .we(kbd_we),

    .ps2_clk(clk_ps2),
    .ps2_clk_out(ps2_clk),
    .ps2_dat_out(ps2_data),
    .tx_empty()
);

assign ps2_kbd_clk = ps2_clk;
assign ps2_kbd_data = ps2_data;

always @(posedge clk) begin
   if(reset) begin
      numpad <= 8'h00;
   end else begin
    if (usb_kbd[7])
        numpad <= 8'h00;
    else
        numpad <=
        (usb_kbd[6:0] == 7'h5e)?numpad | 8'h01:
        (usb_kbd[6:0] == 7'h5c)?numpad | 8'h02:
        (usb_kbd[6:0] == 7'h5a)?numpad | 8'h04:
        (usb_kbd[6:0] == 7'h60)?numpad | 8'h08:
        (usb_kbd[6:0] == 7'h62)?numpad | 8'h10:
        (usb_kbd[6:0] == 7'h63)?numpad | 8'h20:8'h00;
    end
end

// process mouse events
always @(posedge clk) begin
   if(reset) begin
      state <= 4'd0;
      mouse_strobe <=1'b0;
      irq <= 1'b0;
      irq_enable <= 1'b0;
      joystick_strobe <= 1'b0; 
      usb_kbd <= 8'h00;
      kbd_strobe <= 1'b0;
      ps2_key_raw <= 0;
      ps2skip <= 1'b0;
      kbd_we <= 1'b0;
   end else begin
      if (data_in_start == 1'b0 && ps2skip == 1'b1) begin
            ps2skip <= 1'b0;
            ps2_key <= {~ps2_key[10], pressed, extended, ps2_key_raw[7:0]};
            if(ps2_key_raw == 'hE012E07C) ps2_key[9:0] <= 'h37C; // prnscr pressed
            if(ps2_key_raw == 'h7CE0F012) ps2_key[9:0] <= 'h17C; // prnscr released
            if(ps2_key_raw == 'hF014F077) ps2_key[9:0] <= 'h377; // pause  pressed
        end

      db9_portD <= db9_port;
      db9_portD2 <= db9_portD;

      // monitor db9 port for changes and raise interrupt
      if(irq_enable) begin
        if(db9_portD2 != db9_portD) begin
            // irq_enable prevents further interrupts until
            // the db9 state has actually been read by the MCU
            irq <= 1'b1;
            irq_enable <= 1'b0;
        end
      end

      if(iack) irq <= 1'b0;      // iack clears interrupt

      mouse_strobe <=1'b0;
      joystick_strobe <=1'b0;
      kbd_we <= 1'b0;
      if(data_in_strobe) begin      
        if(data_in_start) begin
            state <= 4'd0;
            command <= data_in;
            ps2_key_raw <= 0;
            ps2skip <= 1'b0;
        end else begin
            if(state != 4'd15) state <= state + 4'd1;

            // CMD 0: status data
            if(command == 8'd0) begin
                if(state == 4'd0) data_out <= 8'h01;
                if(state == 4'd1) data_out <= 8'h00;
            end

            // CMD 1: keyboard data
            if(command == 8'd1) begin
            // kbd_column and kbd_row are derived from data_in
               if(state == 4'd0) begin
                usb_kbd <= data_in;
                kbd_strobe <= ~kbd_strobe;
               end
               if(state == 4'd1) begin
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
                    ps2skip <= 1'b1;
                    kbd_data <= data_in;
                    kbd_we <= 1'b1;
                end
               if(state == 4'd2) begin
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
                    kbd_data <= data_in;
                    kbd_we <= 1'b1;
                end
               if(state == 4'd3) begin
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
                    kbd_data <= data_in;
                    kbd_we <= 1'b1;
                end
               if(state == 4'd4) begin
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
                    kbd_data <= data_in;
                    kbd_we <= 1'b1;
                end
            end

            // CMD 2: mouse data
            if(command == 8'd2) begin
                if(state == 4'd0) mouse_btns <= data_in[1:0];
                if(state == 4'd1) mouse_x <= data_in;
                if(state == 4'd2) begin
                    mouse_y <= data_in;
                    mouse_strobe <=1'b1;
                end
            end

            // CMD 3: receive digital joystick data
            if(command == 8'd3) begin
                if(state == 4'd0) device <= data_in;
                if(state == 4'd1) begin
                    if(device == 8'd0) joystick0 <= data_in;
                    if(device == 8'd1) joystick1 <= data_in;
                end
                if(state == 4'd2) begin
                        if(device == 8'd0) joystick0ax <= data_in;
                        if(device == 8'd1) joystick1ax <= data_in;
                end
                if(state == 4'd3) begin
                        if(device == 8'd0) joystick0ay <= data_in;
                        if(device == 8'd1) joystick1ay <= data_in;
                end
                if(state == 4'd4) begin
                        if(device == 8'd0) extra_button0 <= data_in;
                        if(device == 8'd1) extra_button1 <= data_in;
                        joystick_strobe <= 1'b1;
                end
            end

            // CMD 4: send digital joystick data to MCU
            if(command == 8'd4) begin
                if(state == 4'd0) irq_enable <= 1'b1;    // (re-)enable interrupt
                data_out <= {2'b00, db9_portD };
            end
        end


      end
   end
end


endmodule

module ps2_device #(
    parameter int PS2_FIFO_BITS = 5
)(
    input  logic       clk_sys,
    input  logic       reset,

    // TX interface (FPGA → host)
    input  logic [7:0] wdata,
    input  logic       we,

    // PS/2 clock (internal)
    input  logic       ps2_clk,
    output logic       ps2_clk_out,
    output logic       ps2_dat_out,
    output logic       tx_empty
);

    // FIFO
    logic [7:0] fifo [0:(1<<PS2_FIFO_BITS)-1];
    logic [PS2_FIFO_BITS-1:0] wptr = '0;
    logic [PS2_FIFO_BITS-1:0] rptr = '0;

    // TX state
    logic [3:0] tx_state = '0;

    // Internal registers (moved out of always block)
    logic [7:0] tx_byte = 8'h00;
    logic       parity  = 1'b1;
    logic       old_clk = 1'b0;
    logic [1:0] timeout = 2'b11;

    // Sequential logic
    always_ff @(posedge clk_sys) begin

        if (reset) begin
            wptr        <= '0;
            rptr        <= '0;
            tx_state    <= '0;
            tx_empty    <= 1'b1;
            ps2_clk_out <= 1'b1;   // idle
            ps2_dat_out <= 1'b1;   // idle
            old_clk     <= ps2_clk;
            timeout     <= 2'b11;
        end else begin

            // TX empty flag
            tx_empty <= ((wptr == rptr) && (tx_state == 0));

            // Write into FIFO
            if (we) begin
                fifo[wptr] <= wdata;
                wptr <= wptr + 1;
            end

            // Edge detect on internal ps2_clk
            old_clk <= ps2_clk;

            if (!old_clk && ps2_clk) begin
                // --------------------
                // TX state machine
                // --------------------
                if (tx_state == 0) begin
                    // idle: check if we have data to send
                    if (wptr != rptr) begin
                        timeout <= timeout - 1;
                        if (timeout == 0) begin
                            tx_byte <= fifo[rptr];
                            rptr    <= rptr + 1;

                            // reset parity (odd parity)
                            parity  <= 1'b1;

                            // start transmitter
                            tx_state    <= 4'd1;
                            ps2_dat_out <= 1'b0;   // start bit
                        end
                    end
                end else begin
                    // 1..8: data bits
                    if (tx_state >= 1 && tx_state < 9) begin
                        ps2_dat_out <= tx_byte[0];
                        if (tx_byte[0])
                            parity <= ~parity;
                        tx_byte <= {1'b0, tx_byte[7:1]};
                    end

                    // 9: parity bit
                    if (tx_state == 9)
                        ps2_dat_out <= parity;

                    // 10: stop bit
                    if (tx_state == 10)
                        ps2_dat_out <= 1'b1;

                    // advance / wrap
                    if (tx_state < 11)
                        tx_state <= tx_state + 1;
                    else begin
                        tx_state <= 0;
                        timeout  <= 2'b11;   // reload timeout
                    end
                end
            end

            // ps2_clk_out: internal "bus free" indicator
            if (!old_clk && ps2_clk)
                ps2_clk_out <= 1'b1;

            if (old_clk && !ps2_clk)
                ps2_clk_out <= (tx_state == 0);
        end
    end

endmodule
