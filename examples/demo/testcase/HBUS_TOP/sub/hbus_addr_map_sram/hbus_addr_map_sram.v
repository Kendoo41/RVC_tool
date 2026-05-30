// stimulus for hbus_addr_map_sram
module hbus_addr_map_sram_stim;
  initial begin
    #10 force top.dut.qos_en = 1'b1;
    #100 release top.dut.qos_en;
  end
endmodule
