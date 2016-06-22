BIN_NAME=$(shell basename `pwd` )

all: clean $(BIN_NAME)

$(BIN_NAME):
	ponyc

clean:
	-rm $(BIN_NAME)
	-rm $(BIN_NAME).o

# debug
print-%  :
	@echo $* = $($*)
