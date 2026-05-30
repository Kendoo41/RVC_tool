// stimulus for hbus_safety_ecc_2bit
module hbus_safety_ecc_2bit_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
