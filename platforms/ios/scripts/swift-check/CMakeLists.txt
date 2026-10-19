# Compiles only the SwiftUI sources of the iOS app (no C/C++ core) so availability and
# concurrency errors show up in minutes instead of the full build's ~30. The bridging
# header imports nothing but Foundation and UIKit, so no core headers are needed.
cmake_minimum_required(VERSION 3.20)
project(SwiftCheck C Swift)
set(CMAKE_OSX_SYSROOT iphoneos)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 16.0)
set(APP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../app/src/main")
file(GLOB_RECURSE SWIFT_SOURCES "${APP_ROOT}/swift/*.swift")
file(WRITE "${CMAKE_BINARY_DIR}/stub.c" "int swift_check_stub(void) { return 0; }\n")
add_executable(ARMSX2iOS MACOSX_BUNDLE ${SWIFT_SOURCES} "${CMAKE_BINARY_DIR}/stub.c")
set_target_properties(ARMSX2iOS PROPERTIES
  XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.0"
  XCODE_ATTRIBUTE_SDKROOT "iphoneos"
  XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${APP_ROOT}/cpp/ARMSX2-Bridging-Header.h"
  XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES "YES"
  XCODE_ATTRIBUTE_SWIFT_COMPILATION_MODE "singlefile"
  XCODE_ATTRIBUTE_SWIFT_OPTIMIZATION_LEVEL "-Onone"
  XCODE_ATTRIBUTE_SWIFT_STRICT_CONCURRENCY "complete")
