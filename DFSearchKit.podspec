Pod::Spec.new do |s|
  s.name         = "DFSearchKit"
  s.version      = "1.0"
  s.summary      = "A framework implementing a search index and summary generator using SKSearchKit for both Swift and Objective-C"
  s.description  = <<-DESC
    A framework implementing a search index and summary generator using SKSearchKit for both Swift and Objective-C
  DESC
  s.homepage     = "https://github.com/dagronf/DFSearchKit"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Darren Ford" => "dford_au-reg@yahoo.com" }
  s.social_media_url   = ""
  s.osx.deployment_target = "10.11"
  s.source       = { :git => ".git", :tag => s.version.to_s }
  s.source_files  = "DFSearchKit/*.swift"
  s.frameworks  = "Cocoa"
end
