extern ReadConsoleA: proc
extern GetStdHandle:  proc

.data
    align 8h
    InHandle    qword 0
    align 8h
    InputBuffer qword 100h dup (0)
    align 8h
    InputChars  qword 0
.code

    ; Input procedure:
    ; Inputs a string from the standard input.
    ; Arguments:
    ; * none
    ; Returns:
    ; * pointer to the input string
    ; * length of the input string
    Input proc
        enter 20h, 0h

        ; save passed arguments
        mov qword ptr [rsp],     rcx
        mov qword ptr [rsp+8h],  rdx
        mov qword ptr [rsp+10h], r8
        mov qword ptr [rsp+18h], r9

        cmp InHandle, 0
        jne _input_handle_ready

        mov rcx, -10 ; STD_INPUT_HANDLE
        sub rsp, 28h
        call GetStdHandle
        add rsp, 28h
        
        ; now we have the handle in rax
        mov OutHandle, rax

    _input_handle_ready:

        mov rcx, OutHandle
        mov rdx, offset InputBuffer
        mov r8,  100h
        mov r9,  offset InputChars

        sub  rsp, 30h ; for 1 stack argument + align to 16 bytes: 8 + 8 = 16
        mov  qword ptr [rsp+20h], 0
        call ReadConsoleA
        add  rsp, 30h

        ; invalidate console output handler
        mov OutHandle, 0

        ; return data
        mov rax, offset InputBuffer ; pointer to the input string
        mov rbx, qword ptr [offset InputChars] ; length of the input string

        ; restore arguments
        mov rcx, qword ptr [rsp]
        mov rdx, qword ptr [rsp+8h]
        mov r8,  qword ptr [rsp+10h]
        mov r9,  qword ptr [rsp+18h]

        ; we return nothing
        leave
        ret
    Input endp