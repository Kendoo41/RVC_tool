// stimulus for hbus_err_response_slverr
module hbus_err_response_slverr_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
