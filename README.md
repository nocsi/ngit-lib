# ngit-lib

ngit-lib is a repository for building Libssh2, Openssl, libgit2 and libcurl packaged together as an xcframework for iOS, MacCatalyst, watchOS and tvOS.

- Libssh2: [Website](http://www.libssh2.org) | [Documentation](http://www.libssh2.org/docs.html) | [Changelog](http://www.libssh2.org/changes.html)
- OpenSSL: [Website](http://www.openssl.org) | [Documentation](http://www.openssl.org/docs/) | [Changelog](http://www.openssl.org/news/)

## Requirements

- Xcode
- Xcode Command Line Tools

#### Optional Requirements

- git (required for automatically detection of latest version of Libssh2/OpenSSL)

## Tested with

- Xcode: 11.1
- iOS SDK: 13.0
- Libssh2: 1.9.0
- OpenSSL: 1.1.0c
- Architectures: arm64 arm64e x86_64

## How to build

1. make
2. make framework

## How to use

1. Drag n' Drop libssh2.xcframework into your project
2. Embed and sign the .xcframework in your project's target under "Frameworks, Libraries, and Embedded Content"
2. There is no step 3
