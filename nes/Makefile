# constants
AS = ca65
ASFLAGS = -t nes

LD = ld65
LDFLAGS = -t nes

SRC_DIR = src
BUILD_DIR = build

SOURCES = $(wildcard $(SRC_DIR)/*.asm)
TARGETS = $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.nes,$(SOURCES))

# targets
all: $(TARGETS)

clean:
	$(RM) -r $(BUILD_DIR)

# rules
%: $(BUILD_DIR)/%.nes
	fceux $<

$(BUILD_DIR)/%.nes: $(BUILD_DIR)/%.o
	$(LD) $(LDFLAGS) $^ -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $^ -o $@

$(BUILD_DIR):
	mkdir -p $@