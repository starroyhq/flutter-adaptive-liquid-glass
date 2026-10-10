Pod::Spec.new do |s|
  s.name = 'flutter_adaptive_liquid_glass'
  s.version = '0.1.0'
  s.summary = 'App appearance synchronization for native Flutter glass controls.'
  s.description = 'Applies the app-selected UIKit appearance through public platform APIs.'
  s.homepage = 'https://github.com/starroyhq/flutter-adaptive-liquid-glass'
  s.license = { :type => 'Proprietary' }
  s.author = { 'starroyhq' => 'https://github.com/starroyhq' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
