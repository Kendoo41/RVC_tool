// asm source for hbus_err_response_slverr
_start_hbus_err_response_slverr:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
