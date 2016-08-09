
GCC_ROOT ?= ./gcc-arm/arm-none-eabi-
CC := $(GCC_ROOT)gcc
CXX := $(GCC_ROOT)g++
LD := $(GCC_ROOT)ld
AR := $(GCC_ROOT)ar
OBJCOPY := $(GCC_ROOT)objcopy
ASM := $(GCC_ROOT)as
SIZE = $(GCC_ROOT)size

ECHO = echo
MKDIR = mkdir
PYTHON = python
DFU = ./tools/dfu.py

BSP_ROOT ?= BSP
EFP_BASE ?= .

#Additional flags
PREPROCESSOR_MACROS += ARM_MATH_CM4 USE_USB_FS stm32_flash_layout STM32F415xx
INCLUDE_DIRS += . $(BSP_ROOT)/STM32_USB_Device_Library/Core/Inc $(BSP_ROOT)/STM32_USB_Device_Library/Class/HID/Inc $(BSP_ROOT)/STM32F4xxxx/STM32F4xx_HAL_Driver/Inc $(BSP_ROOT)/STM32F4xxxx/STM32F4xx_HAL_Driver/Inc/Legacy $(BSP_ROOT)/STM32F4xxxx/CMSIS_HAL/Device/ST/STM32F4xx/Include $(BSP_ROOT)/STM32F4xxxx/CMSIS_HAL/Include $(BSP_ROOT)/STM32F4xxxx/CMSIS_HAL/RTOS/Template
INCLUDE_DIRS += mbedtls-2.2.1/include
LIBRARY_DIRS += 
# LIBRARY_NAMES += compactcpp
ADDITIONAL_LINKER_INPUTS += 
MACOS_FRAMEWORKS += 
LINUX_PACKAGES += 

COMMONFLAGS += -mcpu=cortex-m4 -mthumb -mfloat-abi=soft

CFLAGS += $(COMMONFLAGS)
CXXFLAGS += $(COMMONFLAGS)
ASFLAGS += $(COMMONFLAGS)
LDFLAGS += $(COMMONFLAGS)

CFLAGS = -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16
CFLAGS += -Og -fmessage-length=0 -fsigned-char 
CFLAGS += -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -c
CFLAGS += -ffunction-sections -fdata-sections -ffreestanding
CFLAGS += -fno-move-loop-invariants -Wall -Wextra
CFLAGS += -DDEBUG=1 -DSTM32F415xx -DUSE_HAL_DRIVER

CFLAGS += $(addprefix -I,$(INCLUDE_DIRS))
CXXFLAGS += $(addprefix -I,$(INCLUDE_DIRS))

CFLAGS += $(addprefix -D,$(PREPROCESSOR_MACROS))
CXXFLAGS += $(addprefix -D,$(PREPROCESSOR_MACROS))
ASFLAGS += $(addprefix -D,$(PREPROCESSOR_MACROS))

CXXFLAGS += $(addprefix -framework ,$(MACOS_FRAMEWORKS))
CFLAGS += $(addprefix -framework ,$(MACOS_FRAMEWORKS))
LDFLAGS += $(addprefix -framework ,$(MACOS_FRAMEWORKS))

LDFLAGS += $(addprefix -L,$(LIBRARY_DIRS))

SRCDIR = .
BUILD = bin

