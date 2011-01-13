Gem::Specification.new do |s|
  s.name = 'dynarex-blog'
  s.version = '0.7.1'
  s.summary = 'dynarex-blog'
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('polyrex')
  s.add_dependency('dynarex')
  s.add_dependency('hashcache')
end
