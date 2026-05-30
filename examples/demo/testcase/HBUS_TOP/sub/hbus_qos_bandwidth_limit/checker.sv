// assertion for hbus_qos_bandwidth_limit
property p_hbus_qos_bandwidth_limit;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_qos_bandwidth_limit);
