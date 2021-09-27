# Instruction set 
ISA rev 2

## Instruction format
Instruction format is fixed for all instructions. Single instruction is 32-bit.

| Bits 31-16        | Bits 15-13 | Bits 12-10 | Bits 9-7   | Bits 6-0   |
|-------------------|------------|------------|------------|------------|
| immediate/address | second reg | first reg  | target reg | opcode     |

## Instructions

| HEX | Name | Description | Symbolic Description
|-----|------|-------------|-------
|0    | NOP  | No Opertation | -
|1    | MOV  | Move first reg to target | tg <- fi
|2    | LDD  | Load direct from memory  | tg <- [addr]
|3    | LDO  | Load indirect with offset from memory | tg <- [fi + addr]
|4    | LDI  | Load immediate to register | tg <- imm
|5    | STD  | Store direct to memory     | [addr] <- fi
|6    | STO  | Store indirect with offest to memory | [addr+se] <- fi
|7    | ADD  | Add registers | tg <- fi + se
|8    | ADI  | Add immediate to register | tg <- fi + imm
|9    | ADC  | Add registers with carry  | tg <- fi + se + c
|A    | SUB  | Substract registers | tg <- fi - se
|B    | SUC  | Substract registers with carry  | tg <- fi - se - c
|C    | CMP  | Compare registers  | fi - se
|D    | CMI  | Compare register with immediate | fi - imm
|E    | JMP  | Jump (see jump conditions)      | jump if condition [pc <- imm]
|F    | JAL  | Jump and link | tg <- pc; pc <- imm
|10   | SRL  | Load from special register | tg <- sr[addr]
|11   | SRS  | Store to special register | sr[addr] <- sr
|12   |  -   | Reserved for syscall | -
|13   | AND  | And registers | tg <- fi & se
|14   | ORR  | Or registers | tg <- fi \| se
|15   | XOR  | Xor registers | tg <- fi ^ se
|16   | ANI  | And register with immediate | tg <- fi & imm
|17   | ORI  | Or register with immediate | tg <- fi \| imm
|18   | XOI  | Xor register with immediate | tg <- fi ^ imm
|19   | SHL  | Bit shift left | tg <- fi >> se
|1A   | SHR  | Bit shift right | tg <- fi << se
|1B   | CAI  | And-compare with immediate | fi & se
|1C   | MUL  | Unsigned multiply | tg <- fi * se
|1D   | DIV  | Unsigned division | tg <- fi / se

## Jump modes

Jump mode code is defined by bits 10-7
| Jump code | ASM OPCODE | Description | Flags
| --------- | --------- | ----------- | -----
| 0 | JMP | Unconditional | -
| 1 | JCA | Jump if carry | C
| 2 | JEQ | Jump if equal / zero | Z
| 3 | JLT | Jump if less than / negative | N
| 4 | JGT | Jump if greater than / greater than zero | ~(N\|Z)
| 5 | JLE | Jump if less or equal | N\|Z
| 6 | JGE | Jump if greater or equal | ~N
| 7 | JNE | Jump if not equal / not zero | ~Z

All artihemetic and compare operations set all flags
