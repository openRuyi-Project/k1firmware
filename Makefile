# SpacemiT K1 Firmware Build System
# Models: https://github.com/openRuyi-Project/k3firmware

ARCH           := riscv
NPROC          ?= $(shell nproc)
CROSS_COMPILE  ?= riscv64-linux-gnu-

UBOOT_DEFCONFIG ?= k1_defconfig
LINUX_REPO     ?= https://github.com/openRuyi-Project/linux.git
LINUX_DTB_DIR  ?= $(CURDIR)/linux/arch/riscv/boot/dts/spacemit
LINUX_DTBS     := k1-bananapi-f3.dtb k1-milkv-jupiter.dtb k1-orangepi-rv2.dtb

OPENSBI_DIR    := $(CURDIR)/opensbi
OPENSBI_OUT    := $(OPENSBI_DIR)/output
OPENSBI_STD    := $(OPENSBI_OUT)/fw_dynamic-k1.itb
OPENSBI_RVA23  := $(OPENSBI_OUT)/fw_dynamic-k1-rva23.itb

OUTPUT         := $(CURDIR)/output
DIST           := $(CURDIR)/dist

# ─── Dependency check helpers ────────────────────────────────────────

define check_cmd
	@if ! command -v $(1) >/dev/null 2>&1; then \
		echo "WARNING: $(1) not found$(if $(2), (apt: $(2)))"; \
	fi
endef

APT_DEPS_COMMON := git make gcc
APT_DEPS_UBOOT  := gcc-riscv64-linux-gnu device-tree-compiler
APT_DEPS_OPENSBI := gcc-riscv64-linux-gnu python3
APT_DEPS_LINUX  := gcc-riscv64-linux-gnu flex bison libssl-dev bc

# ─── Top-level targets ───────────────────────────────────────────────

.PHONY: all clean check-deps install-deps submodules
.PHONY: linux-dtbs u-boot opensbi opensbi-rva23 dist

all: dist

check-deps:
	$(call check_cmd,git,git)
	$(call check_cmd,$(CROSS_COMPILE)gcc,gcc-riscv64-linux-gnu)
	$(call check_cmd,mkimage,u-boot-tools)
	$(call check_cmd,dtc,device-tree-compiler)
	$(call check_cmd,flex,flex)
	$(call check_cmd,bison,bison)
	$(call check_cmd,python3,python3)

install-deps:
	sudo apt-get update
	sudo apt-get install -y \
		$(APT_DEPS_COMMON) \
		$(APT_DEPS_UBOOT) \
		$(APT_DEPS_OPENSBI) \
		$(APT_DEPS_LINUX)

# ─── Submodules ──────────────────────────────────────────────────────

submodules:
	git submodule update --init --recursive --depth 1

# ─── Linux DTBs ──────────────────────────────────────────────────────

linux:
	git clone --depth 1 $(LINUX_REPO) linux

$(addprefix $(LINUX_DTB_DIR)/,$(LINUX_DTBS)): | linux
	$(MAKE) -C $(CURDIR)/linux -j$(NPROC) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) defconfig
	$(MAKE) -C $(CURDIR)/linux -j$(NPROC) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) dtbs

linux-dtbs: $(addprefix $(LINUX_DTB_DIR)/,$(LINUX_DTBS))

# ─── U-Boot ──────────────────────────────────────────────────────────

u-boot: u-boot/.config linux-dtbs
	$(MAKE) -C u-boot -j$(NPROC) CROSS_COMPILE=$(CROSS_COMPILE) \
		LINUX_DTB_DIR=$(LINUX_DTB_DIR)

u-boot/.config: | submodules
	$(MAKE) -C u-boot -j$(NPROC) CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_DEFCONFIG)

# ─── OpenSBI (standard + RVA23 emulation) ────────────────────────────

opensbi: | submodules
	cd $(OPENSBI_DIR) && ./scripts/build-k1-firmware.sh standard

opensbi-rva23: | submodules
	cd $(OPENSBI_DIR) && ./scripts/build-k1-firmware.sh rva23

# ─── Firmware collection ─────────────────────────────────────────────

dist: u-boot opensbi opensbi-rva23
	@mkdir -p $(DIST)/factory
	cp $(CURDIR)/u-boot/u-boot.itb              $(DIST)/u-boot.itb
	cp $(CURDIR)/u-boot/FSBL.bin               $(DIST)/factory/FSBL.bin
	cp $(CURDIR)/u-boot/bootinfo_spinor.bin    $(DIST)/factory/bootinfo_spinor.bin
	cp $(CURDIR)/u-boot/u-boot-env-default.bin $(DIST)/env.bin
	cp $(OPENSBI_STD)                           $(DIST)/fw_dynamic-k1.itb
	cp $(OPENSBI_RVA23)                         $(DIST)/fw_dynamic-k1-rva23.itb
	cp scripts/partition_2M.json               $(DIST)/partition_2M.json
	cp scripts/flash.sh                        $(DIST)/flash.sh
	cp scripts/flash.bat                       $(DIST)/flash.bat
	@echo "==> Firmware collected in $(DIST)/"

# ─── Clean ───────────────────────────────────────────────────────────

clean:
	-if [ -d $(CURDIR)/linux ]; then $(MAKE) -C linux ARCH=$(ARCH) clean; fi
	-$(MAKE) -C u-boot clean
	-$(MAKE) -C opensbi clean
	-rm -rf $(OPENSBI_OUT)
	-rm -rf $(OUTPUT)
	-rm -rf $(DIST)
