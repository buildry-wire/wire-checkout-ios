Pod::Spec.new do |s|
  s.name             = "WireCheckout"
  s.version          = "1.0.0"
  s.summary          = "Client-side Swift SDK for presenting a Wire hosted checkout."
  s.description      = <<-DESC
    WireCheckout presents a Wire hosted checkout session in a secure in-app
    browser (ASWebAuthenticationSession) and resolves the outcome from the
    authoritative status API. Client-side only — no secret key in the app.
  DESC
  s.homepage         = "https://github.com/buildry-wire/wire-checkout-ios"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Buildry" => "support@wire.mn" }
  s.source           = { :git => "https://github.com/buildry-wire/wire-checkout-ios.git", :tag => "v#{s.version}" }
  s.documentation_url = "https://docs.wire.mn"

  s.swift_version    = "5.9"
  s.ios.deployment_target = "14.0"

  s.source_files     = "Sources/WireCheckout/**/*.swift"
  s.frameworks       = "Foundation", "AuthenticationServices", "UIKit"
end
