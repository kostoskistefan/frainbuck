; Frainbuck - Brainfuck interpreter in x86_64 assembly
; Copyright (c) 2024, Kostoski Stefan (MIT License).
; https://github.com/kostoskistefan/frainbuck

; TODO: Make the second argument optional
; TODO: Add error messages
; TODO: Add checks for unmatched '[' and ']' characters
; TODO: Add a check for a frainbuck_input_pointer overflow and null terminator

; ----------------------------------------------------------------------------------------------------------------------
; Data Section
; ----------------------------------------------------------------------------------------------------------------------
section .data                                       ; Start of .data section
new_line db 10, 0                                   ; The new line character

; ----------------------------------------------------------------------------------------------------------------------
; Block starting symbol (BSS) section
; ----------------------------------------------------------------------------------------------------------------------
section .bss                                        ; Start of .bss section

filename_buffer_size equ 256                        ; The size of the filename buffer
filename resb filename_buffer_size                  ; The filename of the brainfuck code

frainbuck_input_buffer_size equ 1024                ; The size of the brainfuck input buffer
frainbuck_input resb frainbuck_input_buffer_size    ; The brainfuck input buffer
frainbuck_input_pointer resq 1                      ; The pointer to the current character in the brainfuck input buffer

tape_size equ 30000                                 ; The size of the brainfuck language tape
tape_offset resq 1                                  ; The current cell offset of the tape in the brainfuck language 
tape resb tape_size                                 ; The brainfuck language tape

text_buffer_size equ 10000                          ; The size of the input brainfuck code text buffer
text_buffer resb text_buffer_size                   ; The input brainfuck code text buffer

file_descriptor resd 1                              ; The file descriptor of the brainfuck code file

bracket_counter resd 1                              ; The current nesting level of the '[' character

; ----------------------------------------------------------------------------------------------------------------------
; Text Section
; ----------------------------------------------------------------------------------------------------------------------
section .text                                       ; Start of .text section
global _start                                       ; Make _start label available to linker

; ----------------------------------------------------------------------------------------------------------------------
; @brief Entry point
; ----------------------------------------------------------------------------------------------------------------------
_start:
    mov ecx, [rsp]
    cmp ecx, 3                                      ; Check if the number of arguments is 2
    jne exit_failure                                ; If not, exit the interpreter

    inc rsi                                         ; Skip the first argument (path of the executable)
    mov rdx, filename_buffer_size                   ; Store the size of the filename buffer in RDX register
    mov r10, [rsp + rsi * 8 + 8]                    ; Store the second argument in RDI register
    mov r11, filename                               ; Store the filename address in RSI register
    call string_copy                                ; Copy the filename into the filename buffer

    inc rsi                                         ; Move to the next argument
    mov rdx, frainbuck_input_buffer_size            ; Store the size of the brainfuck input buffer in RDX register
    mov r10, [rsp + rsi * 8 + 8]                    ; Store the second argument in RDI register
    mov r11, frainbuck_input                        ; Store the brainfuck input address in RSI register
    call string_copy                                ; Copy the brainfuck input into the frainbuck input buffer

    mov r11, frainbuck_input                        ; Store the brainfuck input address in R11 register
    mov [frainbuck_input_pointer], r11              ; Store the address of the first character in the input pointer
   
    mov rdi, filename                               ; Store the filename in RDI register
    call open_file                                  ; Open the brainfuck code file

    mov rsi, text_buffer                            ; Store the text buffer address in the RSI register
    mov rdx, text_buffer_size                       ; Store the text buffer size in the RDX register
    call read_file                                  ; Read the contents of the brainfuck code file

    call frainbuck_parse_source_code                ; Parse the source code 

    call close_file                                 ; Close the brainfuck code file

    mov rsi, new_line                               ; Store the new line character in the RSI register
    call print_character                            ; Print the new line character

    call exit_success                               ; Exit the interpreter

