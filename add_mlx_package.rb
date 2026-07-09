# Adds the mlx-swift-examples SwiftPM dependency (MLXLLM + MLXLMCommon) to the app
# target only, pinned to the exact release whose API MLXVerseExplainer was written against.
# Idempotent: safe to run more than once. Run from the submodule root:
#   ruby add_mlx_package.rb
require 'xcodeproj'

PROJECT  = 'Bhagavad Gita Verses.xcodeproj'
URL      = 'https://github.com/ml-explore/mlx-swift-examples'
VERSION  = '2.25.9'                      # exact — the API surface verified for MLXVerseExplainer
PRODUCTS = %w[MLXLLM MLXLMCommon]
TARGET   = 'Bhagavad Gita Verses'        # app only; MLX must NOT link into Widgets / App Intent

p   = Xcodeproj::Project.open(PROJECT)
app = p.targets.find { |t| t.name == TARGET } or raise "target #{TARGET} not found"

pkg = p.root_object.package_references.find do |r|
  r.respond_to?(:repositoryURL) && r.repositoryURL == URL
end
unless pkg
  pkg = p.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg.repositoryURL = URL
  pkg.requirement = { 'kind' => 'exactVersion', 'version' => VERSION }
  p.root_object.package_references << pkg
  puts "added remote package reference #{URL} @ #{VERSION}"
end

PRODUCTS.each do |name|
  if app.package_product_dependencies.any? { |d| d.product_name == name }
    puts "#{name}: already linked"
    next
  end
  dep = p.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = pkg
  dep.product_name = name
  app.package_product_dependencies << dep

  bf = p.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  app.frameworks_build_phase.files << bf
  puts "#{name}: linked into #{TARGET}"
end

p.save
puts 'saved.'
