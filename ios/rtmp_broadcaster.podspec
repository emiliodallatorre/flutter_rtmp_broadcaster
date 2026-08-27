#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rtmp_broadcaster.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'rtmp_broadcaster'
  s.version          = '0.0.1'
  s.summary          = 'FLutter plugin to allow rtmp to work with ios.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/nhancv/flutter_rtmp_broadcaster'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'WhelkSoft' => 'pinkfish@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'HaishinKit', '~> 1.9.9'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.10'
end
