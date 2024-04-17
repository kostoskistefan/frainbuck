; Frainbuck - Brainfuck interpreter in x86_64 assembly
; Copyright (c) 2024, Kostoski Stefan (MIT License).
; https://github.com/kostoskistefan/frainbuck

section .bss                                 ; Start of .bss section
filename resb 256                            ; The filename of the brainfuck code
tape_size equ 30000                          ; The size of the brainfuck language tape
tape resb tape_size                          ; The brainfuck language tape
tape_offset resq 1                           ; The current cell offset of the tape in the brainfuck language 
stack_size equ 1000                          ; The size of the stack        
stack resb stack_size                        ; The stack used by the interpreter
stack_pointer resd 1                         ; The stack pointer used by the interpreter
text_buffer_size equ 10000                   ; The size of the input brainfuck code text buffer
text_buffer resb text_buffer_size            ; The input brainfuck code text buffer
file_descriptor resd 1                       ; The file descriptor of the brainfuck code file

section .text                                ; Start of .text section
global _start                                ; Make _start label available to linker

; ----------------------------------------------------------------------------------------------------------------------
; @brief Entry point
; ----------------------------------------------------------------------------------------------------------------------
_start:
    mov ecx, [rsp]
    cmp ecx, 2                               ; Check if the number of arguments is 2
    jne exit_failure                         ; If not, exit the interpreter

    inc rsi                                  ; Skip the first argument (path of the executable)
    mov r10, [rsp+rsi*8+8]                   ; Store the second argument in RDI register
    mov r11, filename                        ; Store the filename address in RSI register
    call string_copy
    
    mov rdi, filename                        ; Store the filename in RDI register
    call open_file                           ; Open the brainfuck code file

    mov rsi, text_buffer                     ; Store the text buffer address in the RSI register
    mov rdx, text_buffer_size                ; Store the text buffer size in the RDX register
    call read_file                           ; Read the contents of the brainfuck code file

    call frainbuck_parse_source_code         ; Parse the source code 

    call close_file                          ; Close the brainfuck code file
    call exit_success                        ; Exit the interpreter

; ----------------------------------------------------------------------------------------------------------------------
; @brief Parse the brainfuck source code
; @modifies R8, R9 registers
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_parse_source_code:
    mov r8, text_buffer                      ; Store the memory address of the source code in the R8 register

frainbuck_parse_source_code_loop:
    cmp r8, 0                                ; Check if the iterator has reached the end of the source code 
    jle frainbuck_parse_source_code_end      ; If so, exit the interpreter

    cmp byte [r8], 0                         ; Check if the current character is EOF
    jle frainbuck_parse_source_code_end      ; If so, exit the interpreter

    cmp byte [r8], '+'                       ; Check if the current character is '+'
    je frainbuck_increment_cell_value        ; If so, increment the value stored in the currently selected cell

    cmp byte [r8], '-'                       ; Check if the current character is '-'
    je frainbuck_decrement_cell_value        ; If so, decrement the value stored in the currently selected cell

    cmp byte [r8], '>'                       ; Check if the current character is '>'
    je frainbuck_increment_tape_pointer      ; If so, increment the tape pointer

    cmp byte [r8], '<'                       ; Check if the current character is '<'
    je frainbuck_decrement_tape_pointer      ; If so, decrement the tape pointer

    cmp byte [r8], '.'                       ; Check if the current character is '.'
    je frainbuck_print_cell_value            ; If so, print the value stored in the currently selected cell

    cmp byte [r8], ','                       ; Check if the current character is ','
    je frainbuck_read_input_in_cell          ; If so, read the value from stdin and store it in the current cell

    cmp byte [r8], '['                       ; Check if the current character is '['
    je frainbuck_jump_forward                ; If so, add a loop start instruction to the stack

    cmp byte [r8], ']'                       ; Check if the current character is ']'
    je frainbuck_jump_backward               ; If so, handle the loop end instruction

frainbuck_parse_source_code_continue:
    inc r8                                   ; Increment the memory address
    jmp frainbuck_parse_source_code_loop     ; Jump to the source code parsing loop

frainbuck_parse_source_code_end:
    ret                                      ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Increment the value in the cell where the tape pointer is pointing to
; @modifies R9 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_increment_cell_value:
    mov r9, [tape_offset]                    ; Store the value of the tape pointer
    add r9, tape                             ; Add the tape address to the tape pointer value
    inc byte [r9]                            ; Increment the value in the cell where the tape pointer is pointing to
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Decrement the value in the cell where the tape pointer is pointing to
; @modifies R9 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_decrement_cell_value:
    mov r9, [tape_offset]                    ; Store the value of the tape pointer
    add r9, tape                             ; Add the tape address to the tape pointer value
    dec byte [r9]                            ; Decrement the value in the cell where the tape pointer is pointing to
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Increment the brainfuck tape pointer
; @modifies none
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_increment_tape_pointer:
    cmp qword [tape_offset], tape_size       ; Check if the tape pointer is equal to the tape size
    je frainbuck_increment_tape_pointer_wrap ; If so, wrap around
    inc qword [tape_offset]                  ; Increment the tape pointer
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

