; pong game
.romd
.org 0x0
f_main:
        ldi r0, 0 ; init globals
        std r0, l_pal_pos
        std r0, r_pal_pos
        std r0, y_speed
        std r0, reset_cnt
        ldi r0, 200; screenpos = pos/10
        std r0, x_bal
        std r0, y_bal
        ldi r0, -10
        std r0, x_speed
    
    loop:
        jal r6, f_draw_frame
        jmp f_handle_collisions
        ret_f_handle_collisions:
        jal r6, f_handle_controls
        jmp loop

f_draw_frame:
        ; stack frame function prologue
        adi r7, r7, -1
        sto r6, r7, 0

        ldi r4, 0 ; pixelcnt
        ldi r5, 0 ; i
        ; iterate over pixel
        loop_pixel_i:
            ldi r6, 0 ; j
            loop_pixel_j:
                jal r3, f_should_draw ; result in r0
                cmi r0, 0
                jeq ndraw
                ldi r1, 0xFFFF
                sto r1, r4, 0x1000 ; set pixel to white if 1
                jmp pxljend
            ndraw:
                ldi r1, 0
                sto r1, r4, 0x1000
            pxljend:
                adi r4, r4, 1 ; increment pixel cnt
                
                ; loop suff
                adi r6, r6, 1
                cmi r6, 40 ; j < 160/2
                jne loop_pixel_j
            ; loop suff
            adi r4, r4, 40
            adi r5, r5, 1
            cmi r5, 49 ; i < 120 / 2
            jne loop_pixel_i
        ; exit function
        ldo r6, r7, 0
        adi r7, r7, 1
        srs r6, 0

f_should_draw: ; r0 - bool r5 - y pos r6 - x pos r3 - return address r7 - sp
        ; mid line
        cmi r6, 20
        jeq exityes
        
        ; if paddle location - 10px * 2px
        cmi r6, 1 ; x: 0px
        jge p1no
        
;        ldi r1, 8
;        std r1, l_pal_pos
        ldd r0, l_pal_pos
;        ldi r0, 3
        adi r1, r0, 10
        cmp r5, r0
        jlt p1no
        cmp r5, r1
        jge p1no
        jmp exityes ; pal1pos <= y < pal1pos+5
    p1no:
        ; pad 2
        cmi r6, 39 
        jne p2no
        ldd r0, r_pal_pos
        adi r1, r0, 10
        cmp r5, r0
        jlt p2no
        cmp r5, r1
        jge p2no
        jmp exityes 
    p2no:
        ; check ball
        ldd r0, x_bal
        ldi r1, 10
        div r0, r0, r1 ; get screen pos
        cmp r0, r6
        jne exitno
        ldd r0, y_bal
        div r0, r0, r1
        sub r0, r5, r0
        cmi r0, 2 ; check if 0 <= y < 2
        jge exitno
        cmi r0, 0 
        jge exityes
       
    jmp exitno
    exityes:
        ldi r0, 1
        srs r3, 0
    exitno:
        ldi r0, 0
        srs r3, 0

f_handle_controls:
        ; move ball only 2 frames
        ldd r0, ball_frame
        adi r0, r0, 1
        std r0, ball_frame
        cai r0, 1
        jne ballskip

        ldd r0, x_bal ;move ball
        ldd r1, x_speed
        add r0, r0, r1
        std r0, x_bal
        ldd r0, y_bal
        ldd r1, y_speed
        add r0, r0, r1
        std r0, y_bal
    ballskip:

        ;buttons
        ldd r0, 0x0
        ani r0, r0, 0x0030
        cmi r0, 16
        jne hcnup
        ldi r1, -1
        jmp hcend
    hcnup:
        cmi r0, 32
        jne hc1no
        ldi r1, 1
    hcend:
        ldd r2, l_pal_pos
        add r2, r2, r1
        std r2, l_pal_pos
    hc1no:
    ;buttons 2 - diferrent mask
        ldd r0, 0x0
        ani r0, r0, 0x00C0
        cmi r0, 64
        jne hcnup2
        ldi r1, -1
        jmp hcend2
    hcnup2:
        cmi r0, 128
        jne hcno
        ldi r1, 1
    hcend2:
        ldd r2, r_pal_pos
        add r2, r2, r1
        std r2, r_pal_pos

    hcno:
        srs r6, 0

