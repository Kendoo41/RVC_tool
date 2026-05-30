// asm source for hbus_qos_bandwidth_limit
_start_hbus_qos_bandwidth_limit:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
