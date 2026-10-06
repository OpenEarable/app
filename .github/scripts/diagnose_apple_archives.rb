# frozen_string_literal: true

# Read diagnostics and optionally retry one existing PR validation build.
# No archive or release operations are performed.
source = File.read(File.join(__dir__, "app_store_connect_release.rb"))
eval(source.split("\nclass AppStoreRelease", 2).first, TOPLEVEL_BINDING, "app_store_connect_client.rb")
client = AppStoreConnectClient.new(
  key_id: ENV.fetch("APP_STORE_CONNECT_KEY_ID"),
  issuer_id: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
  private_key: ENV.fetch("APP_STORE_CONNECT_PRIVATE_KEY")
)

# Preserve diagnostic response metadata, never request credentials.
class AppStoreConnectClient
  private
  def api_error(response)
    safe_headers = response.each_header.to_h.select { |key, _| key.match?(/request.id|correlation|trace|x-apple|date|retry-after/) }
    "HTTP #{response.code}: #{response.body}; response metadata: #{safe_headers.to_json}"
  end
end
results = {}
def collect(client, path, query = {})
  items = []
  loop do
    response = client.get(path, query)
    items.concat(response.fetch("data"))
    break unless response.dig("links", "next")
    page = URI(response.fetch("links").fetch("next"))
    raise "Unexpected pagination host" unless page.host == "api.appstoreconnect.apple.com"
    path = page.path
    query = URI.decode_www_form(page.query.to_s).to_h
  end
  items
end
def record(results, key)
  results[key] = yield
  puts "Read #{key}"
rescue AppStoreConnectError => error
  results[key] = {error: error.message}
  puts "#{key}: #{error.message}"
ensure
  File.write("apple-pr-diagnosis.json", JSON.pretty_generate(results))
end
record(results, "products") { collect(client, "/v1/ciProducts", "limit" => 200) }
Array(results["products"]).each do |product|
  id = product.fetch("id")
  record(results, "product_#{id}_workflows") do
    client.get("/v1/ciProducts/#{id}/workflows", "limit" => 200,
      "include" => "repository,xcodeVersion,macOsVersion",
      "fields[ciXcodeVersions]" => "name,version,macOsVersions")
  end
  record(results, "product_#{id}_builds") do
    collect(client, "/v1/ciProducts/#{id}/buildRuns", "limit" => 200, "sort" => "-number")
  end
end
workflow_ids = %w[4c5830ae-2f0f-44da-9657-f7724c597436 34118c35-53e1-48f4-a4bb-7b25d98b6a44]
workflow_ids.each do |id|
  record(results, "workflow_#{id}") do
    client.get("/v1/ciWorkflows/#{id}", "include" => "product,repository,xcodeVersion,macOsVersion", "fields[ciXcodeVersions]" => "name,version,macOsVersions")
  end
  workflow = results.fetch("workflow_#{id}").fetch("data")
  xcode_id = workflow.dig("relationships", "xcodeVersion", "data", "id")
  record(results, "xcode_#{xcode_id}_supported_macos") do
    client.get("/v1/ciXcodeVersions/#{xcode_id}/macOsVersions", "limit" => 200)
  end
  repository_id = workflow.dig("relationships", "repository", "data", "id")
  record(results, "repository_#{repository_id}") do
    client.get("/v1/scmRepositories/#{repository_id}", "include" => "scmProvider,defaultBranch")
  end
end
# Action durations establish whether there was a common usage cutoff.
builds = results.select { |key, _| key.end_with?("_builds") }.values.flatten
builds.select { |run| run.dig("attributes", "startedDate").to_s >= "2026-10-01" }.each do |run|
  id = run.fetch("id")
  record(results, "actions_#{id}") { collect(client, "/v1/ciBuildRuns/#{id}/actions", "limit" => 200) }
end
