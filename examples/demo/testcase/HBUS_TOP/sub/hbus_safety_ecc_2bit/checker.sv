// assertion for hbus_safety_ecc_2bit
property p_hbus_safety_ecc_2bit;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_safety_ecc_2bit);
