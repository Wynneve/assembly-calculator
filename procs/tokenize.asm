include macros/enum.asm

RESULT_1   textequ <rax>
RESULT_1_B textequ <al>
RESULT_2   textequ <rbx>
RESULT_2_B textequ <bl>
START_PTR  textequ <rcx>
END_PTR    textequ <rdx>
TOKEN_ARR  textequ <r8>
P_TOKEN    textequ <r9>
TOKEN_TYPE textequ <r10b>
TOKEN_VAL  textequ <r11>
P_CHAR     textequ <r12>
CHAR       textequ <r13b>
COUNTER    textequ <r14>
VOLATILE   textequ <r15>

.data
    align 8h
    TEXT_INCORRECT_NUMERAL byte "Incorrect numeral.", 10
    align 8h
    TEXT_UNKNOWN_TOKEN     byte "Unknown token.", 10

.code
    ; Numeral character tokenize procedure
    IsNumeral proc
        mov RESULT_1, 0

        ; is decimal separator?
        cmp CHAR, "."
        je  _is_numeral_is_separator

        ; is digit?
        cmp CHAR, "0"
        jl  _is_numeral_done
        cmp CHAR, "9"
        jg  _is_numeral_done

        jmp _is_numeral_is_numeral

        ; falling through flow:

        _is_numeral_is_separator:
            cmp COUNTER, 0
            jne _is_numeral_incorrect_numeral
            mov COUNTER, 1

        _is_numeral_is_numeral:
            mov RESULT_1, 1 ; number token from the enum

        _is_numeral_done:
            ret

        _is_numeral_incorrect_numeral:
            Invoke2 (Print), (offset TEXT_INCORRECT_NUMERAL), (lengthof TEXT_INCORRECT_NUMERAL)
            Exit (0)
            ret
    IsNumeral endp

    ; Single character tokenize procedure
    TokenizeSingleCharacter proc ; expect previous result in TOKEN_TYPE intact
        cmp CHAR, "("
        je _tokenize_single_character_lparens
        cmp CHAR, ")"
        je _tokenize_single_character_rparens
        cmp CHAR, "+"
        je _tokenize_single_character_plus
        cmp CHAR, "-"
        je _tokenize_single_character_minus
        cmp CHAR, "*"
        je _tokenize_single_character_star
        cmp CHAR, "/"
        je _tokenize_single_character_slash

        jmp _tokenize_single_character_unmatched
        
        _tokenize_single_character_lparens:
            mov RESULT_1, T_LEFTPARENS
            jmp _tokenize_single_character_done
        _tokenize_single_character_rparens:
            mov RESULT_1, T_RIGHTPARENS
            jmp _tokenize_single_character_done
        _tokenize_single_character_plus:
            mov RESULT_1, T_PLUS
            jmp _tokenize_single_character_done
        _tokenize_single_character_minus:
            cmp TOKEN_TYPE, T_RIGHTPARENS
            je  _tokenize_single_character_binary_minus
            cmp TOKEN_TYPE, T_NUMBER
            je  _tokenize_single_character_binary_minus
            jmp _tokenize_single_character_unary_minus
        _tokenize_single_character_binary_minus:
            mov RESULT_1, T_MINUS
            jmp _tokenize_single_character_done
        _tokenize_single_character_unary_minus:
            mov RESULT_1, T_U_MINUS
            jmp _tokenize_single_character_done
        _tokenize_single_character_star:
            mov RESULT_1, T_STAR
            jmp _tokenize_single_character_done
        _tokenize_single_character_slash:
            mov RESULT_1, T_SLASH
            jmp _tokenize_single_character_done
        _tokenize_single_character_unmatched:
            mov RESULT_1, T_UNKNOWN ; only as a signal
            jmp _tokenize_single_character_done

        _tokenize_single_character_done:
            ret
    TokenizeSingleCharacter endp

    ; Tokenize procedure:
    ; Tokenizes the provided arithmetic expression.
    ; Arguments:
    ; * string to tokenize (inclusive start, exclusive end):
    ; (1) start pointer
    ; (2) end pointer
    ; Returns:
    ; * pointers to the result token array (rax, rbx) -- in reverse!
    Tokenize proc ; (1) = rcx, (2) = rdx
        ; start: save arguments and variables
        enter 50h, 0h

        mov   qword ptr [rsp],     rcx
        mov   qword ptr [rsp+8h],  rdx
        mov   qword ptr [rsp+10h], r8
        mov   qword ptr [rsp+18h], r9
        mov   qword ptr [rsp+20h], r10
        mov   qword ptr [rsp+28h], r11
        mov   qword ptr [rsp+30h], r12
        mov   qword ptr [rsp+38h], r13
        mov   qword ptr [rsp+40h], r14
        mov   qword ptr [rsp+48h], r15

        ; calculate the length of the string, to pass it to Malloc
        mov  VOLATILE, END_PTR
        sub  VOLATILE, START_PTR
        imul VOLATILE, 09h ; 1 byte for type + 8 bytes for value (if any) = 9 bytes per token

        ; allocate array for result
        Invoke1 (Malloc), (VOLATILE) ; upper bound
        ; Invoke1 overwrites rcx, restore it
        mov rcx, qword ptr [rsp]
        ; save allocated array pointer
        mov TOKEN_ARR, RESULT_1

        mov P_CHAR,  START_PTR ; first character
        mov P_TOKEN, TOKEN_ARR ; first token
        ; main loop over characters
        _tokenize_main_loop:
            ; finish condition
            cmp P_CHAR, END_PTR
            jge _tokenize_done

            mov RESULT_2, 0
            mov COUNTER,  0
            ; retrieve character
            mov CHAR, byte ptr [P_CHAR]

            ; skip whitespaces
            cmp CHAR, " "
            je _tokenize_whitespace
            
            ; first, check for 1 character token
            call TokenizeSingleCharacter
            cmp RESULT_1, T_UNKNOWN
            jne _tokenize_single_match

            ; second, check for (multi-character) number token
            call IsNumeral
            cmp RESULT_1, 0
            jne _tokenize_numeral_match

            ; nothing matched, we're in for a good crash
            jmp _tokenize_unknown

            ; JUMPS

            ; skip whitespace
            _tokenize_whitespace:
                inc P_CHAR
                jmp _tokenize_main_loop

            ; tokenize single character
            _tokenize_single_match:
                inc P_CHAR
                mov TOKEN_TYPE, RESULT_1_B
                mov TOKEN_VAL,  0 
                jmp _tokenize_write_token

            _tokenize_numeral_match:
                mov TOKEN_TYPE, T_NUMBER
                mov TOKEN_VAL,  0
                jmp _tokenize_numeral_loop

            ; tokenize the whole number
            _tokenize_numeral_loop:
                ; we enter the loop being already on a digit, so
                ; 1) increment the token length
                ; 2) move to the next character
                inc TOKEN_VAL
                inc P_CHAR

                ; check for the end of the whole string
                cmp P_CHAR, END_PTR
                jge _tokenize_numeral_finish

                ; else, it is safe to take the next character
                mov CHAR, byte ptr [P_CHAR]

                ; check if numeral
                call IsNumeral
                cmp  RESULT_1, 0
                je   _tokenize_numeral_finish ; not numeral — the end of the number
            
                jmp _tokenize_numeral_loop

            _tokenize_numeral_finish:
                ; start_ptr = end_ptr - len
                ; end_ptr is p_char
                mov VOLATILE, P_CHAR
                sub VOLATILE, TOKEN_VAL

                mov rcx, VOLATILE ; start pointer
                mov rdx, P_CHAR   ; end pointer
                call StrToNum ; inclusive start pointer and exclusive end pointer
                mov rcx, qword ptr [rsp]
                mov rdx, qword ptr [rsp+8h]

                mov TOKEN_VAL, RESULT_1 ; now we have the parsed number in double fp format
                mov RESULT_2,  1
                jmp _tokenize_write_token

            ; write token
            _tokenize_write_token:
                ; write token type
                mov byte ptr [P_TOKEN], TOKEN_TYPE
                inc P_TOKEN ; 1 byte for type = 1
                
                ; do we have value?
                cmp RESULT_2, 0 ; temporary, because "0.0" parses into "0x0"!
                je _tokenize_main_loop ; no, then skip writing value

                ; yes, then write value
                mov qword ptr [P_TOKEN], TOKEN_VAL
                add P_TOKEN, 08h ; 8 bytes for value (if any) = 9

                jmp _tokenize_main_loop

        jmp _tokenize_main_loop

        _tokenize_done:
            ; finish: return value and restore arguments
            mov RESULT_1, TOKEN_ARR ; result start pointer
            mov RESULT_2, P_TOKEN   ; result end pointer
            mov rcx, qword ptr [rsp]
            mov rdx, qword ptr [rsp+8h]
            mov r8,  qword ptr [rsp+10h]
            mov r9,  qword ptr [rsp+18h]
            mov r10, qword ptr [rsp+20h]
            mov r11, qword ptr [rsp+28h]
            mov r12, qword ptr [rsp+30h]
            mov r13, qword ptr [rsp+38h]
            mov r14, qword ptr [rsp+40h]
            mov r15, qword ptr [rsp+48h]
            leave
            ret

        ; ERRORS

        _tokenize_unknown:
            Invoke2 (Print), (offset TEXT_UNKNOWN_TOKEN), (lengthof TEXT_UNKNOWN_TOKEN)
            leave
            Exit (0)
            ret
    Tokenize endp