# Assembly

Operands in assembly appear in the same order as in ISA (tg, fi, se). Instruction `mov r0, r2` copies register r2 to r0.  

## Calling convention
There is no hardware stack, call and return instructions. Use r7 as a PC, and r6 as return address. 

Example calling function
```
main: 
    jal r6, function ; jump and store return address in r6

function:
    adi r7, r7, -1 ; decrement stack
    sto r6, r7, 1 ; store return address to [sp+1] address
    ; sp points to next free address

    ; ...

    ldo r6, r7, 1
    adi r7, r7, 1 ; pop from stack
    srs r6, 0 ; store r6 (ra) to program counter [return] 
```

## Using memory lablels

Program memory and data memory are located at different sections. Before using memory labels switch to `.ramd` section. Each memory address is 16-bit value. Use `.org 0x4c00` before memory declarations to set origin to begin of GP-ram and `.global <name>, <size in 16 bits>` to allocate variables (unititialized) or `.init <name>, <size>, <value>` for initialized data (only works with OS support). 
```
.romd
    ldd r0, mem
    ldd r0, mem+2
    ldd r0, #0x4c00
    ldo r0, r1, mem2
.ramd
.org 0x4c00
.global mem, 1
.global mem2, 1
```
