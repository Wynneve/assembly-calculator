option casemap:none

includelib kernel32.lib

public main

; data imports

include macros/enum.asm

.data
    ; text strings
    align 8h
    MAIN_PROGRAM_NAME byte "Expression calculator.", 10, 10
    align 8h
    MAIN_PROMPT       byte "> "
    align 8h
    MAIN_RESULT       byte "= "
    align 8h
    MAIN_NEWLINE      byte 10
    align 8h
    MAIN_PADDING      byte 10, 10

; code imports

include macros/invoke.asm
include macros/exit.asm
include procs/print.asm
include procs/input.asm
include procs/malloc.asm
include procs/tokenize.asm
include procs/numtostr.asm
include procs/strtonum.asm
include procs/parse.asm
include procs/evaluate.asm

.code
    main proc
        ;int 3 ; wait for debugger
        mov rbx, rsp

        Invoke2 (Print), (offset MAIN_PROGRAM_NAME), (lengthof MAIN_PROGRAM_NAME)

        _main_loop:    
            Invoke2 (Print), (offset MAIN_PROMPT), (lengthof MAIN_PROMPT)   
            Invoke0 (Input)
            cmp rbx, 2 ; \r\n
            jle _exit  ; exit if no input
            
            ; already have start pointer in rax
            ; calculate end pointer in rbx using length (1 char = 1 byte)
            add rbx, rax
            sub rbx, 2h ; remove \r\n
            Invoke2 (Tokenize), (rax), (rbx)

            Invoke2 (Parse),    (rax), (rbx)

            sub rbx, 8h ; make the start inclusive
            sub rax, 8h ; make the end exclusive
            Invoke2 (Evaluate), (rbx), (rax)

            movq xmm0, rax
            Invoke0 (NumToStr)

            mov r8, rax ; save result pointer
            Invoke2 (Print), (offset MAIN_RESULT), (lengthof MAIN_RESULT)
            Invoke2 (Print), (r8), (20)
            Invoke2 (Print), (offset MAIN_PADDING), (lengthof MAIN_PADDING)
        jmp _main_loop

    _exit:
        ; finish
        Exit (0)
        ; failsafe exit
        ret
    main endp

end