; ----------------------------------------------------------------------------------------------------------------------
; @brief Parse the brainfuck source code
; @modifies R8, R9 registers
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_parse_source_code:
    mov r8, text_buffer                             ; Store the memory address of the source code in the R8 register
    mov r9, text_buffer_size                        ; Store the size of the text buffer in the R9 register

frainbuck_parse_source_code_loop:
    cmp r9, 0                                       ; Check if we've reached the end of the text buffer memory
    jle exit_failure                                ; If so, exit the interpreter

    cmp byte [r8], 0                                ; Check if the current character is EOF
    jle frainbuck_parse_source_code_end             ; If so, exit the interpreter

    cmp byte [r8], '+'                              ; Check if the current character is '+'
    je frainbuck_increment_cell_value               ; If so, increment the value stored in the currently selected cell

    cmp byte [r8], '-'                              ; Check if the current character is '-'
    je frainbuck_decrement_cell_value               ; If so, decrement the value stored in the currently selected cell

    cmp byte [r8], '>'                              ; Check if the current character is '>'
    je frainbuck_increment_tape_pointer             ; If so, increment the tape pointer

    cmp byte [r8], '<'                              ; Check if the current character is '<'
    je frainbuck_decrement_tape_pointer             ; If so, decrement the tape pointer

    cmp byte [r8], '.'                              ; Check if the current character is '.'
    je frainbuck_print_cell_value                   ; If so, print the value stored in the currently selected cell

    cmp byte [r8], ','                              ; Check if the current character is ','
    je frainbuck_read_input_in_cell                 ; If so, read the value from stdin and store it in the current cell

    cmp byte [r8], '['                              ; Check if the current character is '['
    je frainbuck_jump_forward                       ; If so, conditionally jump to the matching ']' character

    cmp byte [r8], ']'                              ; Check if the current character is ']'
    je frainbuck_jump_backward                      ; If so, conditionally jump to the matching '[' character

frainbuck_parse_source_code_continue:
    inc r8                                          ; Increment the memory address
    dec r9                                          ; Decrement the size
    jmp frainbuck_parse_source_code_loop            ; Jump to the source code parsing loop

frainbuck_parse_source_code_end:
    ret                                             ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Increment the value in the cell where the tape pointer is pointing to
; @modifies R10 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_increment_cell_value:
    mov r10, [tape_offset]                          ; Store the value of the tape pointer
    add r10, tape                                   ; Add the tape address to the tape pointer value
    inc byte [r10]                                  ; Increment the value in the current cell
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Decrement the value in the cell where the tape pointer is pointing to
; @modifies R10 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_decrement_cell_value:
    mov r10, [tape_offset]                          ; Store the value of the tape pointer
    add r10, tape                                   ; Add the tape address to the tape pointer value
    dec byte [r10]                                  ; Decrement the value in the current cell
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Increment the brainfuck tape pointer
; @modifies none
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_increment_tape_pointer:
    inc qword [tape_offset]                         ; Increment the tape pointer
    cmp qword [tape_offset], tape_size              ; Check if the tape pointer is equal to the tape size
    jge frainbuck_increment_tape_pointer_wrap       ; If so, wrap around
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

frainbuck_increment_tape_pointer_wrap:
    mov qword [tape_offset], 0                      ; Wrap around
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Decrement the brainfuck tape pointer
; @modifies none
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_decrement_tape_pointer:
    dec qword [tape_offset]                         ; Decrement the tape pointer
    cmp qword [tape_offset], 0                      ; Check if the tape pointer is 0
    jl frainbuck_decrement_tape_pointer_wrap       ; If so, wrap around
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

