/**
 * Char Buffer RAM (1920x8)
 * (24 lines of 80 characters)
 */
module char_buffer
  #(parameter BUF_SIZE = 2000,
    parameter ADDR_BITS = 11)
   (input  clk,
    input  [7:0] din,
    input  [ADDR_BITS-1:0] waddr,
    input  wen,
    input  [ADDR_BITS-1:0] raddr,
    output reg [7:0] dout
    );

   reg [7:0] mem [BUF_SIZE-1:0];

   initial begin
      //$readmemh("mem/test.hex", mem) ;
      $readmemh("mem/empty.hex", mem) ;
   end

   always @(posedge clk) begin
      if (wen) mem[waddr] <= din;
      dout <= mem[raddr];
   end
endmodule
