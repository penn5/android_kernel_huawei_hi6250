#Android makefile to build kernel as a part of Android Build
ifeq ($(BALONG_TOPDIR),)
export BALONG_TOPDIR := $(shell pwd)/vendor/hisi
endif

ifeq ($(TARGET_ARM_TYPE), arm64)
KERNEL_ARCH_PREFIX := arm64
CROSS_COMPILE_PREFIX=aarch64-linux-android-
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/arch/arm64/boot/Image.gz
else
KERNEL_ARCH_PREFIX := arm
CROSS_COMPILE_PREFIX=arm-linux-gnueabihf-
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
endif

ifeq ($(CFG_CONFIG_HISI_FAMA),true)
BALONG_FAMA_FLAGS := -DCONFIG_HISI_FAMA
else
BALONG_FAMA_FLAGS :=
endif

export BALONG_INC
export BALONG_FAMA_FLAGS

KERNEL_N_TARGET ?= vmlinux
UT_EXTRA_CONFIG ?=

DTS_AUTO_GENERATE:= $(TOP)/kernel/$(LINUX_VERSION)/arch/arm64/boot/dts/auto-generate
DTS_KERNEL_OUT:= $(TOP)/out/target/product/$(TARGET_PRODUCT)/obj/KERNEL_OBJ/arch/arm64/boot/dts/auto-generate

HI3650_MODEM_DRV_DIR := $(shell pwd)/vendor/hisi/modem/drv/acore/kernel/drivers/hisi/modem/drv
ifeq ($(wildcard $(HI3650_MODEM_DRV_DIR)),)
$(HI3650_MODEM_DRV_DIR):
	@$(INC_PLUS)mkdir -p $(HI3650_MODEM_DRV_DIR)
	@$(INC_PLUS)touch $(HI3650_MODEM_DRV_DIR)/Makefile
	@$(INC_PLUS)touch $(HI3650_MODEM_DRV_DIR)/Kconfig
endif

ifneq ($(TARGET_BUILD_VARIANT),eng)
KERNEL_DEBUG_CONFIGFILE := $(KERNEL_COMMON_DEFCONFIG)
KERNEL_TOBECLEAN_CONFIGFILE :=
KERNEL_KASAN_CONFIGFILE :=

$(KERNEL_DEBUG_CONFIGFILE):
	echo "will not compile debug modules"

else
ifeq ($(strip $(KERNEL_DEBUG)),false)
KERNEL_DEBUG_CONFIGFILE := $(KERNEL_COMMON_DEFCONFIG)
KERNEL_TOBECLEAN_CONFIGFILE :=
KERNEL_KASAN_CONFIGFILE :=
else
KERNEL_DEBUG_CONFIGFILE :=  $(KERNEL_ARCH_ARM_CONFIGS)/merge_hi6250_defconfig
KERNEL_TOBECLEAN_CONFIGFILE := $(KERNEL_DEBUG_CONFIGFILE)
KERNEL_GEN_CONFIG_FILE := $(KERNEL_COMMON_DEFCONFIG)
KERNEL_GEN_CONFIG_PATH := $(KERNEL_DEBUG_CONFIGFILE)