frainbuck_decrement_tape_pointer_wrap:
    mov qword [tape_offset], tape_size              ; Wrap around
    dec qword [tape_offset]                         ; Decrement the tape pointer because we start at index 0
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Print the value in the cell where the tape pointer is pointing to
; @modifies RAX, RSI, RDI, RDX registers
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_print_cell_value:
    mov rsi, [tape_offset]                          ; Store the value of the tape pointer
    add rsi, tape                                   ; Add the tape address to the tape pointer value
    mov rax, 1                                      ; Syscall write (1)
    mov rdi, 1                                      ; STDOUT File descriptor
    mov rdx, 1                                      ; Memory size
    syscall                                         ; Syscall
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Read one character from stdin and store it in the current cell
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_read_input_in_cell:
    mov r10, [tape_offset]                          ; Store the value of the tape pointer
    add r10, tape                                   ; Add the tape address to the tape pointer value
    mov r11, [frainbuck_input_pointer]              ; Store the value of the input pointer which is a character address
    mov rax, [r11]                                  ; Read the character from the address in R11
    mov [r10], rax                                  ; Store the character in the current cell
    inc qword [frainbuck_input_pointer]             ; Increment the brainfuck input pointer
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Jump to the matching ']' character
; @modifies R10 and possibly the R8 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_jump_forward:
    mov r10, [tape_offset]                          ; Store the value of the tape pointer
    add r10, tape                                   ; Add the tape address to the tape pointer value
    cmp byte [r10], 0                               ; Check if the value in the current cell is 0
    jne frainbuck_parse_source_code_continue        ; If not, continue parsing the next characters

frainbuck_jump_forward_loop:
    inc r8                                          ; Go to the next character from the brainfuck source code
    dec r9                                          ; Decrement the source code iterator
    cmp byte [r8], ']'                              ; Check if the current character is ']'
    je frainbuck_jump_forward_unnest                ; If so, 
    cmp byte [r8], '['                              ; Check if the current character is '['
    je frainbuck_jump_forward_nest                  ; If so, 
    jmp frainbuck_jump_forward_loop                 ; Continue looping

frainbuck_jump_forward_nest:
    inc dword [bracket_counter]                     ; Increment the bracket counter
    jmp frainbuck_jump_forward_loop                 ; Continue looping

frainbuck_jump_forward_unnest:
    cmp dword [bracket_counter], 0                  ; Check if the bracket counter is 0
    je frainbuck_parse_source_code_continue         ; Jump to the source code parsing loop
    dec dword [bracket_counter]                     ; Decrement the bracket counter
    jmp frainbuck_jump_forward_loop                 ; Continue looping

; ----------------------------------------------------------------------------------------------------------------------
; @brief Jump to the matching '[' character
; @modifies R10 and possibly the R8 register
; ----------------------------------------------------------------------------------------------------------------------
frainbuck_jump_backward:
    mov r10, [tape_offset]                          ; Store the value of the tape pointer
    add r10, tape                                   ; Add the tape address to the tape pointer value
    cmp byte [r10], 0                               ; Check if the value in the current cell is 0
    je frainbuck_parse_source_code_continue         ; If so, continue parsing the next characters

frainbuck_jump_backward_loop:
    dec r8                                          ; Go to the previous character from the brainfuck source code
    inc r9                                          ; Increment the source code iterator
    cmp byte [r8], '['                              ; Check if the current character is '['
    je frainbuck_jump_backward_unnest               ; If so, 
    cmp byte [r8], ']'                              ; Check if the current character is ']'
    je frainbuck_jump_backward_nest                 ; If so,
    jmp frainbuck_jump_backward_loop                ; Jump to the source code parsing loop

frainbuck_jump_backward_nest:
    inc dword [bracket_counter]                     ; Increment the bracket counter
    jmp frainbuck_jump_backward_loop                ; Continue looping

frainbuck_jump_backward_unnest:
    cmp dword [bracket_counter], 0                  ; Check if the bracket counter is 0
    je frainbuck_jump_backward_end                  ; Jump to the source code parsing loop
    dec dword [bracket_counter]                     ; Decrement the bracket counter
    jmp frainbuck_jump_backward_loop                ; Continue looping

