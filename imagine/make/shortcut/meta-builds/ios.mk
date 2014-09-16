include $(IMAGINE_PATH)/make/config.mk
-include $(projectPath)/config.mk
include $(IMAGINE_PATH)/make/iOS-metadata.mk

.PHONY: all
all : ios-build

ios_buildName ?= $(firstMakefileName:.mk=)
ios_targetPath ?= target/$(ios_buildName)
ios_targetBinPath := $(ios_targetPath)/bin
ios_bundleDirectory = $(iOS_metadata_bundleName).app
ios_deviceAppBundlePath := /Applications/$(ios_bundleDirectory)
ios_deviceExecPath := $(ios_deviceAppBundlePath)/$(iOS_metadata_exec)
ios_resourcePath := $(projectPath)/res/ios
ios_iconPath := $(projectPath)/res/icons/iOS
ios_plistTxt := $(ios_targetPath)/Info.txt
ios_plist := $(ios_targetPath)/Info.plist
ios_icons := $(wildcard $(ios_iconPath)/*)
ifdef HIGH_OPTIMIZE_CFLAGS
 ios_HIGH_OPTIMIZE_CFLAGS_param = "HIGH_OPTIMIZE_CFLAGS=$(HIGH_OPTIMIZE_CFLAGS)"
endif

# Host/IP of the iOS device to install the app over SSH
ios_installHost := iphone5

ios_arch ?= armv7 arm64
ifeq ($(filter armv6, $(ios_arch)),)
 ios_noARMv6 := 1
endif
ifeq ($(filter armv7, $(ios_arch)),)
 ios_noARMv7 := 1
endif
ifeq ($(filter armv7s, $(ios_arch)),)
 ios_noARMv7s := 1
endif
ifeq ($(filter arm64, $(ios_arch)),)
 ios_noARM64 := 1
endif
ifeq ($(filter x86, $(ios_arch)),)
 ios_noX86 := 1
endif

ifndef ios_noARMv6

ios_armv6Makefile ?= $(IMAGINE_PATH)/make/shortcut/common-builds/ios-armv6.mk
ios_armv6ExecName := $(iOS_metadata_exec)-armv6
ios_armv6Exec := $(ios_targetBinPath)/$(ios_armv6ExecName)
ios_armv6MakeArgs = -f $(ios_armv6Makefile) $(ios_makefileOpts)\
 targetDir=$(ios_targetBinPath) targetFile=$(ios_armv6ExecName) \
 buildName=$(ios_buildName)-armv6 $(ios_HIGH_OPTIMIZE_CFLAGS_param) \
 projectPath=$(projectPath)
ios_execs += $(ios_armv6Exec)
.PHONY: ios-armv6
ios-armv6 :
	@echo "Building ARMv6 Executable"
	$(PRINT_CMD)$(MAKE) $(ios_armv6MakeArgs)
$(ios_armv6Exec) : ios-armv6

.PHONY: ios-armv6-clean
ios-armv6-clean :
	@echo "Cleaning ARMv6 Build"
	$(PRINT_CMD)$(MAKE) $(ios_armv6MakeArgs) clean
ios_cleanTargets += ios-armv6-clean

.PHONY: ios-armv6-install
ios-armv6-install : $(ios_armv6Exec)
	ssh root@$(ios_installHost) rm -f $(ios_deviceExecPath)
	scp $^ root@$(ios_installHost):$(ios_deviceExecPath)
	ssh root@$(ios_installHost) chmod a+x $(ios_deviceExecPath)
ifdef iOS_metadata_setuid
	ssh root@$(ios_installHost) chmod gu+s $(ios_deviceExecPath)
endif

endif

ifndef ios_noARMv7

ios_armv7Makefile ?= $(IMAGINE_PATH)/make/shortcut/common-builds/ios-armv7.mk
ios_armv7ExecName := $(iOS_metadata_exec)-armv7
ios_armv7Exec := $(ios_targetBinPath)/$(ios_armv7ExecName)
ios_armv7MakeArgs = -f $(ios_armv7Makefile) $(ios_makefileOpts) \
 targetDir=$(ios_targetBinPath) targetFile=$(ios_armv7ExecName) \
 buildName=$(ios_buildName)-armv7 $(ios_HIGH_OPTIMIZE_CFLAGS_param) \
 projectPath=$(projectPath)
ios_execs += $(ios_armv7Exec)
.PHONY: ios-armv7
ios-armv7 :
	@echo "Building ARMv7 Executable"
	$(PRINT_CMD)$(MAKE) $(ios_armv7MakeArgs)
$(ios_armv7Exec) : ios-armv7

.PHONY: ios-armv7-clean
ios-armv7-clean :
	@echo "Cleaning ARMv7 Build"
	$(PRINT_CMD)$(MAKE) $(ios_armv7MakeArgs) clean
ios_cleanTargets += ios-armv7-clean

.PHONY: ios-armv7-install
ios-armv7-install : $(ios_armv7Exec)
	ssh root@$(ios_installHost) rm -f $(ios_deviceExecPath)
	scp $^ root@$(ios_installHost):$(ios_deviceExecPath)
	ssh root@$(ios_installHost) chmod a+x $(ios_deviceExecPath)
ifdef iOS_metadata_setuid
	ssh root@$(ios_installHost) chmod gu+s $(ios_deviceExecPath)
endif

endif

ifndef ios_noARM64

ios_arm64Makefile ?= $(IMAGINE_PATH)/make/shortcut/common-builds/ios-arm64.mk
ios_arm64ExecName := $(iOS_metadata_exec)-arm64
ios_arm64Exec := $(ios_targetBinPath)/$(ios_arm64ExecName)
ios_arm64MakeArgs = -f $(ios_arm64Makefile) $(ios_makefileOpts) \
 targetDir=$(ios_targetBinPath) targetFile=$(ios_arm64ExecName) \
 buildName=$(ios_buildName)-arm64 $(ios_HIGH_OPTIMIZE_CFLAGS_param) \
 projectPath=$(projectPath)
ios_execs += $(ios_arm64Exec)
.PHONY: ios-arm64
ios-arm64 :
	@echo "Building ARM64 Executable"
	$(PRINT_CMD)$(MAKE) $(ios_arm64MakeArgs)
$(ios_arm64Exec) : ios-arm64

.PHONY: ios-arm64-clean
ios-arm64-clean :
	@echo "Cleaning ARM64 Build"
	$(PRINT_CMD)$(MAKE) $(ios_arm64MakeArgs) clean
ios_cleanTargets += ios-arm64-clean

.PHONY: ios-arm64-install
ios-arm64-install : $(ios_arm64Exec)
	ssh root@$(ios_installHost) rm -f $(ios_deviceExecPath)
	scp $^ root@$(ios_installHost):$(ios_deviceExecPath)
	ssh root@$(ios_installHost) chmod a+x $(ios_deviceExecPath)
ifdef iOS_metadata_setuid
	ssh root@$(ios_installHost) chmod gu+s $(ios_deviceExecPath)
endif

endif

ios_fatExec := $(ios_targetBinPath)/$(iOS_metadata_exec)
$(ios_fatExec) : $(ios_execs)
	@mkdir -p $(@D)
	lipo -create $^ -output $@

.PHONY: ios-build
ios-build : $(ios_fatExec) $(ios_plist)

ifdef iOS_metadata_setuid

ios_setuidLauncher := $(ios_resourcePath)/$(iOS_metadata_exec)_

$(ios_setuidLauncher) :
	echo '#!/bin/bash' > $@
	echo 'dir=$$(dirname "$$0")' >> $@
	echo 'exec "$${dir}"/$(iOS_metadata_exec) "$$@"' >> $@
	chmod a+x $@

endif

ifdef ios_metadata_setuidPermissionHelper

ios_setuidPermissionHelperDir := $(IMAGINE_PATH)/tools/ios
ios_setuidPermissionHelper := $(ios_setuidPermissionHelperDir)/fixMobilePermission

$(ios_setuidPermissionHelper) :
	$(MAKE) -C $(@D) -f ios-armv6.mk

endif

.PHONY: ios-resources-install
ios-resources-install : $(ios_plist) $(ios_setuidLauncher) $(ios_setuidPermissionHelper)
	ssh root@$(ios_installHost) mkdir -p $(ios_deviceAppBundlePath)
	scp $(ios_resourcePath)/* root@$(ios_installHost):$(ios_deviceAppBundlePath)/
	scp $(ios_icons) root@$(ios_installHost):$(ios_deviceAppBundlePath)/
	ssh root@$(ios_installHost) chmod -R a+r $(ios_deviceAppBundlePath)
ifdef ios_metadata_setuidPermissionHelper
	ssh root@$(ios_installHost) rm -f $(ios_deviceAppBundlePath)/fixMobilePermission
	scp $(ios_setuidPermissionHelper) root@$(ios_installHost):$(ios_deviceAppBundlePath)/
	ssh root@$(ios_installHost) chmod a+x $(ios_deviceAppBundlePath)/fixMobilePermission
	ssh root@$(ios_installHost) chmod gu+s $(ios_deviceAppBundlePath)/fixMobilePermission
endif

.PHONY: ios-plist-install
ios-plist-install : $(ios_plist)
	scp $(ios_plist) root@$(ios_installHost):$(ios_deviceAppBundlePath)/

.PHONY: ios-install
ios-install : ios-build
	ssh root@$(ios_installHost) rm -f $(ios_deviceExecPath)
	scp $(ios_fatExec) root@$(ios_installHost):$(ios_deviceExecPath)
	ssh root@$(ios_installHost) chmod a+x $(ios_deviceExecPath)
ifdef iOS_metadata_setuid
	ssh root@$(ios_installHost) chmod gu+s $(ios_deviceExecPath)
endif

.PHONY: ios-install-only
ios-install-only :
	ssh root@$(ios_installHost) rm -f $(ios_deviceExecPath)
	scp $(ios_fatExec) root@$(ios_installHost):$(ios_deviceExecPath)
	ssh root@$(ios_installHost) chmod a+x $(ios_deviceExecPath)
ifdef iOS_metadata_setuid
	ssh root@$(ios_installHost) chmod gu+s $(ios_deviceExecPath)
endif

# metadata

$(ios_plistTxt) : $(projectPath)/metadata/conf.mk $(metadata_confDeps)
	@mkdir -p $(@D)
	bash $(IMAGINE_PATH)/tools/genIOSMeta.sh $(iOS_gen_metadata_args) $@
$(ios_plist) : $(ios_plistTxt)
	@mkdir -p $(@D)
	plutil -convert binary1 -o $@ $<
.PHONY: ios-metadata
ios-metadata : $(ios_plist)

# tar package

# Note: a version of tar with proper --transform support is needed for this rule (gnutar from MacPorts)
ios_tar := $(ios_targetPath)/$(iOS_metadata_bundleName)-$(iOS_metadata_version)-iOS.tar.gz
$(ios_tar) : # depends on $(ios_fatExec) $(ios_plist) $(ios_setuidLauncher) $(ios_setuidPermissionHelper)
	chmod a+x $(ios_fatExec)
ifdef iOS_metadata_setuid
	chmod gu+s $(ios_fatExec)
endif
ifdef ios_metadata_setuidPermissionHelper
	chmod a+x $(ios_setuidPermissionHelper)
	chmod gu+s $(ios_setuidPermissionHelper)
endif
	gnutar -cPhzf $@ $(ios_fatExec) $(ios_resourcePath)/* $(ios_icons)  $(ios_plist) $(ios_setuidPermissionHelper) \
	--transform='s,^$(ios_targetBinPath)/,$(ios_bundleDirectory)/,;s,^$(ios_resourcePath)/,$(ios_bundleDirectory)/,;s,^$(ios_iconPath)/,$(ios_bundleDirectory)/,;s,^$(ios_setuidPermissionHelperDir)/,$(ios_bundleDirectory)/,;s,^$(ios_targetPath)/,$(ios_bundleDirectory)/,'
.PHONY: ios-tar
ios-tar : $(ios_tar)

.PHONY: ios-clean-tar
ios-clean-tar:
	rm -f $(ios_tar)

.PHONY: ios-ready
ios-ready : $(ios_tar)
	cp $(ios_tar) $(IMAGINE_PATH)/../releases-bin/iOS

.PHONY: ios-check
ios-check :
	@echo "Checking compiled version of $(iOS_metadata_bundleName) $(iOS_metadata_version)"
	strings $(ios_fatExec) | grep " $(iOS_metadata_version)"

.PHONY: ios-clean
ios-clean: $(ios_cleanTargets)
	rm -f $(ios_fatExec)
