// stimulus for hbus_reg_default_value
module hbus_reg_default_value_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
