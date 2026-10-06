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
builds.select { |run| run.dig("attributes", "startedDate").to_s >= "2026-09-06" }.each do |run|
  id = run.fetch("id")
  record(results, "actions_#{id}") { collect(client, "/v1/ciBuildRuns/#{id}/actions", "limit" => 200) }
end

if ENV["RETRY_CANCELLED_BUILD"] == "true"
  product_id = "5D6E7D70-9D8F-425C-9727-AD60401DE764"
  repository_id = "32a6c433-a95d-4633-b3a2-ae706e5c3732"
  diagnostic_name = "Manual iOS start diagnosis 2026-10-06"
  workflows = results.fetch("product_#{product_id}_workflows").fetch("data")
  existing = workflows.find { |workflow| workflow.dig("attributes", "name") == diagnostic_name }
  record(results, "diagnostic_workflow") do
    existing ? {"data" => existing} : client.post("/v1/ciWorkflows", data: {
      type: "ciWorkflows",
      attributes: {
        name: diagnostic_name,
        description: "Temporary manual build-only diagnostic. No archive, upload, distribution, or automatic triggers.",
        isEnabled: false,
        isLockedForEditing: true,
        clean: true,
        containerFilePath: "open_wearable/ios/Runner.xcworkspace",
        manualBranchStartCondition: {source: {isAllMatch: false, patterns: [{pattern: "automation/bump-version-1.5.4-36858743484", isPrefix: false}]}},
        actions: [{name: "Build iOS diagnostic", actionType: "BUILD", destination: "ANY_IOS_DEVICE", scheme: "Runner", platform: "IOS", isRequiredToPass: true}]
      },
      relationships: {
        product: {data: {type: "ciProducts", id: product_id}},
        repository: {data: {type: "scmRepositories", id: repository_id}},
        xcodeVersion: {data: {type: "ciXcodeVersions", id: "42533094-17d3-46b2-ada5-1f94ceb94b61"}},
        macOsVersion: {data: {type: "ciMacOsVersions", id: "c538a952-ac84-4277-bea4-b9dab48bb96c"}}
      }
    })
  end
  if results.dig("diagnostic_workflow", "data", "id")
    record(results, "diagnostic_build") do
      refs = collect(client, "/v1/scmRepositories/#{repository_id}/gitReferences", "limit" => 200)
      reference = refs.find { |ref| ref.dig("attributes", "canonicalName") == "refs/heads/automation/bump-version-1.5.4-36858743484" && !ref.dig("attributes", "isDeleted") }
      raise "Missing expected release branch" unless reference
      client.post("/v1/ciBuildRuns", data: {type: "ciBuildRuns", relationships: {
        workflow: {data: {type: "ciWorkflows", id: results.dig("diagnostic_workflow", "data", "id")}},
        sourceBranchOrTag: {data: {type: "scmGitReferences", id: reference.fetch("id")}}
      }})
    end
  end
end
