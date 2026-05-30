// asm source for hbus_addr_map_flash
_start_hbus_addr_map_flash:
    li   a0, 0x4000_0000
    sw   a0, 0(a1)      // program QoS register
    ret
