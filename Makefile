BUILD_DIR=build
PONYC=ponyc
PONY_SRC=$(wildcard **/*.pony) $(wildcard *.pony)
BIN=$(BUILD_DIR)/$(shell basename `pwd` )
TEST_BIN=$(BUILD_DIR)/test

all: $(BUILD_DIR) test $(BIN)

test: $(TEST_BIN) runtest

$(TEST_BIN): $(PONY_SRC)
	$(PONYC) -o $(BUILD_DIR) test

runtest:
	./$(TEST_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN): $(PONY_SRC) 
	$(PONYC) -o $(BUILD_DIR)

clean:
	-rm -rf $(BUILD_DIR)

# debug
print-%  :
	@echo $* = $($*)
