Invoke0 macro name
    sub rsp, 20h + 8h
    call name
    add rsp, 20h + 8h
endm

Invoke1 macro name, arg1
    mov rcx, arg1
    sub rsp, 20h + 8h
    call name
    add rsp, 20h + 8h
endm

Invoke2 macro name, arg1, arg2
    mov rcx, arg1
    mov rdx, arg2
    sub rsp, 20h + 8h
    call name
    add rsp, 20h + 8h
endm

Invoke3 macro name, arg1, arg2, arg3
    mov rcx, arg1
    mov rdx, arg2
    mov r8,  arg3
    sub rsp, 20h + 8h
    call name
    add rsp, 20h + 8h
endm

Invoke4 macro name, arg1, arg2, arg3, arg4
    mov rcx, arg1
    mov rdx, arg2
    mov r8,  arg3
    mov r9,  arg4
    sub rsp, 20h + 8h
    call name
    add rsp, 20h + 8h
endm