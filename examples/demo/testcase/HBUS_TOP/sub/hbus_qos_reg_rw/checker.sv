// assertion for hbus_qos_reg_rw
property p_hbus_qos_reg_rw;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_qos_reg_rw);
