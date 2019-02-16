Pod::Spec.new do |s|
  s.name             = "NetworkManager"
  s.version          = "1.0.20"
  s.summary          = "NetworkManager library DeeplyMadStudio"
  s.homepage         = "https://github.com/daniele99999999/networkmanager-ios"
  s.license          = { :type => 'MIT' }
  s.author           = { "DeeplyMadStudio" => "deeplymadstudio@gmail.com" }
  s.source           = { :git => "https://github.com/daniele99999999/networkmanager-ios", :tag => s.version }

  s.platform     = :ios, '8.0'
  s.requires_arc = true
  s.frameworks   = 'Foundation'

  s.dependency 'SwifterSwift', '~> 4.0'
  s.dependency 'SwiftyJSON', '4.0.0'
  s.dependency 'Alamofire', '4.5.1'
  s.dependency 'AlamofireNetworkActivityIndicator', '2.2.0'
  s.dependency 'AlamofireImage', '3.3.0'
  s.dependency 'CodableAlamofire', '1.1.0'
  s.dependency 'LoggerManager', '~> 1.0.0'
  s.dependency 'Utils', '~> 1.0.0'


  s.source_files = 'Classes/**/*'
end