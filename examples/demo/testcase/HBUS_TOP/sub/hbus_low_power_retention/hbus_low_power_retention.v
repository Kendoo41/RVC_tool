// stimulus for hbus_low_power_retention
module hbus_low_power_retention_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
