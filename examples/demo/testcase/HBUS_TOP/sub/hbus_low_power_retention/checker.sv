// assertion for hbus_low_power_retention
property p_hbus_low_power_retention;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_low_power_retention);
