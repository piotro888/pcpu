.romd
ldi r0, 0
ldi r1, 0xCAFE
loop:
sto r1, r0, ram
adi r0,r0, 1
adi r1,r1, 1
cmi r0, 0x10
jle loop

ldi r1, 0xCAFE
ldi r0, 0
readloop:
ldo r2, r0, ram
adi r0, r0, 1
nop
nop
nop
cmp r2,r1
jne error
adi r1, r1, 1
cmi r0, 0x10
jle readloop

ldi r0, 0xAAAA
end:
jmp end

error:
mov r0, r3
errloop:
mov r0, r2
nop
mov r0, r1
nop
mov r0, r3
nop
nop
jmp errloop

.ramd
.org 0x4c00
.global ram, 0x0