SRC_C = $(wildcard $(SRCDIR)/*.c)
SRC_C += $(wildcard $(SRCDIR)/mbedtls-2.2.1/library/*.c)
SRC_CPP = $(wildcard $(SRCDIR)/*.cpp)
SRC_ASM = $(wildcard $(SRCDIR)/*.s)

OBJS = $(addprefix $(BUILD)/, $(SRC_C:.c=.o))
OBJS += $(addprefix $(BUILD)/, $(SRC_CPP:.cpp=.o))
OBJS += $(addprefix $(BUILD)/, $(SRC_ASM:.s=.o))


all: $(BUILD)/firmware.dfu


$(BUILD)/firmware.dfu: $(BUILD)/firmware.elf
	$(ECHO) "Create $@"
	$(Q)$(OBJCOPY) -O binary -j .isr_vector $^ $(BUILD)/firmware0.bin
	$(Q)$(OBJCOPY) -O binary -j .text -j .inits -j .data $^ $(BUILD)/firmware1.bin
	$(Q)$(PYTHON) $(DFU) -b 0x08000000:$(BUILD)/firmware0.bin -b 0x08020000:$(BUILD)/firmware1.bin $@

$(BUILD)/firmware.hex: $(BUILD)/firmware.elf
	$(ECHO) "Create $@"
	$(Q)$(OBJCOPY) -O ihex $< $@

obj: $(OBJS)

$(BUILD)/firmware.elf: $(OBJS)
	$(ECHO) "LINK $@"
	$(CXX) -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -Og -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -ffreestanding -fno-move-loop-invariants -Wall -Wextra  -g3 -T ldscripts/mem.ld -T ldscripts/sections.ld -nostartfiles -Xlinker --gc-sections -Wl,-Map,"bin/sc4port.map" --specs=nano.specs -o $@ $^ $(LIBS)
	$(Q)$(SIZE) $@
#	$(Q)$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)


######################################

# This file expects that OBJ contains a list of all of the object files.
# The directory portion of each object file is used to locate the source
# and should not contain any ..'s but rather be relative to the top of the 
# tree.
#
# So for example, py/map.c would have an object file name py/map.o
# The object files will go into the build directory and mantain the same
# directory structure as the source tree. So the final dependency will look
# like this:
#
# build/py/map.o: py/map.c
#
# We set vpath to point to the top of the tree so that the source files
# can be located. By following this scheme, it allows a single build rule
# to be used to compile all .c files.

vpath %.S . $(TOP)
$(BUILD)/%.o: %.S
	$(ECHO) "CC $<"
	$(Q)$(CC) $(CFLAGS) -c -o $@ $<

vpath %.s . $(TOP)
$(BUILD)/%.o: %.s
	$(ECHO) "AS $<"
	$(Q)$(AS) -o $@ $<

define compile_c
$(ECHO) "CC $<"
$(Q)$(CC) $(CFLAGS) -c -MD -o $@ $<
@# The following fixes the dependency file.
@# See http://make.paulandlesley.org/autodep.html for details.
@# Regex adjusted from the above to play better with Windows paths, etc.
@$(CP) $(@:.o=.d) $(@:.o=.P); \
  $(SED) -e 's/#.*//' -e 's/^.*:  *//' -e 's/ *\\$$//' \
      -e '/^$$/ d' -e 's/$$/ :/' < $(@:.o=.d) >> $(@:.o=.P); \
  $(RM) -f $(@:.o=.d)
endef

define compile_cpp
$(ECHO) "CPP $<"
$(Q)$(CXX) $(CFLAGS) -c -MD -o $@ $<
@# The following fixes the dependency file.
@# See http://make.paulandlesley.org/autodep.html for details.
@# Regex adjusted from the above to play better with Windows paths, etc.
@$(CP) $(@:.o=.d) $(@:.o=.P); \
  $(SED) -e 's/#.*//' -e 's/^.*:  *//' -e 's/ *\\$$//' \
      -e '/^$$/ d' -e 's/$$/ :/' < $(@:.o=.d) >> $(@:.o=.P); \
  $(RM) -f $(@:.o=.d)
endef

vpath %.c . ..
$(BUILD)/%.o: %.c
	$(call compile_c)

vpath %.cpp . ..
$(BUILD)/%.o: %.cpp
	$(call compile_cpp)

$(BUILD)/%.pp: %.c
	$(ECHO) "PreProcess $<"
	$(Q)$(CC) $(CFLAGS) -E -Wp,-C,-dD,-dI -o $@ $<

# The following rule uses | to create an order only prereuisite. Order only
# prerequisites only get built if they don't exist. They don't cause timestamp
# checking to be performed.
#
# We don't know which source files actually need the generated.h (since
# it is #included from str.h). The compiler generated dependencies will cause
# the right .o's to get recompiled if the generated.h file changes. Adding
# an order-only dependendency to all of the .o's will cause the generated .h
# to get built before we try to compile any of them.
# $(OBJ): | $(HEADER_BUILD)/qstrdefs.generated.h $(HEADER_BUILD)/mpversion.h

# $(sort $(var)) removes duplicates
#
# The net effect of this, is it causes the objects to depend on the
# object directories (but only for existence), and the object directories
# will be created if they don't exist.
OBJ_DIRS = $(sort $(dir $(OBJS)))
$(OBJS): | $(OBJ_DIRS)
$(OBJ_DIRS):
	$(MKDIR) -p $@

clean:
	$(RM) -rf $(BUILD)
.PHONY: clean
