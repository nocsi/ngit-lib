#!/bin/sh

#  Automatic build script for libssl and libcrypto
#  for iPhoneOS, iPhoneSimulator and macCatalyst

for TARGET in ${TARGETS}
do
  # Determine relevant SDK version
  if [[ "${TARGET}" == tvos* ]]; then
    SDKVERSION="${TVOS_SDKVERSION}"
  elif [[ "${TARGET}" == "mac-catalyst"* ]]; then
    SDKVERSION="${MACOSX_SDKVERSION}"
  else
    SDKVERSION="${IOS_SDKVERSION}"
  fi

  # These variables are used in the configuration file
  export SDKVERSION
  export IOS_MIN_SDK_VERSION
  export TVOS_MIN_SDK_VERSION
  export CONFIG_DISABLE_BITCODE

  # Determine platform
  if [[ "${TARGET}" == "ios-sim-cross-"* ]]; then
    PLATFORM="iPhoneSimulator"
  elif [[ "${TARGET}" == "tvos-sim-cross-"* ]]; then
    PLATFORM="AppleTVSimulator"
  elif [[ "${TARGET}" == "tvos64-cross-"* ]]; then
    PLATFORM="AppleTVOS"
  elif [[ "${TARGET}" == "mac-catalyst-"* ]]; then
    PLATFORM="MacOSX"
  else
    PLATFORM="iPhoneOS"
  fi

  # Extract ARCH from TARGET (part after last dash)
  ARCH=$(echo "${TARGET}" | sed -E 's|^.*\-([^\-]+)$|\1|g')

  if [[ "$ARCH" == arm64* ]]; then
    HOST="aarch64-apple-darwin"
  else
    HOST="$ARCH-apple-darwin"
  fi 

  # Cross compile references, see Configurations/10-main.conf
  export CROSS_COMPILE="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/"
  export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
  export SDKROOT="${CROSS_TOP}/SDKs/${CROSS_SDK}"

  # Prepare TARGETDIR and SOURCEDIR
  prepare_target_source_dirs

  ## Determine config options
  # Add build target, --prefix and prevent async (references to getcontext(),
  # setcontext() and makecontext() result in App Store rejections) and creation
  # of shared libraruuuies (default since 1.1.0)
  if [[ "${PLATFORM}" == "MacOSX" ]]; then
    export CFLAGS="-arch $ARCH -pipe -no-cpp-precomp -fPIE -isysroot $SDKROOT --target=x86_64-apple-ios13.0-macabi -miphoneos-version-min=13.0 -fembed-bitcode"
    export CPPFLAGS="-arch $ARCH -pipe -no-cpp-precomp -fPIE -isysroot $SDKROOT --target=x86_64-apple-ios13.0-macabi -miphoneos-version-min=13.0 -fembed-bitcode"
    export LOCAL_CONFIG_OPTIONS=""
  else
    export CFLAGS="-arch $ARCH -pipe -no-cpp-precomp -fPIE -isysroot $SDKROOT -mios-version-min=13.0 -fembed-bitcode"
    export CPPFLAGS="-arch $ARCH -pipe -no-cpp-precomp -fPIE -isysroot $SDKROOT -mios-version-min=13.0 -fembed-bitcode"
    #export LOCAL_CONFIG_OPTIONS="-DCMAKE_OSX_SYSROOT=${SDKROOT}"
    export LOCAL_CONFIG_OPTIONS=""
  fi
  if [[ "${ARCH}" != "x86_64" ]]
  then
    LOCAL_CONFIG_OPTIONS="-DCMAKE_OSX_SYSROOT=${SDKROOT}"
  fi
  export PKG_CONFIG_PATH="{$TARGETDIR}/lib/pkgconfig/"
  export LOCAL_CONFIG_OPTIONS="-DLIB_INSTALL_DIR:STRING="${TARGETDIR}/lib" -DINCLUDE_INSTALL_DIR:STRING="${TARGETDIR}/include" -DUSE_ICONV:BOOL=OFF -DOPENSSL_ROOT_DIR=${OPENSSLDIR} -DOPENSSL_INCLUDE_DIR=${OPENSSLDIR}/include -DOPENSSL_SSL_LIBRARY=${OPENSSLDIR}/lib/libssl.a -DOPENSSL_CRYPTO_LIBRARY=${OPENSSLDIR}/lib/libcrypto.a -DCMAKE_INSTALL_PREFIX="${TARGETDIR}/" -DCMAKE_C_COMPILER_WORKS:BOOL=ON -DBUILD_SHARED_LIBS:BOOL=OFF -DBUILD_CLAR:BOOL=OFF -DHAVE_FUTIMENS:BOOL=OFF -DUSE_HTTPS=OpenSSL -DLIBSSH2_FOUND=TRUE -DLIBSSH2_INCLUDE_DIRS="${TARGETDIR}/include" -DLIBSSH2_LIBRARY_DIRS="${TARGETDIR}/lib" -DHAVE_LIBSSH2_MEMORY_CREDENTIALS:BOOL=ON -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH:BOOL=ON -DTHREADSAFE:BOOL=ON -DCMAKE_OSX_ARCHITECTURES:STRING="${ARCH}" $LOCAL_CONFIG_OPTIONS"

  CLANG="/usr/bin/xcrun clang"
  export CC="$CLANG"
  export CPP="$CLANG -E"

  # Run Configure
  run_configure

  # Run make
  run_make

  # Remove source dir, add references to library files to relevant arrays
  # Keep reference to first build target for include file
  finish_build_loop
done
