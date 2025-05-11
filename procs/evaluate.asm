include macros/enum.asm

RESULT      textequ <rax>
START_PTR   textequ <rcx>
END_PTR     textequ <rdx>
P_ADDRESS   textequ <r8>
TOKEN_TYPE  textequ <r9b>
TOKEN_VAL   textequ <r10>
VOLATILE    textequ <r11>
FIRST       textequ <xmm0>
SECOND      textequ <xmm1>

.data
    align 10h
    EVAL_SIGN_BIT qword 8000000000000000h
    
.code

; Evaluate procedure
; Evaluates the provided parsed expression.
; Arguments:
; * parsed expression (inclusive start, exclusive end):
; (1) start pointer
; (2) end pointer
; Returns:
; * result (evaluated expression value)
Evaluate proc ; (1) = rcx, (2) = rdx
    enter 50h, 0h
    mov  qword ptr [rsp],     rcx
    mov  qword ptr [rsp+8h],  rdx
    mov  qword ptr [rsp+10h], r8
    mov  qword ptr [rsp+18h], r9
    mov  qword ptr [rsp+20h], r10
    mov  qword ptr [rsp+28h], r11
    movq qword ptr [rsp+30h], xmm0
    movq qword ptr [rsp+38h], xmm1

    mov P_ADDRESS, START_PTR
    mov TOKEN_VAL, 0
    _evaluate_main_loop:
        cmp P_ADDRESS, END_PTR
        jle  _evaluate_done

        mov VOLATILE, qword ptr [P_ADDRESS]
        mov TOKEN_TYPE, byte ptr [VOLATILE]

        ; token type switch
        cmp TOKEN_TYPE, T_NUMBER
        je _evaluate_push_number
        cmp TOKEN_TYPE, T_STAR
        je _evaluate_binary_operation
        cmp TOKEN_TYPE, T_SLASH
        je _evaluate_binary_operation
        cmp TOKEN_TYPE, T_PLUS
        je _evaluate_binary_operation
        cmp TOKEN_TYPE, T_MINUS
        je _evaluate_binary_operation
        cmp TOKEN_TYPE, T_U_MINUS
        je _evaluate_unary_operation

        _evaluate_push_number:
            ; push the number
            add  VOLATILE,  1h ; retrieve the token value
            mov  TOKEN_VAL, qword ptr [VOLATILE]
            push TOKEN_VAL
            
            sub  P_ADDRESS, 8h ; move to the next token
            jmp _evaluate_main_loop

        _evaluate_binary_operation:
            pop  VOLATILE
            movq FIRST, VOLATILE
            pop  VOLATILE
            movq SECOND, VOLATILE

            ; switch for the operation
            cmp TOKEN_TYPE, T_STAR
            je  _evaluate_multiply
            cmp TOKEN_TYPE, T_SLASH
            je  _evaluate_divide
            cmp TOKEN_TYPE, T_PLUS
            je  _evaluate_add
            cmp TOKEN_TYPE, T_MINUS
            je  _evaluate_subtract

            _evaluate_multiply:
                ; multiply them
                mulsd FIRST, SECOND
                jmp _evaluate_push_result

            _evaluate_divide:
                ; divide them
                divsd FIRST, SECOND
                jmp _evaluate_push_result

            _evaluate_add:
                ; add them
                addsd FIRST, SECOND
                jmp _evaluate_push_result
            
            _evaluate_subtract:
                ; subtract them
                subsd FIRST, SECOND
                jmp _evaluate_push_result

        _evaluate_unary_operation:
            ; pop the top number
            pop  VOLATILE
            movq FIRST, VOLATILE
            ; switch for the operation
            cmp TOKEN_TYPE, T_U_MINUS
            je  _evaluate_negate

            _evaluate_negate:
                ; negate it
                xorpd FIRST, qword ptr [EVAL_SIGN_BIT]
                jmp _evaluate_push_result

        _evaluate_push_result:
            movq VOLATILE, FIRST
            push VOLATILE
        
            sub P_ADDRESS, 8h ; move to the next token
            jmp _evaluate_main_loop

    _evaluate_done:
        ; retrieve result and restore registers
        pop VOLATILE
        mov RESULT, VOLATILE

        mov  rcx,  qword ptr [rsp]
        mov  rdx,  qword ptr [rsp+8h]
        mov  r8,   qword ptr [rsp+10h]
        mov  r9,   qword ptr [rsp+18h]
        mov  r10,  qword ptr [rsp+20h]
        mov  r11,  qword ptr [rsp+28h]
        movq xmm0, qword ptr [rsp+30h]
        movq xmm1, qword ptr [rsp+38h]
        leave
        ret
Evaluate endp