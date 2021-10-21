# \ var
MODULE  = $(notdir $(CURDIR))
OS      = $(shell uname -s)
NOW     = $(shell date +%d%m%y)
REL     = $(shell git rev-parse --short=4 HEAD)
BRANCH  = $(shell git rev-parse --abbrev-ref HEAD)
CORES   = $(shell grep processor /proc/cpuinfo| wc -l)
AUTHOR  = "Dmitry Ponyatov"
EMAIL   = "dponyatov@gmail.com"
APP     = nitro
HW      = qemu386
include app/$(APP).mk
include hw/$(HW).mk
include cpu/$(CPU).mk
include arch/$(ARCH).mk
# / var

# \ ver
BUILDROOT_VER = 2021.05.2
# / ver

# \ dir
CWD     = $(CURDIR)
BIN     = $(CWD)/bin
DOC     = $(CWD)/doc
LIB     = $(CWD)/lib
SRC     = $(CWD)/src
TMP     = $(CWD)/tmp
GZ      = $(HOME)/gz
FW      = $(CWD)/fw
ISO     = $(FW)/$(APP)$(HW).iso
# / dir

# \ tool
CURL    = curl -L -o
PY      = $(shell which python3)
PIP     = $(shell which pip3)
PEP     = $(shell which autopep8)
PYT     = $(shell which pytest)
# / tool

# \ src
Y   += $(MODULE).metaL.py metaL.py
S   += $(Y)
# / src

# \ cfg
BUILDROOT     = buildroot-$(BUILDROOT_VER)
BUILDROOT_GZ  = $(BUILDROOT).tar.gz
BUILDROOT_URL = https://github.com/buildroot/buildroot/archive/refs/tags/$(BUILDROOT_VER).tar.gz
# / cfg

# \ all

.PHONY: all
all:

.PHONY: meta
meta: $(PY) $(MODULE).metaL.py
	$^
	$(MAKE) format_py

format_py: tmp/format_py
tmp/format_py: $(Y)
	$(PEP) --ignore=E26,E302,E305,E401,E402,E701,E702 --in-place $?
	touch $@

.PHONY: qemu
qemu: $(ISO)
	$(QEMU) -m $(QEMU_MEM) -cdrom $<
# / all

# \ rule
%/README: $(GZ)/%.tar.gz
	tar zx < $< && touch $@
# / rule

# \ doc

.PHONY: doxy
doxy:
	rm -rf docs ; doxygen doxy.gen 1>/dev/null

.PHONY: doc
doc:
# / doc

# \ install
.PHONY: install update
install: $(OS)_install doc
	$(MAKE) update
update: $(OS)_update

.PHONY: Linux_install Linux_update
Linux_install Linux_update:
ifneq (,$(shell which apt))
	sudo apt update
	sudo apt install -u `cat apt.txt apt.dev`
endif

.PHONY: Msys_install Msys_update
Msys_install:
	pacman -S git make python3 python3-pip
Msys_update:

.PHONY: gz
gz: $(GZ)/$(BUILDROOT_GZ)
$(GZ)/$(BUILDROOT_GZ):
	$(CURL) $@ $(BUILDROOT_URL)

.PHONY: buildroot
buildroot: $(BUILDROOT)/README
	cd $(BUILDROOT) ; rm .config ; make allnoconfig ;\
	cat ../all/br >> .config ;\
	cat ../arch/$(ARCH).br >> .config ;\
	cat ../cpu/$(CPU).br >> .config ;\
	cat ../hw/$(HW).br >> .config ;\
	cat ../app/$(APP).br >> .config ;\
	echo "BR2_DL_DIR=\"$(GZ)\"" >> .config ;\
	echo "BR2_TARGET_GENERIC_HOSTNAME=\"$(APP)\"" >> .config ;\
	echo "BR2_TARGET_GENERIC_ISSUE=\"$(MODULE) @ $(HW) (c) $(AUTHOR) <$(EMAIL)>\"" >> .config ;\
	echo "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE=\"$(CWD)/all/kr\"" >> .config ;\
	echo "BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES=\"$(CWD)/arch/$(ARCH).kr $(CWD)/cpu/$(CPU).kr $(CWD)/hw/$(HW).kr $(CWD)/app/$(APP).kr\"" >> .config ;\
	echo "BR2_LINUX_KERNEL_CUSTOM_LOGO_PATH=\"$(CWD)/doc/logo.png\"" >> .config ;\
	make menuconfig && make
	$(MAKE) fw

.PHONY: fw
fw: $(ISO)
$(ISO): $(BUILDROOT)/output/images/rootfs.iso9660
	cp $< $@
BR_CONFIGS = $(shell find app hw arch cpu -type f)
$(BUILDROOT)/output/images/rootfs.iso9660: $(BR_CONFIGS)
	make buildroot
# / install

# \ merge
MERGE  = Makefile README.md .gitignore apt.dev apt.txt apt.msys doxy.gen $(S)
MERGE += .vscode bin doc lib src tmp
MERGE += app hw cpu arch

.PHONY: ponymuck
ponymuck:
	git push -v
	git checkout $@
	git pull -v

.PHONY: dev
dev:
	git push -v
	git checkout $@
	git pull -v
	git checkout ponymuck -- $(MERGE)
	$(MAKE) doxy ; git add -f docs

.PHONY: release
release:
	git tag $(NOW)-$(REL)
	git push -v --tags
	$(MAKE) ponymuck

.PHONY: zip
ZIP = $(TMP)/$(MODULE)_$(BRANCH)_$(NOW)_$(REL).src.zip
zip:
	git archive --format zip --output $(ZIP) HEAD
	$(MAKE) doxy ; zip -r $(ZIP) docs
# / merge
