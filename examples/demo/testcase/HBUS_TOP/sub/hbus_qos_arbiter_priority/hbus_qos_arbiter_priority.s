// asm source for hbus_qos_arbiter_priority
_start_hbus_qos_arbiter_priority:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
