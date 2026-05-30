// asm source for hbus_reg_default_value
_start_hbus_reg_default_value:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
