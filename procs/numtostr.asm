NUMBER       textequ <xmm0>
VOLATILE_FP1 textequ <xmm1>
VOLATILE_FP2 textequ <xmm2>
RESULT       textequ <rax>
DIVIDEND     textequ <rax>
DIVISOR      textequ <rbx>
REMAINDER    textequ <rdx>
REMAINDER_W  textequ <dx>
REMAINDER_B  textequ <dl>
STR_BASE_PTR textequ <rcx>
VOLATILE_I1  textequ <r8>
VOLATILE_I2  textequ <r9>
P_CHAR       textequ <r10>
DIGITS_COUNT textequ <r11>

.data
    align 8h
    N2S_NEG_BOUNDARY  qword -1000000000.0d
    align 8h
    N2S_POS_BOUNDARY  qword 1000000000.0d
    align 10h
    N2S_SIGN_MASK     qword 7FFFFFFFFFFFFFFFh
    align 8h
    N2S_PRECISION_FP  qword 1000000000.0d
    align 8h
    N2S_PRECISION_INT qword 1000000000
    align 8h
    N2S_PRECISION_LEN qword 9
    align 8h
    N2S_ONE           qword 1
    align 8h
    N2S_ZERO          qword 0
    align 8h
    N2S_TEXT_OVERFLOW byte  "Number overflow.", 10

