ref_0x0:
main:
    jal r6, print_welcome
    ; wait for begin char *
    wait_begin:
        jal r6, f_readchar
        cmi r0, 0x2A
        jne wait_begin

    ldi r5, 0x00 ; current memory address
    ldi r7, 0x00 ; checksum
    rcv_loop:
        jal r6, f_readchar
        cmi r0, 0x2A
        jeq rcv_end ; end if * received
        ; receive 4 bytes, convert from hex and save to current mem address
        jal r6, f_convert_from_hex
        ; r2,r3 - result
        ldi r4, 12
        shl r3, r0, r4 ; r3 = (r0<<12)
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        ldi r4, 8
        shl r0, r0, r4
        orr r3, r3, r0 ; r3 |= (r0<<8) 
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        ldi r4, 4
        shl r0, r0, r4
        orr r3, r3, r0 ; r3 |= (r0<<4) 
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        orr r3, r3, r0 ; r3 |= r0
        
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        ldi r4, 12
        shl r2, r0, r4
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        ldi r4, 8
        shl r0, r0, r4
        orr r2, r2, r0 
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        ldi r4, 4
        shl r0, r0, r4
        orr r2, r2, r0
        jal r6, f_readchar
        jal r6, f_convert_from_hex
        orr r2, r2, r0 

        ; mov r0, r3
        ; jal r6, f_printchar
        ; ldi r4, 8
        ; shr r0,r0,r4
        ; jal r6, f_printchar
        ; mov r0, r2
        ; jal r6, f_printchar
        ; ldi r4, 8
        ; shr r0,r0,r4
        ; jal r6, f_printchar

        ; write to ram
        ldi r0, 0b11
        srs r0, 1 ; set instruction_memory_access
        sto r2, r5, 0 ; store r2 to current mem addr
        sto r3, r5, 1 ; store bytes 3-4
        adi r5, r5, 2 ;increment current mem addr
        ldi r0, 0b01
        srs r0, 1 ; reset instruction_memory_access
        add r7, r7, r2
        add r7, r7, r3
        jmp rcv_loop

    rcv_end:
    cmi r7, 0
    jne cs_err

    ldi r0, 0b0
    srs r0, 2 ; exit bootloader mode on next jump
    jmp ref_0x0 ; jump to address 0, executes from ram

cs_err:
    ldi r0, 0xAAAA
    jmp cs_err

f_readchar: ; returns r0
    ldi r0, 0xFF
    wait_new_data: ; wait for new data received signal
        ldd r1, 0x02
        cai r1, 0x01
        jeq wait_new_data
    ldd r0, 0x01
    srs r6, 0

f_printchar: ; r0 - char to send
    wait_ready: ; wait for ready to tx signal
        ldd r1, 0x02
        cai r1, 0x02
        jeq wait_ready
    std r0, 0x01
    srs r6, 0

f_convert_from_hex:
    cmi r0, 0x39 ; 0-9
    jgt convert_letter
    adi r0, r0, -0x30
    srs r6, 0 ; return
    convert_letter: ; not capital
    adi r0, r0, -0x61 ; a
    adi r0, r0, 0xA
    srs r6, 0

print_welcome:
    ; bootloader can't initialize memory for itself, hard coded message
    mov r5, r6
    ldi r0, 0x70
    jal r6, f_printchar
    ldi r0, 0x63
    jal r6, f_printchar
    ldi r0, 0x70
    jal r6, f_printchar
    ldi r0, 0x75
    jal r6, f_printchar
    ldi r0, 0x20
    jal r6, f_printchar
    ldi r0, 0x62
    jal r6, f_printchar
    ldi r0, 0x6F
    jal r6, f_printchar
    ldi r0, 0x6F
    jal r6, f_printchar
    ldi r0, 0x74
    jal r6, f_printchar
    ldi r0, 0x6C
    jal r6, f_printchar
    ldi r0, 0x64
    jal r6, f_printchar
    ldi r0, 0x0A
    jal r6, f_printchar
    srs r5, 0