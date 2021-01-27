#!/bin/sh

#  Automatic build script for libcurl
#  for iPhoneOS, iPhoneSimulator and MacCatalyst
#

# -u  Attempt to use undefined variable outputs error message, and forces an exit
set -u

# SCRIPT DEFAULTS

# Default version in case no version is specified
DEFAULTVERSION="7.66.0"

# Default (=full) set of architectures (libcurl <= 1.9.0) or targets (libssh2>= 1.1.0) to build
DEFAULTTARGETS="ios-sim-cross-x86_64 ios-sim-cross-i386 ios64-cross-arm64 ios-cross-armv7s ios-cross-armv7 tvos-sim-cross-x86_64 tvos64-cross-arm64"  # mac-catalyst-x86_64 is a valid target that is not in the DEFAULTTARGETS because it's incompatible with "ios-sim-cross-x86_64"

# Minimum iOS/tvOS SDK version to build for
IOS_MIN_SDK_VERSION="13.0"
TVOS_MIN_SDK_VERSION="9.0"
MACOSX_MIN_SDK_VERSION="10.15"

# Init optional env variables (use available variable or default to empty string)
CURL_OPTIONS="${CURL_OPTIONS:-}"
CONFIG_OPTIONS="${CONFIG_OPTIONS:-}"

echo_help()
{
  echo "Usage: $0 [options...]"
  echo "Generic options"
  echo "     --cleanup                     Clean up build directories (bin, include/libcurl, lib, src) before starting build"
  echo " -h, --help                        Print help (this message)"
  echo "     --ios-sdk=SDKVERSION          Override iOS SDK version"
  echo "     --macosx-sdk=SDKVERSION       Override MacOSX SDK version"
  echo "     --noparallel                  Disable running make with parallel jobs (make -j)"
  echo "     --tvos-sdk=SDKVERSION         Override tvOS SDK version"
  echo "     --disable-bitcode             Disable embedding Bitcode"
  echo " -v, --verbose                     Enable verbose logging"
  echo "     --verbose-on-error            Dump last 500 lines from log file if an error occurs (for Travis builds)"
  echo "     --version=VERSION             libcurl version to build (defaults to ${DEFAULTVERSION})"
  echo
  echo "Options for libSSH2 1.9.0 and higher ONLY"
  echo "     --targets=\"TARGET TARGET ...\" Space-separated list of build targets"
  echo "                                     Options: ${DEFAULTTARGETS} mac-catalyst-x86_64"
  echo
  echo "For custom configure options, set variable CONFIG_OPTIONS"
  echo "For custom cURL options, set variable CURL_OPTIONS"
  echo "  Example: CURL_OPTIONS=\"--proxy 192.168.1.1:8080\" ./build-libssl.sh"
}

spinner()
{
  local pid=$!
  local delay=0.75
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "  [%c]" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b"
  done

  wait $pid
  return $?
}

# Prepare target and source dir in build loop
prepare_target_source_dirs()
{
  OPENSSLDIR="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
  export TARGETDIR="${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
  mkdir -p "${TARGETDIR}"
  LOG="${TARGETDIR}/build-libcurl-${VERSION}.log"

  echo "Building libcurl-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}..."
  echo "  Logfile: ${LOG}"

  # Prepare source dir
  SOURCEDIR="${CURRENTPATH}/src/${PLATFORM}-${ARCH}"
  mkdir -p "${SOURCEDIR}"
  tar zxf "${CURRENTPATH}/${LIBCURL_ARCHIVE_FILE_NAME}" -C "${SOURCEDIR}"
  cd "${SOURCEDIR}/curl-${LIBCURL_ARCHIVE_BASE_NAME}"
}

# Check for error status
check_status()
{
  local STATUS=$1
  local COMMAND=$2

  if [ "${STATUS}" != 0 ]; then
    if [[ "${LOG_VERBOSE}" != "verbose"* ]]; then
      echo "Problem during ${COMMAND} - Please check ${LOG}"
    fi

    # Dump last 500 lines from log file for verbose-on-error
    if [ "${LOG_VERBOSE}" == "verbose-on-error" ]; then
      echo "Problem during ${COMMAND} - Dumping last 500 lines from log file"
      echo
      tail -n 500 "${LOG}"
    fi

    exit 1
  fi
}

# Run Configure in build loop
run_configure()
{
  echo "  Configure..."
  set +e
  echo $LOCAL_CONFIG_OPTIONS

  if [ "${LOG_VERBOSE}" == "verbose" ]; then
    ./configure ${LOCAL_CONFIG_OPTIONS} | tee "${LOG}"
  else
    ( ./configure ${LOCAL_CONFIG_OPTIONS} > "${LOG}" 2>&1 ) & spinner
  fi

  # Check for error status
  check_status $? "Configure"
}

