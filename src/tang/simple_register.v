/**
 * Basic register with synchronous set & reset
 */
module simple_register
  #(parameter SIZE = 8)
   (input  clk,
    input  reset,
    input  [SIZE-1:0] idata,
    input  wen,
    output reg [SIZE-1:0] odata
    );

   always @(posedge clk) begin
      if (reset) odata <= 0;
      else if (wen) odata = idata;
   end
endmodule
