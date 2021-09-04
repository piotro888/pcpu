# Special registers
## Special register 0
Mapped to program counter
## Special register 1
CPU Privileged register. Writes require SUPERIVSOR mode
### Bit 0 - SUP
Supervisor mode. Default: 1
### Bit 1 - PMA
If set normal writes to memory affect program/instruction memory region (not normally accessible). Use in bootloader.
## Special register 2
Jump triggered register. Changes take effect on next jump instruction
### Bit 0 - B00T
Bootloader mode. Set by default to 1. If B00M bit is set program executes from internal
ROM. Otherwise program executes from SDRAM program memory sector.