# Run make in build loop
run_make()
{
  echo "  Make (using ${BUILD_THREADS} thread(s))..."

  if [ "${LOG_VERBOSE}" == "verbose" ]; then
    make -j "${BUILD_THREADS}" | tee -a "${LOG}"
  else
    (make -j "${BUILD_THREADS}" >> "${LOG}" 2>&1) & spinner
  fi

  # Check for error status
  check_status $? "make"
}

# Cleanup and bookkeeping at end of build loop
finish_build_loop()
{
  # Add references to library files to relevant arrays
  if [[ "${PLATFORM}" == AppleTV* ]]; then
    LIBCURL_TVOS+=("${TARGETDIR}/lib/libcurl.a")
    LIBCURLCONF_SUFFIX="tvos_${ARCH}"
  else
    LIBCURL_IOS+=("${TARGETDIR}/lib/libcurl.a")
    if [[ "${PLATFORM}" != MacOSX* ]]; then
      LIBCURLCONF_SUFFIX="ios_${ARCH}"
    else
      LIBCURLCONF_SUFFIX="catalyst_${ARCH}"
    fi
  fi

  # Copy libsshconf.h to bin directory and add to array
  #LIBCURLCONF="libsshconf_${LIBCURLCONF_SUFFIX}.h"
  #cp "${TARGETDIR}/include/libcurl/libsshconf.h" "${CURRENTPATH}/bin/${LIBCURLCONF}"
  #LIBCURLCONF_ALL+=("${LIBCURLCONF}")
  echo $SOURCEDIR
  rm -rf "${TARGETDIR}/include/libcurl"
  mkdir -p "${TARGETDIR}/include/libcurl"
  cp -RL "${SOURCEDIR}/curl-${LIBCURL_ARCHIVE_BASE_NAME}/include/" "${TARGETDIR}/include/libcurl/"

  # Keep reference to first build target for include file
  if [ -z "${INCLUDE_DIR}" ]; then
    INCLUDE_DIR="${TARGETDIR}/include/libcurl"
  fi

  # Return to ${CURRENTPATH} and remove source dir
  cd "${CURRENTPATH}"
  rm -r "${SOURCEDIR}"
}

# Init optional command line vars
ARCHS=""
CLEANUP=""
CONFIG_DISABLE_BITCODE=""
CONFIG_NO_DEPRECATED=""
IOS_SDKVERSION=""
MACOSX_SDKVERSION=""
LOG_VERBOSE=""
PARALLEL=""
TARGETS=""
TVOS_SDKVERSION=""
VERSION=""

# Process command line arguments
for i in "$@"
do
case $i in
  --archs=*)
    ARCHS="${i#*=}"
    shift
    ;;
  --cleanup)
    CLEANUP="true"
    ;;
  --deprecated)
    CONFIG_NO_DEPRECATED="false"
    ;;
  --disable-bitcode)
    CONFIG_DISABLE_BITCODE="true"
    ;;
  -h|--help)
    echo_help
    exit
    ;;
  --ios-sdk=*)
    IOS_SDKVERSION="${i#*=}"
    shift
    ;;
  --macosx-sdk=*)
    MACOSX_SDKVERSION="${i#*=}"
    shift
    ;;
  --noparallel)
    PARALLEL="false"
    ;;
  --targets=*)
    TARGETS="${i#*=}"
    shift
    ;;
  --tvos-sdk=*)
    TVOS_SDKVERSION="${i#*=}"
    shift
    ;;
  -v|--verbose)
    LOG_VERBOSE="verbose"
    ;;
  --verbose-on-error)
    LOG_VERBOSE="verbose-on-error"
    ;;
  --version=*)
    VERSION="${i#*=}"
    shift
    ;;
  *)
    echo "Unknown argument: ${i}"
    ;;
esac
done

