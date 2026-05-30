// assertion for hbus_addr_map_sram
property p_hbus_addr_map_sram;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_addr_map_sram);
