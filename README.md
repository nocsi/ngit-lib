# issh2

iSSH2 is a bash script for compiling Libssh2 (and OpenSSL) for iOS, macOS, watchOS and tvOS.
issh2 is a repository for building OpenSSL & Libssh2 as an xcframework to support iOS, MacCatalyst, watchOS and tvOS.

- Libssh2: [Website](http://www.libssh2.org) | [Documentation](http://www.libssh2.org/docs.html) | [Changelog](http://www.libssh2.org/changes.html)
- OpenSSL: [Website](http://www.openssl.org) | [Documentation](http://www.openssl.org/docs/) | [Changelog](http://www.openssl.org/news/)

## Requirements

- Xcode
- Xcode Command Line Tools

#### Optional Requirements

- git (required for automatically detection of latest version of Libssh2/OpenSSL)

## Tested with

- Xcode: 10.2.1
- iOS SDK: 12.2
- Libssh2: 1.9.0
- OpenSSL: 1.1.0c
- Architectures: arm64 arm64e x86_64

## How to use

1. make
2. make framework
