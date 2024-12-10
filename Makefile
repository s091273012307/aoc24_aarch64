DEPS=utils.asm 

all: day1

day1: day1.asm $(DEPS)
	clang -target aarch64-linux-gnu -nostdlib -c day1.asm -o day1.bin;llvm-objcopy --dump-section=.text=day1 day1.bin

clean:
	rm -rf day1.bin day1

