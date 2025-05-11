NUMBER       textequ <xmm0>
VOLATILE_FP1 textequ <xmm1>
VOLATILE_FP2 textequ <xmm2>
RESULT       textequ <rax>
START_PTR    textequ <rcx>
END_PTR      textequ <rdx>
P_CHAR       textequ <r8>
CHAR         textequ <r9b>
CHAR_Q       textequ <r9>
PART_LEN     textequ <r10>
SIGN         textequ <r11>
VOLATILE_I   textequ <r12>

.data
    align 8h
    S2N_PRECISION_LEN  qword 9
    align 10h
    S2N_SIGN_BIT       qword 8000000000000000h
    align 10h
    S2N_ZERO           qword 0.0d
    align 10h
    S2N_TEN_FP         qword 10.0d
    align 8h
    S2N_TEXT_OVERFLOW  byte  "Number overflow.", 10
    align 8h
    S2N_TEXT_INCORRECT byte  "Incorrect numeral.", 10

.code

    ; StrToNum procedure:
    ; Parses the provided floating point number represented via a string.
    ; Arguments:
    ; * string to parse (inclusive start, exclusive end):
    ; (1) start pointer
    ; (2) end pointer
    ; Returns:
    ; * parsed number
    StrToNum proc ; (1): rcx, (2): rdx, *: rax
        ; start: save arguments and variables
        enter 50h, 0h
        movq  qword ptr [rsp],     xmm0
        movq  qword ptr [rsp+8h],  xmm1
        movq  qword ptr [rsp+10h], xmm2
        mov   qword ptr [rsp+18h], rcx
        mov   qword ptr [rsp+20h], rdx
        mov   qword ptr [rsp+28h], r8
        mov   qword ptr [rsp+30h], r9
        mov   qword ptr [rsp+38h], r10
        mov   qword ptr [rsp+40h], r11
        mov   qword ptr [rsp+48h], r12
        
        ; zero out the number first
        movq NUMBER, qword ptr [offset S2N_ZERO]

        ; initialize character pointer and fractional part counter
        mov P_CHAR,     START_PTR
        mov CHAR_Q,     0
        mov PART_LEN,   0
        mov VOLATILE_I, 0
        
        ; check for sign
        mov SIGN, 0
        mov CHAR, byte ptr [P_CHAR]
        cmp CHAR, "-"
        jne _strtonum_positive

        mov SIGN, 1
        inc P_CHAR
    _strtonum_positive:
        movq VOLATILE_FP2, qword ptr [offset S2N_TEN_FP]
        _strtonum_main_loop:
            ; ITERATIONS
            ; check if we are at the end of the string
            cmp    P_CHAR, END_PTR
            jge    _strtonum_main_done ; jump if true

            ; retrieve character
            mov CHAR,     byte ptr [P_CHAR]
            ; check if dot
            cmp CHAR, "."
            je  _strtonum_dot

            ; retrieve digit value
            sub      CHAR, "0"
            cmp      CHAR, 9
            jg       _strtonum_incorrect_numeral
            cmp      CHAR, 0
            jl       _strtonum_incorrect_numeral
            ; number *= 10; number += digit;
            mulsd    NUMBER, VOLATILE_FP2
            cvtsi2sd VOLATILE_FP1, CHAR_Q
            addsd    NUMBER, VOLATILE_FP1

            ; check boundary
            inc PART_LEN
            cmp PART_LEN, qword ptr [offset S2N_PRECISION_LEN]
            jg  _strtonum_failed_boundary

            ; if passed everything, continue
            inc P_CHAR
            jmp _strtonum_main_loop

        _strtonum_dot:
            cmp VOLATILE_I, 1
            je  _strtonum_incorrect_numeral

            mov VOLATILE_I, 1
            mov PART_LEN,   0

            inc P_CHAR
            jmp _strtonum_main_loop

    _strtonum_main_done:
        ; have we encountered a dot?
        cmp VOLATILE_I, 1
        jne _strtonum_sign ; no, so it is an integer, then don't compute power 10^FRAC_LEN nand divide
        ; else, proceed
        mov VOLATILE_I, 1

    ; we have all digits in xmm0, now compute the corresponding power 10^FRAC_LEN
    _strtonum_power_loop:
        cmp PART_LEN, 0
        je _strtonum_divide

        ; power *= 10;
        imul VOLATILE_I, 10
        dec PART_LEN
    jmp _strtonum_power_loop

    _strtonum_divide:
        ; now we have the power, divide by it to place the decimal separator
        ; number /= power
        cvtsi2sd VOLATILE_FP1, VOLATILE_I
        divsd    NUMBER, VOLATILE_FP1

    _strtonum_sign:
        ; we are done with the number, now check for sign
        cmp SIGN, 0
        je  _strtonum_return

        ; it is negative, set sign bit
        movq VOLATILE_FP1, qword ptr [offset S2N_SIGN_BIT]
        orpd NUMBER, VOLATILE_FP1

    _strtonum_return:
        ; finish: restore arguments and return value
        movq RESULT, NUMBER
        movq xmm0, qword ptr [rsp]
        movq xmm1, qword ptr [rsp+8h]
        movq xmm2, qword ptr [rsp+10h]
        mov  rcx,  qword ptr [rsp+18h]
        mov  rdx,  qword ptr [rsp+20h]
        mov  r8,   qword ptr [rsp+28h]
        mov  r9,   qword ptr [rsp+30h]
        mov  r10,  qword ptr [rsp+38h]
        mov  r11,  qword ptr [rsp+40h]
        mov  r12,  qword ptr [rsp+48h]
        leave
        ret

    _strtonum_failed_boundary:
        Invoke2 (Print), (offset S2N_TEXT_OVERFLOW), (lengthof S2N_TEXT_OVERFLOW)
        leave
        Exit (0)
        ret

    _strtonum_incorrect_numeral:
        Invoke2 (Print), (offset S2N_TEXT_INCORRECT), (lengthof S2N_TEXT_INCORRECT)
        leave
        Exit (0)
        ret
    StrToNum endp