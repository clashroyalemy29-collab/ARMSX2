cmake_minimum_required(VERSION 3.20)
project(Probe C CXX Swift)
set(CMAKE_OSX_SYSROOT iphoneos)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 16.0)
add_library(probelib STATIC lib.c)
add_executable(ARMSX2iOS MACOSX_BUNDLE main.swift)
target_link_libraries(ARMSX2iOS PRIVATE probelib)
set_target_properties(ARMSX2iOS PROPERTIES
  XCODE_ATTRIBUTE_SWIFT_VERSION "6.0"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.0"
  XCODE_ATTRIBUTE_SDKROOT "iphoneos")
