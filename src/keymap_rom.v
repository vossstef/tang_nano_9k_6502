/**
 * Keymap ROM (2KB, maps keycodes to ASCII chars)
 * This could be a RAM to allow keymap modifications, but not for now
 * There's 8 planes for each keycode (controlled by the highest three bits)
 * MSB is for long keycode vs short keycode, the the next two bits:
 * 00: no shift or caps lock
 * 01: just shift
 * 10: just caps lock
 * 11: caps lock & shift
 */
module keymap_rom
  (input wire clk,
   input wire [10:0] addr,
   output reg [7:0] dout
   );

   reg [7:0] mem [2047:0];

   initial begin
      $readmemh("mem/keymap2.hex", mem);
   end

   always @(posedge clk) begin
      dout = mem[addr];
   end

endmodule