# Specific version: Verify version number format. Expected: dot notation
if [[ -n "${VERSION}" && ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Unknown version number format. Examples: 1.0.2, 1.0.2h"
  exit 1

# Script default
elif [ -z "${VERSION}" ]; then
  VERSION="${DEFAULTVERSION}"
fi

# Set default for TARGETS if not specified
if [ ! -n "${TARGETS}" ]; then
  TARGETS="${DEFAULTTARGETS}"
fi

# Determine SDK versions
if [ ! -n "${IOS_SDKVERSION}" ]; then
  IOS_SDKVERSION=$(xcrun -sdk iphoneos --show-sdk-version)
fi
if [ ! -n "${MACOSX_SDKVERSION}" ]; then
  MACOSX_SDKVERSION=$(xcrun -sdk macosx --show-sdk-version)
fi
if [ ! -n "${TVOS_SDKVERSION}" ]; then
  TVOS_SDKVERSION=$(xcrun -sdk appletvos --show-sdk-version)
fi

# Determine number of cores for (parallel) build
BUILD_THREADS=1
if [ "${PARALLEL}" != "false" ]; then
  BUILD_THREADS=$(sysctl hw.ncpu | awk '{print $2}')
fi

# Determine script directory
SCRIPTDIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# Write files relative to current location and validate directory
CURRENTPATH=$(pwd)
case "${CURRENTPATH}" in
  *\ * )
    echo "Your path contains whitespaces, which is not supported by 'make install'."
    exit 1
  ;;
esac
cd "${CURRENTPATH}"

# Validate Xcode Developer path
DEVELOPER=$(xcode-select -print-path)
if [ ! -d "${DEVELOPER}" ]; then
  echo "Xcode path is not set correctly ${DEVELOPER} does not exist"
  echo "run"
  echo "sudo xcode-select -switch <Xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case "${DEVELOPER}" in
  *\ * )
    echo "Your Xcode path contains whitespaces, which is not supported."
    exit 1
  ;;
esac

# Show build options
echo
echo "Build options"
echo "  libcurl version: ${VERSION}"
echo "  Targets: ${TARGETS}"
echo "  iOS SDK: ${IOS_SDKVERSION}"
echo "  tvOS SDK: ${TVOS_SDKVERSION}"
if [ "${CONFIG_DISABLE_BITCODE}" == "true" ]; then
  echo "  Bitcode embedding disabled"
fi
echo "  Number of make threads: ${BUILD_THREADS}"
if [ -n "${CONFIG_OPTIONS}" ]; then
  echo "  Configure options: ${CONFIG_OPTIONS}"
fi
echo "  Build location: ${CURRENTPATH}"
echo

# Download libcurl when not present
LIBCURL_ARCHIVE_BASE_NAME="${VERSION}"
LIBCURL_ARCHIVE_FILE_NAME="curl-${LIBCURL_ARCHIVE_BASE_NAME}.tar.gz"
if [ ! -e ${LIBCURL_ARCHIVE_FILE_NAME} ]; then
  echo "Downloading ${LIBCURL_ARCHIVE_FILE_NAME}..."
  LIBCURL_ARCHIVE_URL="https://curl.haxx.se/download/${LIBCURL_ARCHIVE_FILE_NAME}"

  # Check whether file exists here (this is the location of the latest version for each branch)
  # -s be silent, -f return non-zero exit status on failure, -I get header (do not download)
  curl ${CURL_OPTIONS} -sfIL "${LIBCURL_ARCHIVE_URL}" > /dev/null

  # Both attempts failed, so report the error
  if [ $? -ne 0 ]; then
    echo "An error occurred trying to find libcurl ${VERSION} on ${LIBCURL_ARCHIVE_URL}"
    echo "Please verify that the version you are trying to build exists, check cURL's error message and/or your network connection."
    exit 1
  fi

  # Archive was found, so proceed with download.
  # -O Use server-specified filename for download
  curl ${CURL_OPTIONS} -L "${LIBCURL_ARCHIVE_URL}" -o ${LIBCURL_ARCHIVE_FILE_NAME}

else
  echo "Using ${LIBCURL_ARCHIVE_FILE_NAME}"
fi

# Set reference to custom configuration (libcurl 1.9.0)
export LIBCURL_LOCAL_CONFIG_DIR="${SCRIPTDIR}/config"

# -e  Abort script at first error, when a command exits with non-zero status (except in until or while loops, if-tests, list constructs)
# -o pipefail  Causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value
set -eo pipefail

# Clean up target directories if requested and present
if [ "${CLEANUP}" == "true" ]; then
  if [ -d "${CURRENTPATH}/bin" ]; then
    rm -r "${CURRENTPATH}/bin"
  fi
  if [ -d "${CURRENTPATH}/include/libcurl" ]; then
    rm -r "${CURRENTPATH}/include/libcurl"
    rm -f "${CURRENTPATH}/include/*.h"
  fi
  if [ -d "${CURRENTPATH}/lib" ]; then
    rm -r "${CURRENTPATH}/lib"
  fi
  if [ -d "${CURRENTPATH}/src" ]; then
    rm -r "${CURRENTPATH}/src"
  fi
