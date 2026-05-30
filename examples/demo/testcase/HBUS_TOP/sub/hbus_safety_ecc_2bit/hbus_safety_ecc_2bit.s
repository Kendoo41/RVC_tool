// asm source for hbus_safety_ecc_2bit
_start_hbus_safety_ecc_2bit:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
