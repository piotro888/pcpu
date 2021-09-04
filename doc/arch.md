# Architecture overview
PCPU Architecture
## Core

* 8 x 16-bit registers
* Load/store RISC architecture
* All instructions are executed in 1 clock cycle
* 16 bit memory width  
* 3 operand arithmetic instructions
* 16 bit hardware program counter
* Fixed format 32-bit instructions fetched from internal or external ram
* Memory paging, interrupts, syscalls  [TODO]
* Separate sections for program and data ram

## Additional
* Custom SDRAM controller
* VGA
* Serial interface
* Verilog design with control signals (for possible implementation outside FPGA)
* Port of GCC in progress