// assertion for hbus_addr_map_flash
property p_hbus_addr_map_flash;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_addr_map_flash);
