#!/bin/sh

FWNAME=Libssh2
DEFAULTTARGETS="iOS-arm64 macOS-x86_64 simulator-x86_64"  # mac-catalyst-x86_64 is a valid target that is not in the DEFAULTTARGETS because it's incompatible with "ios-sim-cross-x86_64"

echo_help()
{
  echo "Usage: $0 [options...]"
  echo "Generic options"
  echo "     --dynamic                     Clean up build directories (bin, include/libssh2, lib, src) before starting build"
  echo " -h, --help                        Print help (this message)"
  echo "     --ios-sdk=SDKVERSION          Override iOS SDK version"
  echo "     --macosx-sdk=SDKVERSION       Override MacOSX SDK version"
  echo "     --tvos-sdk=SDKVERSION         Override tvOS SDK version"
  echo " -v, --verbose                     Enable verbose logging"
  echo "     --verbose-on-error            Dump last 500 lines from log file if an error occurs (for Travis builds)"
  echo "     --version=VERSION             libssh2 version to build (defaults to ${DEFAULTVERSION})"
  echo
  echo "Options for libSSH2 1.9.0 and higher ONLY"
  echo "     --targets=\"TARGET TARGET ...\" Space-separated list of build targets"
  echo "                                     Options: ${DEFAULTTARGETS} mac-catalyst-x86_64"
}

if [ ! -d lib ]; then
    echo "Please run build-libssh.sh first!"
    exit 1
fi

# Init optional command line vars
DYNAMIC=""
IOS_SDKVERSION=""
MACOSX_SDKVERSION=""
LOG_VERBOSE=""
PARALLEL=""
TARGETS=""
TVOS_SDKVERSION=""

# Process command line arguments
for i in "$@"
do
case $i in
  --dynamic)
    DYNAMIC="true"
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

if [ ! -n "${TARGETS}" ]; then
  TARGETS="${DEFAULTTARGETS}"
fi

for TARGET in ${TARGETS}
do
  TARGET_FRAMEWORK=frameworks/${TARGET}/${FWNAME}
  # Extract ARCH from TARGET (part after last dash)
  ARCH=$(echo "${TARGET}" | sed -E 's|^.*\-([^\-]+)$|\1|g')

  if [ -d $TARGET_FRAMEWORK.framework ]; then
  	echo "Removing previous ${TARGET_FRAMEWORK}.framework copy"
  	rm -rf $TARGET_FRAMEWORK.framework
  fi

  if [ "$DYNAMIC" == "true" ]; then
  	LIBTOOL_FLAGS="-dynamic -undefined dynamic_lookup -ios_version_min 8.0"
  else
  	LIBTOOL_FLAGS="-static"
  fi

  echo "Creating $TARGET_FRAMEWORK.framework"
  mkdir -p $TARGET_FRAMEWORK.framework/Headers
  libtool -no_warning_for_no_symbols $LIBTOOL_FLAGS -arch_only $ARCH -o $TARGET_FRAMEWORK.framework/$FWNAME lib/libcrypto.a lib/libssl.a lib/libssh2.a
  cp -r include/$FWNAME/* $TARGET_FRAMEWORK.framework/Headers/

  DIR="$(cd "$(dirname "$0")" && pwd)"
  cp $DIR/"LibSSH-for-iOS/LibSSH-for-iOS-Info.plist" $TARGET_FRAMEWORK.framework/Info.plist
  echo "Created $TARGET_FRAMEWORK.framework"
  echo $TARGET_FRAMEWORK.framework/$FWNAME

  check_bitcode=`otool -arch $ARCH -l $TARGET_FRAMEWORK.framework/$FWNAME | grep __bitcode`
  if [ -z "$check_bitcode" ]
  then
  	echo "INFO: $TARGET_FRAMEWORK.framework doesn't contain Bitcode"
  else
  	echo "INFO: $TARGET_FRAMEWORK.framework contains Bitcode"
  fi
done
