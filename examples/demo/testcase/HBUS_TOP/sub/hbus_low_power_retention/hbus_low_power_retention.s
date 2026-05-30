// asm source for hbus_low_power_retention
_start_hbus_low_power_retention:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
