// stimulus for hbus_qos_bandwidth_limit
module hbus_qos_bandwidth_limit_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
