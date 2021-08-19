; uart test -> echo data
loop:
    
    new_data_wait: ; loop until new data is avaliable
        ldd r1, #0x02
        cai r1, 0x01 ; test 1st bit of addr 0x2 -> rx_new_data
        jeq new_data_wait ; jump if zero
    ldd r0, #0x01 ; receive data from port (addr 0x1), clears rx_new_data
    
    tx_ready_wait: ; wait until uart is ready for transmitting
        ldd r1, #0x02
        cai r1, 0x02 ; 2nd bit of addr 0x2 is tx_ready
        jeq tx_ready_wait
    std r0, #0x01 ; wire to addr 0x1 -> send data

    jmp loop