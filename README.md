# Frainbuck

Frainbuck is a Brainfuck interpreter written in x86_64 assembly. It is by no means optimized and is not intended to be. The main purpose of this project is for me to brush up on the fundamentals of assembly language.

## Requirements

* A x86_64 machine running Linux
* GNU Make
* NASM - Netwide Assembler
* LD - Linker

## Usage

* Clone this repository: `git clone https://github.com/kostoskistefan/frainbuck.git`
* Navigate to the cloned directory: `cd frainbuck`
* Compile: `make`
* Create a file called `input.bf` in the current directory and write your Brainfuck code there
* Run: `./frainbuck`
