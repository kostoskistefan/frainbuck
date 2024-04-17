PROJECT_NAME := frainbuck

LD := ld
AS := nasm
AS_FLAGS := -felf64 -g -F dwarf

SOURCE_DIRECTORY := source
BUILD_DIRECTORY := build

all:
	$(AS) $(AS_FLAGS) $(SOURCE_DIRECTORY)/$(PROJECT_NAME).asm -o $(BUILD_DIRECTORY)/$(PROJECT_NAME).o
	$(LD) -o $(PROJECT_NAME) $(BUILD_DIRECTORY)/$(PROJECT_NAME).o

clean:
	rm -rf $(BUILD_DIRECTORY) $(PROJECT_NAME)

$(shell mkdir -p $(BUILD_DIRECTORY))
