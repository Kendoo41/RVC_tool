// assertion for hbus_qos_arbiter_priority
property p_hbus_qos_arbiter_priority;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_qos_arbiter_priority);
