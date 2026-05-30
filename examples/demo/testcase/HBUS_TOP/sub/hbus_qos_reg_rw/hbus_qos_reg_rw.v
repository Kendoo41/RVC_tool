// stimulus for hbus_qos_reg_rw
module hbus_qos_reg_rw_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
