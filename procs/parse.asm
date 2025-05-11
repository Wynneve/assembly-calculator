include macros/enum.asm

RESULT_1     textequ <rax>
RESULT_2     textequ <rbx>
VOLATILE_1   textequ <rsi>
VOLATILE_2   textequ <rdi>
START_PTR    textequ <rcx> ; shared recursively
END_PTR      textequ <rdx> ; shared recursively
P_TOKEN      textequ <r8>  ; shared recursively
TOKEN_TYPE   textequ <r9b> ; shared recursively
DEQUE_BASE   textequ <r10> 
DEQUE_START  textequ <r11>
DEQUE_END    textequ <r12>
RESULT_BASE  textequ <r13>
RESULT_START textequ <r14>
RESULT_END   textequ <r15>

.code
    ; Parse auxiliary procedure
    ; Initializes recursive parsing of the provided tokenized arithmetic expression.
    ; Arguments:
    ; * token array (inclusive start, exclusive end) -- in reverse!:
    ; (1) start pointer
    ; (2) end pointer
    ; Returns:
    ; * the result rearrangement array:
    ; (1) start pointer
    ; (2) end pointer
    Parse proc ; (1) = rcx, (2) = rdx
        enter 60h, 0h
        mov qword ptr [rsp],     rcx
        mov qword ptr [rsp+8h],  rdx
        mov qword ptr [rsp+10h], rsi
        mov qword ptr [rsp+18h], rdi
        mov qword ptr [rsp+20h], r8
        mov qword ptr [rsp+28h], r9
        mov qword ptr [rsp+30h], r10
        mov qword ptr [rsp+38h], r11
        mov qword ptr [rsp+40h], r12
        mov qword ptr [rsp+48h], r13
        mov qword ptr [rsp+50h], r14
        mov qword ptr [rsp+58h], r15
        
        ; initialize variables
        mov P_TOKEN,    START_PTR
        mov TOKEN_TYPE, 0
        call ParseRecursive ; parse the expression recursively
        ; after that, the whole result array is in rax, rbx

        mov rcx, qword ptr [rsp]
        mov rdx, qword ptr [rsp+8h]
        mov rsi, qword ptr [rsp+10h]
        mov rdi, qword ptr [rsp+18h]
        mov r8,  qword ptr [rsp+20h]
        mov r9,  qword ptr [rsp+28h]
        mov r10, qword ptr [rsp+30h]
        mov r11, qword ptr [rsp+38h]
        mov r12, qword ptr [rsp+40h]
        mov r13, qword ptr [rsp+48h]
        mov r14, qword ptr [rsp+50h]
        mov r15, qword ptr [rsp+58h]
        leave
        ret
    Parse endp

    ; ParseFlushDeque procedure:
    ; Flushes the deque to the result array.
    ; Arguments:
    ; (1) deque start pointer  -- implicitly: global state, via DEQUE_START
    ; (2) deque end pointer    -- implicitly: global state, via DEQUE_END
    ; (3) result start pointer -- implicitly: global state, via RESULT_START
    ; (4) result end pointer   -- implicitly: global state, via RESULT_END
    ; (5) result array pointer -- implicitly: global state, via RESULT_1
    ; Returns:
    ; * nothing (mutates global state: DEQUE_START and DEQUE_END)
    ParseFlushDeque proc ; (1) = ---, (2) = ---, (3) = ---
        ; flush the deque to the result array, if not empty
        _parse_flush_deque_main_loop:
            cmp DEQUE_START, DEQUE_END
            jge _parse_flush_deque_done

            mov VOLATILE_1, qword ptr [DEQUE_START]
            mov qword ptr [RESULT_END], VOLATILE_1
            
            ; move to the next place:
            add RESULT_END,  8h ; in the result array
            add DEQUE_START, 8h ; in the deque
        jmp _parse_flush_deque_main_loop

        _parse_flush_deque_done:
            ; finish: restore deque pointers
            mov DEQUE_START, DEQUE_BASE
            mov DEQUE_END,   DEQUE_BASE
            ret
    ParseFlushDeque endp

    ; ParseRecursive procedure:
    ; Partly parses the provided expression until first closing condition.
    ; Arguments:
    ; (1) current token pointer -- implicitly: global state, via P_TOKEN            
    ; Returns:
    ; * result array pointer start (inclusive)
    ; * result array pointer end   (exclusive)
    ParseRecursive proc ; (1) = ---, (2) = ---
        ; start: save arguments and variables
        enter 30h, 0h

        mov   qword ptr [rsp],     r10
        mov   qword ptr [rsp+8h],  r11
        mov   qword ptr [rsp+10h], r12
        mov   qword ptr [rsp+18h], r13
        mov   qword ptr [rsp+20h], r14
        mov   qword ptr [rsp+28h], r15

        mov  VOLATILE_1, END_PTR
        sub  VOLATILE_1, START_PTR
        imul VOLATILE_1, 8h
        mov  VOLATILE_2, VOLATILE_1
        shr  VOLATILE_2, 1

        mov rbx, rcx ; Invoke1 will consume rcx
        
        ; allocate array for result
        Invoke1 (Malloc), (VOLATILE_1) ; precisely
        ; save allocated array pointers
        lea RESULT_BASE, [RESULT_1 + VOLATILE_2]
        mov RESULT_START, RESULT_BASE
        mov RESULT_END,   RESULT_BASE

        ; allocate array for deque
        Invoke1 (Malloc), (VOLATILE_1) ; approximate value
        ; save allocated array pointers
        lea DEQUE_BASE,  [RESULT_1 + VOLATILE_2]
        mov DEQUE_START, DEQUE_BASE
        mov DEQUE_END,   DEQUE_BASE

        mov rcx, rbx ; restore rcx

        _parse_recursive_main_loop:
            cmp P_TOKEN, END_PTR
            jge _parse_recursive_done ; end of the token array

            mov TOKEN_TYPE, byte ptr [P_TOKEN]
            
            ; token type switch
            cmp TOKEN_TYPE, T_NUMBER
            je _parse_recursive_push_number
            cmp TOKEN_TYPE, T_STAR
            je _parse_recursive_push_multiplicative
            cmp TOKEN_TYPE, T_SLASH
            je _parse_recursive_push_multiplicative
            cmp TOKEN_TYPE, T_PLUS
            je _parse_recursive_push_additive
            cmp TOKEN_TYPE, T_MINUS
            je _parse_recursive_push_additive
            cmp TOKEN_TYPE, T_U_MINUS
            je _parse_recursive_push_additive
            cmp TOKEN_TYPE, T_LEFTPARENS
            je _parse_recursive_call
            cmp TOKEN_TYPE, T_RIGHTPARENS
            je _parse_recursive_done

            ; nothing matched
            jmp _parse_recursive_unknown

            ; JUMPS

            _parse_recursive_push_number:
                ; append number address to the deque
                mov qword ptr [DEQUE_END], P_TOKEN
                add DEQUE_END, 8h

                ; move to the next token
                add P_TOKEN, 9 ; 1 byte for type + 8 bytes for number value
                jmp _parse_recursive_main_loop

            _parse_recursive_push_multiplicative:
                ; prepend operator to the deque
                sub DEQUE_START, 8h
                mov qword ptr [DEQUE_START], P_TOKEN
                
                ; move to the next token
                add P_TOKEN, 1h ; 1 byte for type, no value
                jmp _parse_recursive_main_loop

            _parse_recursive_push_additive:
                ; prepend operator to the result
                sub RESULT_START, 8h
                mov qword ptr [RESULT_START], P_TOKEN

                ; move to the next token
                add P_TOKEN, 1h ; 1 byte for type, no value

                ; flush the deque to the result array
                call ParseFlushDeque

                jmp _parse_recursive_main_loop

            _parse_recursive_call:
                ; move to the next token
                add P_TOKEN, 1h ; 1 byte for type

                ; let it parse recursively the subexpression
                call ParseRecursive
                ; we receive the result array in rax, rbx;
                ; flush it to the deque
                
                _parse_recursive_push_to_deque:
                    mov VOLATILE_1, qword ptr [RESULT_1]
                    mov qword ptr [DEQUE_END], VOLATILE_1

                    add DEQUE_END, 8h
                    add RESULT_1,  8h ; move to the next token
                cmp RESULT_1, RESULT_2
                jl _parse_recursive_push_to_deque

                ; finished, continue
                jmp _parse_recursive_main_loop

        _parse_recursive_done:
            ; finish:
            ; move to the next token
            add P_TOKEN, 1h ; 1 byte for type, no value
            ; flush the deque to the result array
            call ParseFlushDeque
            ; return the result array
            mov RESULT_1, RESULT_START
            mov RESULT_2, RESULT_END
            ; restore arguments
            mov r10, qword ptr [rsp]
            mov r11, qword ptr [rsp+8h]
            mov r12, qword ptr [rsp+10h]
            mov r13, qword ptr [rsp+18h]
            mov r14, qword ptr [rsp+20h]
            mov r15, qword ptr [rsp+28h]
            leave
            ret

        ; ERRORS

        _parse_recursive_unknown:
            Invoke2 (Print), (offset TEXT_UNKNOWN_TOKEN), (lengthof TEXT_UNKNOWN_TOKEN)
            leave
            Exit (0)
            ret
    ParseRecursive endp