// assertion for hbus_clock_gating
property p_hbus_clock_gating;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_clock_gating);
