Gem::Specification.new do |s|
  s.name = 'dynarex-blog'
  s.version = '0.7.4'
  s.summary = 'dynarex-blog'
    s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.add_dependency('polyrex')
  s.add_dependency('dynarex')
  s.add_dependency('hashcache') 
  s.signing_key = '../privatekeys/dynarex-blog.pem'
  s.cert_chain  = ['gem-public_cert.pem']
end