.code

    ; NumToStr auxiliary convert loop macro
    NumToStr__convert_loop macro target, loop_name
        ; classic algorithm to convert integer to string
        mov DIGITS_COUNT, 0
        mov DIVIDEND,     target
        mov DIVISOR,      10 ; divide by 10
    loop_name:
        ; DIVIDEND /= 10
        mov REMAINDER, 0
        div DIVISOR

        dec VOLATILE_I2

        ; result_str += "0" + (DIVIDEND mod 10)
        add    REMAINDER_B, "0"
        cmp    REMAINDER_B, "0"
        cmovne VOLATILE_I1, qword ptr [N2S_ONE]  ; encountered a non-zero digit! set to 1
        cmp    DIVIDEND,    0                    ; also do an exception for leftover zeroes
        cmove  VOLATILE_I1, qword ptr [N2S_ONE]  ; set to 1 in this case to avoid stucking in the loop forever
        cmp    VOLATILE_I1, 1

        jne    loop_name   ; if not, skip pushing this non-significant digit
        ; else, push the digit
        push   REMAINDER_W ; can't push 8-bit value, so use 16-bit
        ; digits_count++
        inc    DIGITS_COUNT

        ; DIVIDEND == 0 ?
        cmp DIVIDEND, 0

        ; if not, continue
        jne loop_name

        ; else, check for desired precision
        cmp VOLATILE_I2, 0
        ; if not reached, still continue writing zeroes
        jg  loop_name
        ; else, finish
    endm

    ; NumToStr auxiliary write loop macro
    NumToStr__write_loop macro loop_name
    loop_name:
        ; pop the last digit
        pop  REMAINDER_W
        ; digits_count0--
        dec  DIGITS_COUNT
        ; write it to the string
        mov  byte ptr [P_CHAR], REMAINDER_B
        inc  P_CHAR
        ; is it the last digit?
        cmp  DIGITS_COUNT, 0
        ; if not, continue
        jne loop_name
    endm

    ; NumToStr procedure:
    ; Converts the provided floating point number to a string representation.
    ; Arguments:
    ; (1) number to convert
    ; Returns:
    ; * result string pointer
    NumToStr proc ; (1): xmm0 [lower 64 bits]
        ; start: save arguments and variables
        enter 50h, 0h
        movq  qword ptr [rsp],     xmm0
        movq  qword ptr [rsp+8h],  xmm1
        movq  qword ptr [rsp+10h], xmm2
        mov   qword ptr [rsp+18h], rbx
        mov   qword ptr [rsp+20h], rcx
        mov   qword ptr [rsp+28h], rdx
        mov   qword ptr [rsp+30h], r8
        mov   qword ptr [rsp+38h], r9
        mov   qword ptr [rsp+40h], r10
        mov   qword ptr [rsp+48h], r11
        
        ; check if xmm1 >= N2S_NEG_BOUNDARY
        movsd    VOLATILE_FP1, NUMBER
        movsd    VOLATILE_FP2, qword ptr [offset N2S_NEG_BOUNDARY]
        cmpsd    VOLATILE_FP1, VOLATILE_FP2, 5 ; greater than or equal
        movmskpd VOLATILE_I1,  VOLATILE_FP1
        test     VOLATILE_I1,  VOLATILE_I1
        je       _numtostr_failed_boundary

        ; check if xmm <= N2S_POS_BOUNDARY
        movsd    VOLATILE_FP1, NUMBER
        movsd    VOLATILE_FP2, qword ptr [offset N2S_POS_BOUNDARY]
        cmpsd    VOLATILE_FP1, VOLATILE_FP2, 2 ; less than or equal
        movmskpd VOLATILE_I1,  VOLATILE_FP1
        test     VOLATILE_I1,  VOLATILE_I1
        je       _numtostr_failed_boundary

        ; passed checks
        ; allocate string for result
        Invoke1 (Malloc), (20) ; 1 minus, 9 integral digits, 1 decimal separator and 9 fractional digits
        ; Invoke1 overwrites rcx, restore it
        mov rcx, qword ptr [rsp+20h]
        ; save the allocated string pointer
        mov STR_BASE_PTR, RESULT
        ; copy the pointer to increment it during the conversion
        mov P_CHAR,       RESULT

        ; check if negative
        movq VOLATILE_I1, NUMBER
        bt   VOLATILE_I1, 63
        
        jnc _numtostr_positive
        
        ; it is negative: push a minus and negate
        mov   byte ptr [P_CHAR], "-"
        inc   P_CHAR
        andpd NUMBER, qword ptr [offset N2S_SIGN_MASK] ; clear sign bit

    _numtostr_positive:
        ; retrieve integral and fractional parts (fixed point with PRECISION)
        movsd    VOLATILE_FP1, NUMBER
        mulsd    VOLATILE_FP1, qword ptr [N2S_PRECISION_FP]
        cvtsd2si DIVIDEND,     VOLATILE_FP1
        mov      REMAINDER,    0
        mov      DIVISOR,      N2S_PRECISION_INT
        div      DIVISOR
        ; now integral part in rax (DIVIDEND), fractional part in rdx (REMAINDER)

        ; save fractional part, will convert later
        movq VOLATILE_FP2, REMAINDER

        ; convert integral part first
        mov VOLATILE_I1, 1 ; don't wait for digits
        mov VOLATILE_I2, 0 ; let it be any length!
        NumToStr__convert_loop DIVIDEND, _numtostr_integral_convert_loop
        NumToStr__write_loop             _numtostr_integral_write_loop

        ; after the integral part, place the decimal separator
        mov   byte ptr [P_CHAR], "."
        inc   P_CHAR
        
        ; now restore fractional part
        movq DIVIDEND, VOLATILE_FP2

        ; and convert it too
        mov VOLATILE_I1,   0 ; encountered a non-zero digit (not true yet)
        mov VOLATILE_I2,   qword ptr [offset N2S_PRECISION_LEN] ; desired precision length
        cmp DIVIDEND,      0 ; do an exception for 0
        cmove VOLATILE_I2, qword ptr [N2S_ZERO]
        NumToStr__convert_loop DIVIDEND, _numtostr_fractional_convert_loop
        NumToStr__write_loop             _numtostr_fractional_write_loop

        ; finish: restore arguments and return value
        mov  RESULT, STR_BASE_PTR
        movq xmm0, qword ptr [rsp]
        movq xmm1, qword ptr [rsp+8h]
        movq xmm2, qword ptr [rsp+10h]
        mov  rbx,  qword ptr [rsp+18h]
        mov  rcx,  qword ptr [rsp+20h]
        mov  rdx,  qword ptr [rsp+28h]
        mov  r8,   qword ptr [rsp+30h]
        mov  r9,   qword ptr [rsp+38h]
        mov  r10,  qword ptr [rsp+40h]
        mov  r11,  qword ptr [rsp+48h]
        leave
        ret

    _numtostr_failed_boundary:
        Invoke2 (Print), (offset N2S_TEXT_OVERFLOW), (lengthof N2S_TEXT_OVERFLOW)
        leave
        Exit (0)
        ret
    NumToStr endp