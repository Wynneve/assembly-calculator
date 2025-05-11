extern WriteConsoleA: proc
extern GetStdHandle:  proc

.data
    align 8h
    OutHandle qword 0
    
.code

    ; Print procedure:
    ; Prints the specified string to the standard output.
    ; Arguments:
    ; (1) the string
    ; (2) length of the string
    ; Returns:
    ; * nothing
    Print proc
        enter 20h, 0h

        ; save passed arguments
        mov qword ptr [rsp],     rcx
        mov qword ptr [rsp+8h],  rdx
        mov qword ptr [rsp+10h], r8
        mov qword ptr [rsp+18h], r9

        cmp OutHandle, 0
        jne _print_handle_ready

        mov rcx, -11 ; STD_OUTPUT_HANDLE
        sub rsp, 28h
        call GetStdHandle
        add rsp, 28h
        
        ; now we have the handle in rax
        mov OutHandle, rax

    _print_handle_ready:

        mov rcx, OutHandle
        mov rdx, qword ptr [rsp]
        mov r8,  qword ptr [rsp+8h]
        mov r9,  0

        sub  rsp, 30h ; for 1 stack argument + align to 16 bytes: 8 + 8 = 16
        mov  qword ptr [rsp+20h], 0
        call WriteConsoleA
        add  rsp, 30h

        ; restore arguments
        mov rcx, qword ptr [rsp]
        mov rdx, qword ptr [rsp+8h]
        mov r8,  qword ptr [rsp+10h]
        mov r9,  qword ptr [rsp+18h]

        ; we return nothing
        leave
        ret
    Print endp