fi

# (Re-)create target directories
mkdir -p "${CURRENTPATH}/bin"
mkdir -p "${CURRENTPATH}/lib"
mkdir -p "${CURRENTPATH}/src"

# Init vars for library references
INCLUDE_DIR=""
LIBCURLCONF_ALL=()
LIBCURL_IOS=()
LIBCURL_TVOS=()

# Run relevant build loop (archs = 1.0 style, targets = 1.1 style)
source "${SCRIPTDIR}/scripts/build-loop-targets.sh"

#Build iOS library if selected for build
if [ ${#LIBCURL_IOS[@]} -gt 0 ]; then
  echo "Build library for iOS..."
  lipo -create ${LIBCURL_IOS[@]} -output "${CURRENTPATH}/lib/libcurl.a"
  echo "\n=====>iOS SSL and Crypto lib files:"
  echo "${CURRENTPATH}/lib/libcurl.a"
fi

# Build tvOS library if selected for build
if [ ${#LIBCURL_TVOS[@]} -gt 0 ]; then
  echo "Build library for tvOS..."
  lipo -create ${LIBCURL_TVOS[@]} -output "${CURRENTPATH}/lib/libcurl-tvOS.a"
  echo "\n=====>tvOS SSL and Crypto lib files:"
  echo "${CURRENTPATH}/lib/libcurl-tvOS.a"
fi

# Copy include directory
cp -R "${INCLUDE_DIR}" "${CURRENTPATH}/include"

echo "\n=====>Include directory:"
echo "${CURRENTPATH}/include/libcurl"

# Only create intermediate file when building for multiple targets
# For a single target, libsshconf.h is still present in $INCLUDE_DIR (and has just been copied to the target include dir)
if [ ${#LIBCURLCONF_ALL[@]} -gt 1 ]; then

  # Prepare intermediate header file
  # This overwrites libsshconf.h that was copied from $INCLUDE_DIR
  LIBCURLCONF_INTERMEDIATE="${CURRENTPATH}/include/libcurl/libcurlconf.h"
  cp "${CURRENTPATH}/include/libcurlconf-template.h" "${LIBCURLCONF_INTERMEDIATE}"

  # Loop all header files
  LOOPCOUNT=0
  for LIBCURLCONF_CURRENT in "${LIBCURLCONF_ALL[@]}" ; do

    # Copy specific libsshconf file to include dir
    cp "${CURRENTPATH}/bin/${LIBCURLCONF_CURRENT}" "${CURRENTPATH}/include/libcurl"

    # Determine define condition
    case "${LIBCURLCONF_CURRENT}" in
      *_ios_x86_64.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64"
      ;;
      *_ios_i386.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_X86"
      ;;
      *_ios_arm64.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64"
      ;;
      *_ios_armv7s.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM && defined(__ARM_ARCH_7S__)"
      ;;
      *_ios_armv7.h)
        DEFINE_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM && !defined(__ARM_ARCH_7S__)"
      ;;
      *_catalyst_x86_64.h)
        DEFINE_CONDITION="(TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_X86_64"
      ;;
      *_catalyst_arm64.h)
        DEFINE_CONDITION="(TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_ARM64"
      ;;
      *_tvos_x86_64.h)
        DEFINE_CONDITION="TARGET_OS_TV && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64"
      ;;
      *_tvos_arm64.h)
        DEFINE_CONDITION="TARGET_OS_TV && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64"
      ;;
      *)
        # Don't run into unexpected cases by setting the default condition to false
        DEFINE_CONDITION="0"
      ;;
    esac

    # Determine loopcount; start with if and continue with elif
    LOOPCOUNT=$((LOOPCOUNT + 1))
    if [ ${LOOPCOUNT} -eq 1 ]; then
      echo "#if ${DEFINE_CONDITION}" >> "${LIBCURLCONF_INTERMEDIATE}"
    else
      echo "#elif ${DEFINE_CONDITION}" >> "${LIBCURLCONF_INTERMEDIATE}"
    fi

    # Add include
    echo "# include <libcurl/${LIBCURLCONF_CURRENT}>" >> "${LIBCURLCONF_INTERMEDIATE}"
  done

  # Finish
  echo "#else" >> "${LIBCURLCONF_INTERMEDIATE}"
  echo '# error Unable to determine target or target not included in libcurl build' >> "${LIBCURLCONF_INTERMEDIATE}"
  echo "#endif" >> "${LIBCURLCONF_INTERMEDIATE}"
fi

echo "Done."
