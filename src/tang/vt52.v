module vt52 (
            input clk,
            input clk_pixel,
            input uart_clk,
            input pll_lock,
            output hsync,
            output vsync,
            output vblank,
            output hblank,
            output video,
            output led,
            input [7:0] usb_kbd,
            input kbd_strobe,
            input  rxd,
            output txd
            );
   localparam ROWS = 25;
   localparam COLS = 80;
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;


   // scroll
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;
   wire [ADDR_BITS-1:0] first_char;
   // cursor
   wire [ROW_BITS-1:0]  new_cursor_y;
   wire [COL_BITS-1:0]  new_cursor_x;
   wire new_cursor_wen;
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;
   // char buffer
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   wire [ADDR_BITS-1:0] char_address;
   wire [7:0] char;
   // char rom
   wire [11:0] char_rom_address;
   wire [7:0] char_rom_data;

   // uart input/output
   wire [7:0] uart_out_data;
   wire uart_out_valid;

   reg [7:0] uart_in_data, uart_in_data_d,uart_in_data_d1;
   reg uart_in_valid, uart_in_valid_d, uart_in_valid_d1;
   wire uart_in_ready;

   // led follows the cursor blink
   assign led = cursor_blink_on;

   keyboard keyboard(.clk(clk),
                     .reset(~pll_lock),
                     .usb_kbd(usb_kbd),
                     .kbd_strobe(kbd_strobe),
                     .data(uart_in_data),
                     .valid(uart_in_valid),
                     .ready(1'b1) //uart_in_ready)
                   );

   cursor #(.ROW_BITS(ROW_BITS), .COL_BITS(COL_BITS))
      cursor(.clk(clk),
             .reset(~pll_lock),
             .tick(vblank),
             .x(cursor_x),
             .y(cursor_y),
             .blink_on(cursor_blink_on),
             .new_x(new_cursor_x),
             .new_y(new_cursor_y),
             .wen(new_cursor_wen)
            );

   simple_register #(.SIZE(ADDR_BITS))
      scroll_register(.clk(clk),
                      .reset(~pll_lock),
                      .idata(new_first_char),
                      .wen(new_first_char_wen),
                      .odata(first_char)
                      );

   char_buffer char_buffer(.clk(clk),
                           .din(new_char),
                           .waddr(new_char_address),
                           .wen(new_char_wen),
                           .raddr(char_address),
                           .dout(char)
                           );

   char_rom char_rom(.clk(clk),
                     .addr(char_rom_address),
                     .dout(char_rom_data)
                     );

   video_generator video_generator(
                      .clk(clk_pixel),
                      .reset(~pll_lock),
                      .hsync(hsync),
                      .vsync(vsync),
                      .video(video),
                      .hblank(hblank),
                      .vblank(vblank),
                      .cursor_x(cursor_x),
                      .cursor_y(cursor_y),
                      .cursor_blink_on(cursor_blink_on),
                      .first_char(first_char),
                      .char_buffer_address(char_address),
                      .char_buffer_data(char),
                      .char_rom_address(char_rom_address),
                      .char_rom_data(char_rom_data)
                      );

   wire uart_rxd_int;

   sync_signal #(
      .WIDTH(1),
      .N(4))
   sync_signal_inst (
      .clk(uart_clk),
      .in(rxd),
      .out(uart_rxd_int)
   );

reg strobe;

always @(posedge uart_clk) begin
   {uart_in_data_d1 , uart_in_data_d}  <= {uart_in_data_d , uart_in_data};
   {uart_in_valid_d1, uart_in_valid_d} <= {uart_in_valid_d, uart_in_valid};

    strobe <= 1'b0;
    if (!uart_in_valid_d1 && uart_in_valid_d)
          strobe <= 1'b1;
    end

   wire fifo_full;
   uart uart(
      .clk(uart_clk),
      .rst(~pll_lock),
      .rxd(uart_rxd_int),

      .txd(txd),
       // uart pipeline in (keyboard->usb)
      .s_axis_tdata(uart_in_data),
      .s_axis_tvalid(strobe),
      .s_axis_tready(uart_in_ready),

      // uart pipeline out
      .m_axis_tdata(uart_out_data),
      .m_axis_tvalid(uart_out_valid),
      .m_axis_tready(fifo_full),
      // status
      .tx_busy(),
      .rx_busy(),
      .rx_overrun_error(),
      .rx_frame_error(),
      //config
 //   .prescale(16'd4) // x8 oversampling 50400000/(115200*8))
      .prescale(50400000/(115200*8))
      );

   wire [7:0] fifo_data;
   wire fifo_valid, fifo_ready;

   fifo_async #(
      .DW(8),
      .EA(128))
   fifo_async(
      .i_rstn(pll_lock),
      .i_clk(uart_clk),
      .i_tready(fifo_full),
      .i_tvalid(uart_out_valid),
      .i_tdata(uart_out_data),

      .o_rstn(pll_lock),
      .o_clk(clk),
      .o_tready(fifo_ready),
      .o_tvalid(fifo_valid),
      .o_tdata(fifo_data)
   );

   command_handler #(.ROWS(ROWS),
                     .COLS(COLS),
                     .ROW_BITS(ROW_BITS),
                     .COL_BITS(COL_BITS),
                     .ADDR_BITS(ADDR_BITS))
      command_handler(.clk(clk),
                      .reset(~pll_lock),
                      .data(fifo_data),
                      .valid(fifo_valid),
                      .ready(fifo_ready),
                      .new_first_char(new_first_char),
                      .new_first_char_wen(new_first_char_wen),
                      .new_char(new_char),
                      .new_char_address(new_char_address),
                      .new_char_wen(new_char_wen),
                      .new_cursor_x(new_cursor_x),
                      .new_cursor_y(new_cursor_y),
                      .new_cursor_wen(new_cursor_wen)
                      );

 endmodule