frainbuck_jump_backward_end:
    dec r8                                          ; Go to the previous character from the brainfuck source code
    inc r9                                          ; Increment the source code iterator
    jmp frainbuck_parse_source_code_continue        ; Jump to the source code parsing loop

; ----------------------------------------------------------------------------------------------------------------------
; @brief Copy a string from one address to another
; @param rdx The size of the destination buffer
; @param r10 The address of the string to copy from
; @param r11 The address of the string to copy to
; @modifies R10, R11, RAX, RCX, RDX registers
; ----------------------------------------------------------------------------------------------------------------------
string_copy:
    mov rcx, 0                                      ; Initialize the number of read characters

string_copy_loop:
    cmp rcx, rdx                                    ; Compare the number of read characters to the destination buffer size
    je string_copy_done                             ; If so, exit the function
    cmp byte [r10], 0                               ; Check if the string is empty
    je string_copy_done                             ; If so, exit the function
    mov rax, [r10]                                  ; Store the current character in RAX
    mov [r11], rax                                  ; Store the current character in the destination address
    inc rcx                                         ; Increment the number of read characters
    inc r10                                         ; Move to the next character from the source
    inc r11                                         ; Move to the next character in the destination
    jmp string_copy_loop                            ; Loop

string_copy_done:
    ret                                             ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Open a file with a given filename
; @param filename The name of the file to open stored in the RDI register
; @note Assumes that the filename is already stored in the RDI register
; @modifies RAX, RDI, RSI, RDX registers
; ----------------------------------------------------------------------------------------------------------------------
open_file:
    mov rax, 2                                      ; Syscall open (2)
    mov rsi, 0                                      ; Read only
    mov rdx, 0                                      ; No permissions - Doesn't matter for reading
    syscall                                         ; Syscall
    cmp rax, 0                                      ; Check if the file was opened successfully
    jle exit_failure                                ; If not, exit the interpreter
    mov [file_descriptor], rax                      ; Save the file descriptor
    ret                                             ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Close a file with a given file descriptor
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
close_file:
    mov rax, 3                                      ; Syscall close (3)
    mov rdi, [file_descriptor]                      ; File descriptor
    syscall                                         ; Syscall
    ret                                             ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Read the contents of a file with a given file descriptor
; @param text_buffer The address of the text buffer stored in the RSI register
; @param text_buffer_size The size of the text buffer stored in the RDX register
; @note Assumes that the text buffer and text buffer size are already stored in the RSI and RDX registers
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
read_file:
    mov rax, 0                                      ; Syscall read (0)
    mov rdi, [file_descriptor]                      ; File descriptor
    syscall                                         ; Syscall
    cmp rax, 0                                      ; Check if the file was read successfully
    jle exit_failure                                ; If not, exit the interpreter
    ret                                             ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Print a character to the console
; @param character The character to print stored in the RSI register
; @modifies RAX, RDI, RDX registers
; ----------------------------------------------------------------------------------------------------------------------
print_character:
    mov rax, 1                                      ; Syscall write (1)
    mov rdi, 1                                      ; STDOUT File descriptor
    mov rdx, 1                                      ; Memory size
    syscall                                         ; Syscall
    ret                                             ; Return

; ----------------------------------------------------------------------------------------------------------------------
; @brief Exit with a success exit code
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
exit_success:
    mov rax, 60                                     ; Syscall exit (60)
    mov rdi, 0                                      ; Exit code
    syscall                                         ; Syscall

; ----------------------------------------------------------------------------------------------------------------------
; @brief Exit with a failure exit code
; @modifies RAX, RDI registers
; ----------------------------------------------------------------------------------------------------------------------
exit_failure:
    mov rax, 60                                     ; Syscall exit (60)
    mov rdi, 2                                      ; Exit code
    syscall                                         ; Syscall
