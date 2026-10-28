Pod::Spec.new do |s|
  s.name = 'flutter_adaptive_liquid_glass'
  s.version = '0.6.1'
  s.summary = 'Adaptive Flutter controls with native iOS Liquid Glass.'
  s.description = 'Native UIKit controls and appearance synchronization through public platform APIs.'
  s.homepage = 'https://github.com/starroyhq/flutter-adaptive-liquid-glass'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = { 'starroyhq' => 'https://github.com/starroyhq' }
  s.source = { :path => '.' }
  # Sources are shared with the Swift package in flutter_adaptive_liquid_glass/.
  s.source_files = 'flutter_adaptive_liquid_glass/Sources/flutter_adaptive_liquid_glass/**/*.swift'
  s.resource_bundles = {
    'flutter_adaptive_liquid_glass_privacy' => ['flutter_adaptive_liquid_glass/Sources/flutter_adaptive_liquid_glass/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  # Keep in step with `platforms` in flutter_adaptive_liquid_glass/Package.swift.
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
