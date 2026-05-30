// assertion for hbus_reg_default_value
property p_hbus_reg_default_value;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_reg_default_value);
