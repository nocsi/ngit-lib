#
#  Makefile
#  libgit2 for Apple stuff
#
#

DEFAULTTARGETS="ios64-cross mac-catalyst-x86_64"
DEFAULTFWTARGETS="iOS-arm64 macOS-x86_64 simulator-x86_64"
OPENSSLVER="1.1.1d"
LIBSSHVER="1.9.0"
LIBCURLVER="7.66.0"
LIBGITVER="0.28.3"

CUR_DIR = $(CURDIR)
TARGETDIR := target

BUILD_OPENSSL := $(realpath $(CUR_DIR)/src/openssl/build-libssl.sh)
BUILD_LIBSSH := $(realpath $(CUR_DIR)/src/libssh2/build-libssh.sh)
BUILD_LIBCURL := $(realpath $(CUR_DIR)/src/libcurl/build-libcurl.sh)
BUILD_LIBGIT := $(realpath $(CUR_DIR)/src/libgit2/build-libgit.sh)
CREATE_FRAMEWORK := $(realpath $(CUR_DIR)/create-ngit-framework.sh)

STATIC_IOS := $(TARGETDIR)/frameworks/iOS-arm64/libgit2.framework/libgit2.a
STATIC_MACOS := $(TARGETDIR)/frameworks/macOS-x86_64/libgit2.framework/libgit2.a
STATIC_SIM := $(TARGETDIR)/frameworks/simulator-x86_64/libgit2.framework/libgit2.a

FRAMEWORK_IOS := $(TARGETDIR)/frameworks/iOS-arm64/libgit2.framework
FRAMEWORK_MACOS := $(TARGETDIR)/frameworks/macOS-x86_64/libgit2.framework
FRAMEWORK_SIM := $(TARGETDIR)/frameworks/simulator-x86_64/libgit2.framework
FRAMEWORK_HEADERS := $(TARGETDIR)/frameworks/iOS-arm64/libgit2.framework/Headers

OUTPUT_DIR := framework

default: clean build

build: build_ios build_macos build_sim

build_ios:
	( cd ./$(TARGETDIR) && \
	$(BUILD_OPENSSL) --targets="ios64-cross-arm64" --ec-nistp-64-gcc-128 --version=1.1.0f && \
	$(BUILD_LIBSSH) --targets="ios64-cross-arm64" --version=$(LIBSSHVER) && \
	$(BUILD_LIBCURL) --targets="ios64-cross-arm64" --version=$(LIBCURLVER) && \
  $(BUILD_LIBGIT) --targets="ios64-cross-arm64" --version=$(LIBGITVER) --verbose && \
	$(CREATE_FRAMEWORK) --targets="iOS-arm64" )

build_macos:
	( cd ./$(TARGETDIR) && \
	$(BUILD_OPENSSL) --targets="mac-catalyst-x86_64" --ec-nistp-64-gcc-128 --version=1.1.0f && \
	$(BUILD_LIBSSH) --targets="mac-catalyst-x86_64" --version=$(LIBSSHVER) && \
	$(BUILD_LIBCURL) --targets="mac-catalyst-x86_64" --version=$(LIBCURLVER) && \
	$(BUILD_LIBGIT) --targets="mac-catalyst-x86_64" --version=$(LIBGITVER) --verbose && \
	$(CREATE_FRAMEWORK) --targets="macOS-x86_64" )

build_sim:
	( cd ./$(TARGETDIR) && \
	$(BUILD_OPENSSL) --targets="ios-sim-cross-x86_64" --ec-nistp-64-gcc-128 --version=1.1.0f && \
	$(BUILD_LIBSSH) --targets="ios-sim-cross-x86_64" --version=$(LIBSSHVER) && \
	$(BUILD_LIBCURL) --targets="ios-sim-cross-x86_64" --version=$(LIBCURLVER) && \
	$(BUILD_LIBGIT) --targets="ios-sim-cross-x86_64" --version=$(LIBGITVER) --verbose && \
	$(CREATE_FRAMEWORK) --targets="simulator-x86_64" )

framework:
	xcodebuild -create-xcframework \
		-framework ${FRAMEWORK_IOS} \
		-framework ${FRAMEWORK_MACOS} \
		-framework ${FRAMEWORK_SIM} \
		-output libgit2.xcframework

framework_static:
	xcodebuild -create-xcframework \
		-library ${STATIC_IOS} \
		-headers ${FRAMEWORK_HEADERS} \
		-library ${STATIC_MACOS} \
		-headers ${FRAMEWORK_HEADERS} \
		-library ${STATIC_SIM} \
		-headers ${FRAMEWORK_HEADERS} \
		-output libgit2.xcframework

codesign:
	codesign_identity=$(security find-identity -v -p codesigning | grep A33F2F2 | grep -o -E '\w{40}' | head -n 1)
	codesign -f --deep -s 769B34C9C0E7AA7E0B0D60FF33C9F6F565288DBC libgit2.xcframework

clean:
	@echo " Cleaning...";
	@echo " $(RM) -r $(LIBDIR) $(SRCDIR)"; $(RM) -r $(LIBDIR) $(SRCDIR)
	@echo " Cleaning Frameworks...";
	@echo " $(RM) -r $(TARGETDIR)/*.framework"; $(RM) -r $(TARGETDIR)/*.framework
	@echo " $(RM) -r $(TARGETDIR)/frameworks/*.framework"; $(RM) -r $(TARGETDIR)/frameworks/*.framework

.PHONY: clean
