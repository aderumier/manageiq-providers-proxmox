lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "manageiq/providers/proxmox/version"

Gem::Specification.new do |spec|
  spec.name    = "manageiq-providers-proxmox"
  spec.version = ManageIQ::Providers::Proxmox::VERSION
  spec.authors = ["Martins"]
  spec.email   = ["david.martins@groupe-cyllene.com"]

  spec.summary     = "ManageIQ plugin for Proxmox provider"
  spec.description = "Proxmox provider for ManageIQ"
  spec.homepage    = "https://github.com/ManageIQ/manageiq-providers-proxmox"
  spec.license     = "Apache-2.0"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "lib/**/*",
    "app/**/*",
    "config/**/*",
    "plugin.rb"
  ] + %w[README.md LICENSE.txt CHANGELOG.md].select { |f| File.exist?(f) }
  
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rest-client", "~> 2.1"
  
  # Development dependencies
  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", ">= 0.21.2"
end
