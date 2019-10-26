#
#  Makefile
#  libssh2 for Apple stuff
#
#

DEFAULTTARGETS="ios64-cross-arm64 mac-catalyst-x86_64"
DEFAULTFWTARGETS="iOS-arm64 macOS-x86_64 simulator-x86_64"
OPENSSLVER="1.1.0f"
LIBSSHVER="1.9.0"

CUR_DIR = $(CURDIR)
TARGETDIR := target

BUILD_OPENSSL := $(realpath $(CUR_DIR)/src/openssl/build-libssl.sh)
BUILD_LIBSSH := $(realpath $(CUR_DIR)/src/libssh2/build-libssh.sh)
CREATE_FRAMEWORK := $(realpath $(CUR_DIR)/src/libssh2/create-libssh-framework.sh)

STATIC_IOS := $(TARGETDIR)/libssh2_iOS-arm64.framework/libssh2.a
STATIC_MACOS := $(TARGETDIR)/libssh2_macOS-x86_64.framework/libssh2.a
STATIC_SIM := $(TARGETDIR)/libssh2_simulator-x86_64.framework/libssh2.a

FRAMEWORK_IOS := $(TARGETDIR)/frameworks/iOS-arm64/Libssh2.framework
FRAMEWORK_MACOS := $(TARGETDIR)/frameworks/macOS-x86_64/Libssh2.framework
FRAMEWORK_SIM := $(TARGETDIR)/frameworks/simulator-x86_64/Libssh2.framework


OUTPUT_DIR := framework

default: clean build

build: build_ios build_macos build_sim

build_ios:
	( cd ./$(TARGETDIR) && \
	$(BUILD_OPENSSL) --targets="ios64-cross-arm64" --ec-nistp-64-gcc-128 --version=$(OPENSSLVER) && \
	$(BUILD_LIBSSH) --targets="ios64-cross-arm64" --version=$(LIBSSHVER) && \
	$(CREATE_FRAMEWORK) --targets="iOS-arm64" )

build_macos:
	( cd ./$(TARGETDIR) && \
	$(BUILD_OPENSSL) --targets="mac-catalyst-x86_64" --ec-nistp-64-gcc-128 --version=$(OPENSSLVER) && \
	$(BUILD_LIBSSH) --targets="mac-catalyst-x86_64" --version=$(LIBSSHVER) && \
	$(CREATE_FRAMEWORK) --targets="macOS-x86_64" )

build_sim:
	( cd ./$(TARGETDIR) && \
	$(BUILD_OPENSSL) --targets="ios-sim-cross-x86_64" --ec-nistp-64-gcc-128 --version=$(OPENSSLVER) && \
	$(BUILD_LIBSSH) --targets="ios-sim-cross-x86_64" --version=$(LIBSSHVER) && \
	$(CREATE_FRAMEWORK) --targets="simulator-x86_64" )

framework:
	xcodebuild -create-xcframework \
		-framework ${FRAMEWORK_IOS} \
		-framework ${FRAMEWORK_MACOS} \
		-framework ${FRAMEWORK_SIM} \
		-output libssh2.xcframework

framework_static:
	xcodebuild -create-xcframework \
		-library ${STATIC_IOS} \
		-headers ${STATIC_IOS}/Headers \
		-library ${STATIC_MACOS} \
		-library ${STATIC_SIM} \
		-output libssh2.xcframework

codesign:
	codesign_identity=$(security find-identity -v -p codesigning | grep A33F2F2 | grep -o -E '\w{40}' | head -n 1)
	codesign -f --deep -s  "$codesign_identity" libssh2.xcframework

clean:
	@echo " Cleaning...";
	@echo " $(RM) -r $(LIBDIR) $(SRCDIR)"; $(RM) -r $(LIBDIR) $(SRCDIR)
	@echo " Cleaning Frameworks...";
	@echo " $(RM) -r $(TARGETDIR)/*.framework"; $(RM) -r $(TARGETDIR)/*.framework
	@echo " $(RM) -r $(TARGETDIR)/frameworks/*.framework"; $(RM) -r $(TARGETDIR)/frameworks/*.framework

.PHONY: clean