ifeq ($(ENG_DEBUG_VERSION),true)
KERNEL_ENG_DEBUG_CONFIGFILE := $(KERNEL_ARCH_ARM_CONFIGS)/merge_hi6250_defconfig
$(KERNEL_ENG_DEBUG_CONFIGFILE):$(KERNEL_COMMON_DEFCONFIG) $(wildcard $(KERNEL_ENG_DEBUG_CONFIGS)/*)
	touch $(KERNEL_ENG_DEBUG_CONFIGFILE)
	@$(INC_PLUS)$(TOP)/device/hisi/customize/build_script/kernel-config.sh -f $(KERNEL_COMMON_DEFCONFIG) -d $(KERNEL_ENG_DEBUG_CONFIGS) -o $(KERNEL_ENG_DEBUG_CONFIGFILE)

$(KERNEL_DEBUG_CONFIGFILE):$(KERNEL_ENG_DEBUG_CONFIGFILE) $(wildcard $(KERNEL_DEBUG_CONFIGS)/*)
	touch $(KERNEL_DEBUG_CONFIGFILE)
	@$(INC_PLUS)$(TOP)/device/hisi/customize/build_script/kernel-config.sh -f $(KERNEL_ENG_DEBUG_CONFIGFILE) -d $(KERNEL_DEBUG_CONFIGS) -o $(KERNEL_DEBUG_CONFIGFILE)
else
KERNEL_ENG_DEBUG_CONFIGFILE :=
ifneq ($(TARGET_SANITIZER_MODE),)
KERNEL_KASAN_CONFIGFILE := $(KERNEL_ARCH_ARM_CONFIGS)/hisi_$(TARGET_PRODUCT)_kasan_defconfig

$(KERNEL_KASAN_CONFIGFILE):$(KERNEL_COMMON_DEFCONFIG) $(wildcard $(KERNEL_KASAN_CONFIGS)/*)
	@$(INC_PLUS)$(TOP)/device/hisi/customize/build_script/kernel-config.sh -f $(KERNEL_COMMON_DEFCONFIG) -d $(KERNEL_KASAN_CONFIGS) -o $(KERNEL_KASAN_CONFIGFILE)

$(KERNEL_DEBUG_CONFIGFILE):$(KERNEL_KASAN_CONFIGFILE) $(wildcard $(KERNEL_DEBUG_CONFIGS)/*)
	@$(INC_PLUS)$(TOP)/device/hisi/customize/build_script/kernel-config.sh -f $(KERNEL_KASAN_CONFIGFILE) -d $(KERNEL_DEBUG_CONFIGS) -o $(KERNEL_DEBUG_CONFIGFILE)
else
KERNEL_KASAN_CONFIGFILE :=
$(KERNEL_DEBUG_CONFIGFILE):$(KERNEL_COMMON_DEFCONFIG) $(wildcard $(KERNEL_DEBUG_CONFIGS)/*)
	@$(INC_PLUS)$(TOP)/device/hisi/customize/build_script/kernel-config.sh -f $(KERNEL_COMMON_DEFCONFIG) -d $(KERNEL_DEBUG_CONFIGS) -o $(KERNEL_DEBUG_CONFIGFILE)
endif
endif
endif
endif

GENERATE_DTB := $(KERNEL_OUT)/.timestamp
$(GENERATE_DTB):$(DEPENDENCY_FILELIST)
	$(DTS_PARSE_CONFIG)
	@mkdir -p $(KERNEL_OUT)
	@touch $@

ifeq ($(strip $(llt_gcov)),y)
HISI_MDRV_GCOV_DEFCONFIG := ${KERNEL_ARCH_ARM_CONFIGS}/gcov_defconfig
APPEND_MODEM_GCOV_DEFCONFIG := cat $(HISI_MDRV_GCOV_DEFCONFIG) >> $(KERNEL_GEN_CONFIG_PATH)
endif

ifdef APPEND_MODEM_DEFCONFIG
	$(APPEND_MODEM_DEFCONFIG)
endif
ifeq ($(strip $(llt_gcov)),y)
	$(shell $(APPEND_MODEM_GCOV_DEFCONFIG))
endif

kernel_modem_config : $(KERNEL_GEN_CONFIG_PATH)
	@echo $@

ifeq ($(OBB_PRINT_CMD), true)
$(KERNEL_CONFIG): MAKEFLAGS :=
$(KERNEL_CONFIG):$(KERNEL_GEN_CONFIG_PATH) $(HI3650_MODEM_DRV_DIR)
	$(INC_PLUS)mkdir -p $(KERNEL_OUT)
	$(INC_PLUS)$(MAKE) -C $(kernel_path) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_GEN_CONFIG_FILE)
else
ifeq ($(HISI_PILOT_LIBS), true)
$(KERNEL_CONFIG): $(KERNEL_GEN_CONFIG_PATH) HISI_PILOT_PREBUILD $(HI3650_MODEM_DRV_DIR)
else
$(KERNEL_CONFIG): $(KERNEL_GEN_CONFIG_PATH) $(HI3650_MODEM_DRV_DIR)
endif
	mkdir -p $(KERNEL_OUT)
	$(MAKE) -C $(kernel_path) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_GEN_CONFIG_FILE)
endif

ifeq ($(OBB_PRINT_CMD), true)
$(TARGET_PREBUILT_KERNEL): FORCE $(GPIO_IOMUX_FILE) | $(KERNEL_CONFIG)
	$(hide) $(MAKE) -C $(kernel_path) -j1 O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_N_TARGET)
	mkdir -p $(KERNEL_OUT)/arch/arm64/boot
	touch $(TARGET_PREBUILT_KERNEL)
	@rm -frv $(KERNEL_TOBECLEAN_CONFIGFILE)
	@rm -frv $(KERNEL_KASAN_CONFIGFILE)
	@rm -frv $(KERNEL_ENG_DEBUG_CONFIGFILE)
	@rm -frv $(KERNEL_GEN_CONFIG_PATH)
else
$(TARGET_PREBUILT_KERNEL): FORCE  $(GPIO_IOMUX_FILE)  $(GENERATE_DTB) | $(KERNEL_CONFIG)
	#$(kernel_path)/scripts/copy_kernel_obj_to_out.sh $(kernel_path) $(KERNEL_OUT)
	$(MAKE) -C $(kernel_path) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX)
	touch $(TARGET_PREBUILT_KERNEL)
	@rm -frv $(KERNEL_TOBECLEAN_CONFIGFILE)
	@rm -frv $(KERNEL_KASAN_CONFIGFILE)
	@rm -frv $(KERNEL_ENG_DEBUG_CONFIGFILE)
	@rm -frv $(KERNEL_GEN_CONFIG_PATH)
endif


HISI_PILOT_PREBUILD:
	$(hide) rm -rf $(kernel_path)/include/huawei_platform
	$(hide) rm -rf $(kernel_path)/include/modem
	$(hide) rm -rf $(kernel_path)/drivers/huawei_platform
	$(hide) rm -rf $(kernel_path)/drivers/huawei_platform_legacy
	$(hide) rm -rf $(kernel_path)/drivers/hisi/modem_hi6xxx
	$(hide) rm -rf $(kernel_path)/drivers/device-depend-arm64
	$(hide) cp -rf $(HISI_PILOT_TOPDIR)$(kernel_path)/include/huawei_platform $(kernel_path)/include/.
	$(hide) cp -rf $(HISI_PILOT_TOPDIR)$(kernel_path)/include/modem $(kernel_path)/include/.
	$(hide) cp -rf $(HISI_PILOT_TOPDIR)$(kernel_path)/drivers/huawei_platform $(kernel_path)/drivers/
	$(hide) cp -rf $(HISI_PILOT_TOPDIR)$(kernel_path)/drivers/huawei_platform_legacy $(kernel_path)/drivers/
	$(hide) cp -rf $(HISI_PILOT_TOPDIR)$(kernel_path)/drivers/hisi/modem_hi6xxx $(kernel_path)/drivers/hisi/.
	$(hide) cp $(HISI_PILOT_KERNEL_DIR)/Makefile.pilot $(HISI_PILOT_KERNEL_DIR)/Makefile
	$(hide) cp $(HISI_PILOT_KERNEL_DIR)/Kconfig.pilot $(HISI_PILOT_KERNEL_DIR)/Kconfig

kernelconfig: $(KERNEL_GEN_CONFIG_PATH)
	mkdir -p $(KERNEL_OUT)
	$(MAKE) -C $(kernel_path) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) $(KERNEL_GEN_CONFIG_FILE) menuconfig

zImage Image:$(TARGET_PREBUILT_KERNEL)
	@mkdir -p $(dir $(INSTALLED_KERNEL_TARGET))
	@cp -fp $(TARGET_PREBUILT_KERNEL) $(INSTALLED_KERNEL_TARGET)

pclint_kernel: $(KERNEL_CONFIG)
	$(hide) $(MAKE) -C $(kernel_path) O=$(KERNEL_OUT) ARCH=$(KERNEL_ARCH_PREFIX) CROSS_COMPILE=$(CROSS_COMPILE_PREFIX) pc_lint_all

export BOARD_CHARGER_ENABLE_DRM
