extern GetProcessHeap: proc
extern HeapAlloc: proc

.data
HeapHandle qword 0h ; saved for future allocations

.code

; Malloc procedure:
; Allocates memory on the current process heap.
; Arguments:
; (1) amount of bytes to be allocated
; Returns:
; * the pointer to allocated memory
Malloc proc
    enter 40h, 0h

    ; save arguments and variables
    mov  qword ptr [rsp],     rcx 
    mov  qword ptr [rsp+8h],  rdx
    mov  qword ptr [rsp+10h], r8
    mov  qword ptr [rsp+18h], r9
    mov  qword ptr [rsp+20h], r10
    mov  qword ptr [rsp+28h], r11
    movq qword ptr [rsp+30h], xmm0

    cmp HeapHandle, 0h
    jne _malloc_handle_ready

    sub rsp, 28h ; 20h for shadow space + 8h for alignment
    call GetProcessHeap
    add rsp, 28h ; restore stack

    ; now we have the heap handle in rax, save it
    mov HeapHandle, rax

_malloc_handle_ready:

    mov rcx, HeapHandle     ; heap handle
    mov rdx, 4h + 8h        ; HEAP_GENERATE_EXCEPTIONS + HEAP_ZERO_MEMORY
    mov r8, qword ptr [rsp] ; amount of bytes
    
    sub rsp, 28h ; prepare stack
    call HeapAlloc
    add rsp, 28h ; restore stack

    ; HeapAlloc overwrites r9, r10, r11 and xmm0, restore them as well
    ; restore arguments
    mov  rcx,  qword ptr [rsp] 
    mov  rdx,  qword ptr [rsp+8h]
    mov  r8,   qword ptr [rsp+10h]
    mov  r9,   qword ptr [rsp+18h]
    mov  r10,  qword ptr [rsp+20h]
    mov  r11,  qword ptr [rsp+28h]
    movq xmm0, qword ptr [rsp+30h]
    
    ; we already have the pointer in the return register, rax
    leave
    ret
Malloc endp