frainbuck_increment_tape_pointer_wrap:
    mov qword [tape_offset], 0               ; Wrap around
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Decrement the brainfuck tape pointer
; @modifies none
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_decrement_tape_pointer:
    cmp qword [tape_offset], 0               ; Check if the tape pointer is 0
    je frainbuck_decrement_tape_pointer_wrap ; If so, wrap around
    dec qword [tape_offset]                  ; Decrement the tape pointer
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

frainbuck_decrement_tape_pointer_wrap:
    mov qword [tape_offset], tape_size       ; Wrap around
    dec qword [tape_offset]                  ; Decrement the tape pointer because we start at index 0
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Print the value in the cell where the tape pointer is pointing to
; @modifies RAX, RSI, RDI, RDX registers
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_print_cell_value:
    mov rsi, [tape_offset]                   ; Store the value of the tape pointer
    add rsi, tape                            ; Add the tape address to the tape pointer value
    mov rax, 1                               ; Syscall write (1)
    mov rdi, 1                               ; STDOUT File descriptor
    mov rdx, 1                               ; Memory size
    syscall                                  ; Syscall
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Read one character from stdin and store it in the current cell
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_read_input_in_cell:
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Jump to the matching ']' character
; @modifies R9 and possibly the R8 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_jump_forward:
    mov r9, [tape_offset]                    ; Store the value of the tape pointer
    add r9, tape                             ; Add the tape address to the tape pointer value
    cmp byte [r9], 0                         ; Check if the value in the current cell is 0
    je frainbuck_jump_forward_loop           ; If so, move to the matching ']' character
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

frainbuck_jump_forward_loop:
    inc r8                                   ; Go to the next character from the brainfuck source code
    cmp byte [r8], ']'                       ; Check if the current character is ']'
    jne frainbuck_jump_forward_loop          ; If not, loop
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Jump to the matching '[' character
; @modifies R9 and possibly the R8 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_jump_backward:
    mov r9, [tape_offset]                    ; Store the value of the tape pointer
    add r9, tape                             ; Add the tape address to the tape pointer value
    cmp byte [r9], 0                         ; Check if the value in the current cell is 0
    jne frainbuck_jump_backward_loop         ; If not, move to the matching '[' character
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

frainbuck_jump_backward_loop:
    dec r8                                   ; Go to the previous character from the brainfuck source code
    cmp byte [r8], '['                       ; Check if the current character is '['
    jne frainbuck_jump_backward_loop         ; If not, loop
    jmp frainbuck_parse_source_code_continue ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Copy a string from one address to another
; @param r10 The address of the string to copy from
; @param r11 The address of the string to copy to
; @modifies AL, R10, R11 registers
; ----------------------------------------------------------------------------------------------------------------------
string_copy:
    cmp byte [r10], 0                        ; Check if the string is empty
    je string_copy_done                      ; If so, exit the function
    mov al, [r10]                            ; Store the current character in AL
    mov [r11], al                            ; Store the current character in the destination address
    inc r10                                  ; Move to the next character from the source
    inc r11                                  ; Move to the next character in the destination
    jmp string_copy                          ; Loop

string_copy_done:
    ret

; ----------------------------------------------------------------------------------------------------------------------
; @brief Open a file with a given filename
; @param filename The name of the file to open stored in the RDI register
; @note Assumes that the filename is already stored in the RDI register
; @modifies RAX, RDI, RSI, RDX registers
; ----------------------------------------------------------------------------------------------------------------------
open_file:
    mov rax, 2                               ; Syscall open (2)
    mov rsi, 0                               ; Read only
    mov rdx, 0                               ; No permissions - Doesn't matter for reading
    syscall                                  ; Syscall
    cmp rax, 0                               ; Check if the file was opened successfully
    jle exit_failure                         ; If not, exit the interpreter
    mov [file_descriptor], rax               ; Save the file descriptor
    ret                                      ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Close a file with a given file descriptor
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
close_file:
    mov rax, 3                               ; Syscall close (3)
    mov rdi, [file_descriptor]               ; File descriptor
    syscall                                  ; Syscall
    ret                                      ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Read the contents of a file with a given file descriptor
; @param text_buffer The address of the text buffer stored in the RSI register
; @param text_buffer_size The size of the text buffer stored in the RDX register
; @note Assumes that the text buffer and text buffer size are already stored in the RSI and RDX registers
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
read_file:
    mov rax, 0                               ; Syscall read (0)
    mov rdi, [file_descriptor]               ; File descriptor
    syscall                                  ; Syscall
    cmp rax, 0                               ; Check if the file was read successfully
    jle exit_failure                         ; If not, exit the interpreter
    ret                                      ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Exit with a success exit code
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
exit_success:
    mov rax, 60                              ; Syscall exit (60)
    mov rdi, 0                               ; Exit code
    syscall                                  ; Syscall

; ----------------------------------------------------------------------------------------------------------------------
; @brief Exit with a failure exit code
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
exit_failure:
    mov rax, 60                              ; Syscall exit (60)
    mov rdi, 2                               ; Exit code
    syscall                                  ; Syscall
