include br-template.config

BR2T_BR_FILE = buildroot-$(BR2T_VERSION).tar.bz2
BR2T_CONFIG = out/$(BR2T_DEFCONFIG)/.config
BR2T_RECOVERY_CONFIG = out/$(BR2T_RECOVERY_DEFCONFIG)/.config
BR2T_DL = out/dl
BR2T_BR_DIR = out/buildroot-$(BR2T_VERSION)
BR2T_IMG_DIR = out/images
BR2T_UPD_DIR = out/update
BR2T_TMP_DIR = $(BR2T_UPD_DIR)/tmp

BR2T_ID := $(shell git log -1 --pretty=format:"%h")

export BR2_DL_DIR='$(CURDIR)/$(BR2T_DL)'

all: image update

$(BR2T_EXTERNAL)/external.desc:
	@mkdir -p $(BR2T_EXTERNAL)
	@mkdir -p $(BR2T_EXTERNAL)/board
	@mkdir -p $(BR2T_EXTERNAL)/configs
	@mkdir -p $(BR2T_EXTERNAL)/package
	@echo '# Example: source "$(BR2T_EXTERNAL)/package/package1/Config.in"' > \
		$(BR2T_EXTERNAL)/Config.in
	@echo 'name: $(BR2T_NAME)' > $(BR2T_EXTERNAL)/external.desc

$(BR2T_BR_DIR):
	@mkdir -p $(BR2T_DL)
	@wget -c https://buildroot.org/downloads/$(BR2T_BR_FILE) \
		-O $(BR2T_DL)/$(BR2T_BR_FILE)
	@tar axf $(BR2T_DL)/$(BR2T_BR_FILE) -C out

$(BR2T_CONFIG): $(BR2T_BR_DIR) $(BR2T_EXTERNAL)/external.desc
	$(MAKE) -C out/buildroot-$(BR2T_VERSION) O=../$(BR2T_DEFCONFIG) \
		BR2_EXTERNAL=$(CURDIR)/$(BR2T_EXTERNAL) $(BR2T_DEFCONFIG)_defconfig
	@mkdir -p $(BR2T_IMG_DIR)

$(BR2T_RECOVERY_CONFIG):
	$(MAKE) -C out/buildroot-$(BR2T_VERSION) O=../$(BR2T_RECOVERY_DEFCONFIG) \
		BR2_EXTERNAL=$(CURDIR)/$(BR2T_EXTERNAL) $(BR2T_RECOVERY_DEFCONFIG)_defconfig

$(BR2T_DEFCONFIG) $(BR2T_RECOVERY_DEFCONFIG): $(BR2T_CONFIG) $(BR2T_RECOVERY_CONFIG)
	$(MAKE) -l -C out/$@ $(subst $@,,$(MAKECMDGOALS))

image: $(BR2T_CONFIG) $(BR2T_RECOVERY_CONFIG)
	$(MAKE) -l -C out/$(BR2T_DEFCONFIG) source
	$(MAKE) -l -C out/$(BR2T_DEFCONFIG)
	$(MAKE) -l -C out/$(BR2T_RECOVERY_DEFCONFIG) source
	$(MAKE) -l -C out/$(BR2T_RECOVERY_DEFCONFIG)
	@for file in $(BR2T_IMAGE_FILES); do \
		cp -v "$${file%%:*}" ${BR2T_IMG_DIR}/"$${file##*:}"; \
	done

recovery:
	@rm -rf $(BR2T_TMP_DIR)
	@mkdir -p $(BR2T_TMP_DIR)
	@cp -v $(BR2T_IMG_DIR)/* $(BR2T_TMP_DIR)/
	@cp -v $(BR2T_EXTERNAL)/$(BR2T_SWDESCRIPTION) $(BR2T_TMP_DIR)
	@cd $(BR2T_TMP_DIR) && \
	echo sw-description \
		$$(find . -type f -name "*" ! -name "sw-description*") \
		| tr " " "\n" | \
		cpio -ov -H crc > ../$(BR2T_NAME)_$(BR2T_ID).swu;
	@rm -rf $(BR2T_TMP_DIR)

clean:
	rm $(BR2T_EXTERNAL)/external.desc
	rm -rf $(BR2T_BR_DIR)
	rm -rf out/$(BR2T_DEFCONFIG)
	rm -rf out/$(BR2T_RECOVERY_DEFCONFIG)

distclean:
	rm -rf out
	git clean -fdx

%:
	@:

help:
	@echo br-template help
	@echo
	@echo 'Building'
	@echo '  all                    - compiles everything'
	@echo '  image                  - produces images files in $(BR2T_IMG_DIR)'
	@echo '  recovery                 - produces an update swu file in $(BR2T_UPD_DIR)'
	@echo
	@echo 'Cleaning'
	@echo '  clean                  - removes everything but keeps dl folder'
	@echo '  distclean              - reset the project to a clean state'
	@echo
	@echo 'Buildroot management'
	@$(foreach config,$(BR2T_DEFCONFIG) $(BR2T_RECOVERY_DEFCONFIG),\
	echo '$(config) [TARGET]' ; \
	echo '                         - calls TARGET on $(config) buildroot makefile';)
