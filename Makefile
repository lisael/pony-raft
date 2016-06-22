BUILD_DIR=build
BIN=$(BUILD_DIR)/$(shell basename `pwd` )

all: clean $(BUILD_DIR) $(BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN):
	ponyc -o $(BUILD_DIR)

clean:
	-rm -rf $(BUILD_DIR)

# debug
print-%  :
	@echo $* = $($*)
