module DVI_CLKDIV (clkout, hclkin, resetn, calib);

output wire clkout;
input wire hclkin;
input wire resetn;
input wire calib;

CLKDIV clkdiv_inst (
    .CLKOUT(clkout),
    .HCLKIN(hclkin),
    .RESETN(resetn),
    .CALIB(calib)
);

defparam clkdiv_inst.DIV_MODE = "5";
defparam clkdiv_inst.GSREN = "false";

endmodule
