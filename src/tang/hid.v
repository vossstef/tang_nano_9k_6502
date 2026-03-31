/*
    hid.v
 
    hid (keyboard, mouse etc) interface to the IO MCU

    c64 core specific variant of hid
  */

module hid (
  input               clk,
  input               reset,

  input               data_in_strobe,
  input               data_in_start,
  input [7:0]         data_in,
  output reg [7:0]    data_out,

  // input local db9 port events to be sent to MCU
  input  [5:0]        db9_port,
  output reg          irq,
  input               iack,
  output reg [7:0]    usb_kbd,
  output reg          kbd_strobe,

  // ps2 alternative interface.
  // [10] toggles with every press/release [9] pressed, [8] extended [7:0] key
  output reg [10:0]   ps2_key,
  output              ps2_kbd_clk,
  output              ps2_kbd_data,

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

ps2_device keyboard (
    .clk_sys(clk),

    .wdata(kbd_data),
    .we(kbd_we),

    .ps2_clk(clk_ps2),
    .ps2_clk_out(ps2_kbd_clk),
    .ps2_dat_out(ps2_kbd_data),
    .tx_empty(),

    .ps2_clk_in(1'b1),
    .ps2_dat_in(1'b1),

    .rdata(),
    .rd(1'b0)
);

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
               if(state == 4'd2)
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
               if(state == 4'd3)
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
               if(state == 4'd4)
                    ps2_key_raw[31:0] <= {ps2_key_raw[23:0], data_in};
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

module ps2_device #(parameter PS2_FIFO_BITS=5)
(
	input        clk_sys,

	input  [7:0] wdata,
	input        we,

	input        ps2_clk,
	output reg   ps2_clk_out,
	output reg   ps2_dat_out,
	output reg   tx_empty,

	input        ps2_clk_in,
	input        ps2_dat_in,

	output [8:0] rdata,
	input        rd
);


reg [7:0] fifo[1<<PS2_FIFO_BITS];

reg [PS2_FIFO_BITS-1:0] wptr;
reg [PS2_FIFO_BITS-1:0] rptr;

reg [2:0] rx_state = 0;
reg [3:0] tx_state = 0;

reg       has_data;
reg [7:0] data;
assign    rdata = {has_data, data};

always@(posedge clk_sys) begin
	reg [7:0] tx_byte;
	reg parity;
	reg r_inc;
	reg old_clk;
	reg [1:0] timeout;

	reg [3:0] rx_cnt;

	reg c1,c2,d1;

	tx_empty <= ((wptr == rptr) && (tx_state == 0));

	if(we && !has_data) begin
		fifo[wptr] <= wdata;
		wptr <= wptr + 1'd1;
	end

	if(rd) has_data <= 0;

	c1 <= ps2_clk_in;
	c2 <= c1;
	d1 <= ps2_dat_in;
	if(!rx_state && !tx_state && ~c2 && c1 && ~d1) begin
		rx_state <= rx_state + 1'b1;
		ps2_dat_out <= 1;
	end

	old_clk <= ps2_clk;
	if(~old_clk & ps2_clk) begin

		if(rx_state) begin
			case(rx_state)
				1: begin
						rx_state <= rx_state + 1'b1;
						rx_cnt <= 0;
					end

				2: begin
						if(rx_cnt <= 7) data <= {d1, data[7:1]};
						else rx_state <= rx_state + 1'b1;
						rx_cnt <= rx_cnt + 1'b1;
					end

				3: if(d1) begin
						rx_state <= rx_state + 1'b1;
						ps2_dat_out <= 0;
					end

				4: begin
						ps2_dat_out <= 1;
						has_data <= 1;
						rx_state <= 0;
						rptr     <= 0;
						wptr     <= 0;
					end
			endcase
		end else begin

			// transmitter is idle?
			if(tx_state == 0) begin
				// data in fifo present?
				if(c2 && c1 && d1 && wptr != rptr) begin

					timeout <= timeout - 1'd1;
					if(!timeout) begin
						tx_byte <= fifo[rptr];
						rptr <= rptr + 1'd1;

						// reset parity
						parity <= 1;

						// start transmitter
						tx_state <= 1;

						// put start bit on data line
						ps2_dat_out <= 0;			// start bit is 0
					end
				end
			end else begin

				// transmission of 8 data bits
				if((tx_state >= 1)&&(tx_state < 9)) begin
					ps2_dat_out <= tx_byte[0];	          // data bits
					tx_byte[6:0] <= tx_byte[7:1]; // shift down
					if(tx_byte[0])
						parity <= !parity;
				end

				// transmission of parity
				if(tx_state == 9) ps2_dat_out <= parity;

				// transmission of stop bit
				if(tx_state == 10) ps2_dat_out <= 1;    // stop bit is 1

				// advance state machine
				if(tx_state < 11) tx_state <= tx_state + 1'd1;
					else tx_state <= 0;
			end
		end
	end

	if(~old_clk & ps2_clk) ps2_clk_out <= 1;
	if(old_clk & ~ps2_clk) ps2_clk_out <= ((tx_state == 0) && (rx_state<2));

end

endmodule
