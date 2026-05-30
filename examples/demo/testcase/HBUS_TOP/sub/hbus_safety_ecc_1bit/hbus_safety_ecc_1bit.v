// stimulus for hbus_safety_ecc_1bit
module hbus_safety_ecc_1bit_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
