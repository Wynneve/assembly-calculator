EXTERN ExitProcess:PROC

Exit MACRO code:=<0>, return:=<0>
    mov  rcx, code
    
    sub  rsp, 28h
    call ExitProcess
    add  rsp, 28h
ENDM