f_handle_collisions:
    ; if collided with end wall
    ldd r0, x_bal
    cmi r0, 10
    jlt c1nok
    cmi r0, 390
    jlt c1ok
    c1nok:
    ldi r0, 0
    std r0, x_speed
    std r0, y_speed
    jmp reset
    c1ok:
    
    
    ; check collision with pallete
    ldd r0, x_bal
    ldi r3, 10
    div r0, r0, r3
    cmi r0, 1
    jgt c2ok

    ;  -1 <= dy <= 9
    ldd r1, y_bal  
    ldd r2, l_pal_pos 
    div r1, r1, r3 
    sub r1, r1, r2
    cmi r1, 9
    jgt c2ok
    
    cmi r1, -1
    jlt c2ok
    
    ; xspeed 
    adi r1, r1, -4
    ldi r2, 10
    ldi r6, -1
    mov r4, r1
    cmi r1, 0
    jge signok
    mul r1, r1, r6
    signok:
    sub r2, r2, r1
    std r2, x_speed

    ;y speed
    ldi r3, 6
    ldi r2, 4
    mul r1, r1, r3
    div r1, r1, r2
    cmi r4, 0
    jge sok2
    mul r1, r1, r6
    sok2:
    std r1, y_speed
    jmp cend

    c2ok:
    ; pallete 2
    ldd r0, x_bal
    ldi r3, 10
    div r0, r0, r3
    cmi r0, 38
    jlt c3ok
    ldd r1, y_bal  
    ldd r2, r_pal_pos 
    div r1, r1, r3 
    sub r1, r1, r2
    cmi r1, 9
    jgt c3ok
    cmi r1, -1
    jlt c3ok
    ; xspeed 
    adi r1, r1, -4
    ldi r2, 10
    ldi r6, -1
    mov r4, r1
    cmi r1, 0
    jge signok3
    mul r1, r1, r6
    signok3:
    sub r2, r2, r1
    mul r2, r2, r6
    std r2, x_speed
    ;y speed
    ldi r3, 6
    ldi r2, 4
    mul r1, r1, r3
    div r1, r1, r2
    cmi r4, 0
    jge sok3
    mul r1, r1, r6
    sok3:
    std r1, y_speed
    jmp cend

    c3ok:
    ;check upper and lower wall
    ldd r0, y_bal
    ldi r1, 10
    div r0, r0, r1
    cmi r0, 0
    jle c4no
    cmi r0, 47
    jge c4no
    jmp c4ok
    c4no:
    ldd r0, y_speed
    ldd r2, y_bal
    ldi r1, -1
    adi r2, r2, -20 ;compare sign of speed and pos to don't repeat collision
    xor r2, r2, r0
    ani r2, r2, 0x8000
    cmi r2, 0
    jne c4ok
    mul r0, r0, r1
    std r0, y_speed

    c4ok:
    cend:
    jmp ret_f_handle_collisions

reset:
    ldi r0, 0
    std r0, y_speed
    ldd r1, reset_cnt
    adi r1, r1, 1
    std r1, reset_cnt
    cai r1, 1
    jne opt2
    ldi r0, 10
    jmp opt2e
    opt2:
    ldi r0, -10
    opt2e:
    std r0, x_speed
    ldi r0, 200
    std r0, y_bal
    std r0, x_bal
    jmp loop

.ramd
.org 0x4c01
.global l_pal_pos, 1
.global r_pal_pos, 1
.global x_bal, 1
.global y_bal, 1
.global x_speed, 1
.global y_speed, 1
.global ball_frame, 1
.global reset_cnt, 1