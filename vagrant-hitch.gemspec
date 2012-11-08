# -*- encoding: utf-8 -*-
#
Gem::Specification.new do |gem|
  gem.authors       = ["Aziz Shamim","James Fryman"]
  gem.email         = ["azizshamim@gmail.com", "james@frymanet.com"]
  gem.description   = %q{Creates and use a data driven vagrant environment}
  gem.summary       = %q{Creates and use a data driven vagrant environment}
  gem.homepage      = "https://github.com/fup/vagrant-hitch"

  gem.add_dependency "vagrant"
  gem.add_development_dependency "rspec"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "vagrant-hitch"
  gem.require_paths = ["lib"]
  gem.version       = "0.0.6"
end
