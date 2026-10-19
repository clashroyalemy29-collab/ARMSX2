#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the Swift Package Manager dependencies the SwiftUI layer needs to the
# CMake-generated Xcode project.
#
# CMake's Xcode generator cannot express Swift packages, and the SwiftUI sources
# import `Perception` (pointfreeco/swift-perception), the back-port of the iOS 17
# Observation framework that lets the app deploy to iOS 16. This script runs right
# after CMake generates the project and records the package reference and the
# product dependency in project.pbxproj, so `xcodebuild` resolves it on its own.
#
# Usage: add-swift-packages.rb <path/to/ARMSX2iOS.xcodeproj> [target-name]
#
# The script is idempotent: running it twice leaves the project unchanged.

begin
  require 'xcodeproj'
rescue LoadError
  warn 'error: the xcodeproj Ruby gem is required (gem install xcodeproj --user-install).'
  exit 1
end

# One entry per package. Pinned to an exact release so builds are reproducible;
# bump deliberately. 2.0.11 is the newest release with swift-tools-version 6.0
# (2.0.12 asks for 6.4) and allows swift-syntax up to 605.
PACKAGES = [
  {
    url: 'https://github.com/pointfreeco/swift-perception',
    version: '2.0.11',
    products: ['Perception']
  }
].freeze

project_path = ARGV[0]
target_name = ARGV[1] || 'ARMSX2iOS'

if project_path.nil? || !File.directory?(project_path)
  warn "usage: #{File.basename($PROGRAM_NAME)} <project.xcodeproj> [target]"
  exit 1
end

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  warn "error: target '#{target_name}' not found in #{project_path}"
  exit 1
end

PACKAGES.each do |package|
  reference = project.root_object.package_references.find do |ref|
    ref.respond_to?(:repositoryURL) && ref.repositoryURL == package[:url]
  end

  if reference.nil?
    reference = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    reference.repositoryURL = package[:url]
    reference.requirement = { 'kind' => 'exactVersion', 'version' => package[:version] }
    project.root_object.package_references << reference
  end

  package[:products].each do |product|
    next if target.package_product_dependencies.any? { |dep| dep.product_name == product }

    dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dependency.product_name = product
    dependency.package = reference
    target.package_product_dependencies << dependency

    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dependency
    target.frameworks_build_phase.files << build_file
  end
end

project.save

# CMake's Xcode generator writes a project-level SYMROOT (and OBJROOT). Xcode treats
# that as "legacy build locations" and refuses to resolve Swift packages:
#   "Packages are not supported when using legacy build locations".
# Removing just those keys fixes it. The products folder is pinned again from the
# command line (build-ios-ipa.sh passes SYMROOT="$BUILD_DIR"), so it still equals the
# CONFIGURATION_BUILD_DIR CMake wrote and the absolute library paths CMake links
# against stay valid. Verified with scripts/spm-probe (see ios_spm_probe.yml).
pbxproj = File.join(project_path, 'project.pbxproj')
text = File.read(pbxproj)
stripped = text.gsub(/^[ \t]*(?:SYMROOT|OBJROOT) = [^;\n]*;\n/, '')
if stripped != text
  File.write(pbxproj, stripped)
  puts "Removed project-level SYMROOT/OBJROOT from #{pbxproj}"
end

puts "Added Swift packages to #{project_path}: " \
     "#{PACKAGES.flat_map { |p| p[:products] }.join(', ')}"
