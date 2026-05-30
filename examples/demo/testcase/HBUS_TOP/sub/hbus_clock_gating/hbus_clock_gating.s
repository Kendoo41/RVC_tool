// asm source for hbus_clock_gating
_start_hbus_clock_gating:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
