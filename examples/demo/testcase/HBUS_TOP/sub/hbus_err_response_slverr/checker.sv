// assertion for hbus_err_response_slverr
property p_hbus_err_response_slverr;
  @(posedge clk) req |-> ##[1:3] ack;
endproperty
assert property (p_hbus_err_response_slverr);
