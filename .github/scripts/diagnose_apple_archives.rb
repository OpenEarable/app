# frozen_string_literal: true

require "open-uri"
require "tmpdir"

# Reuse only the API client; do not execute any release operations.
source = File.read(File.join(__dir__, "app_store_connect_release.rb"))
eval(source.split("\nclass AppStoreRelease", 2).first, TOPLEVEL_BINDING, "app_store_connect_client.rb")
client = AppStoreConnectClient.new(
  key_id: ENV.fetch("APP_STORE_CONNECT_KEY_ID"),
  issuer_id: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
  private_key: ENV.fetch("APP_STORE_CONNECT_PRIVATE_KEY")
)
{
  "iOS" => "29e12b76-738a-48bf-ba13-113295d857df",
  "macOS" => "908c7876-2dbe-46c8-9f9d-ef5023ae7f3a"
}.each do |platform, run_id|
  puts "::group::#{platform} archive workflow"
  run = client.get("/v1/ciBuildRuns/#{run_id}", "include" => "workflow")
  workflow = run.fetch("included").find { |resource| resource["type"] == "ciWorkflows" }
  raise "Missing workflow" unless workflow
  puts JSON.generate(id: workflow.fetch("id"), attributes: workflow.fetch("attributes"))
  repository = client.get("/v1/ciWorkflows/#{workflow.fetch('id')}/repository").fetch("data")
  refs = client.get("/v1/scmRepositories/#{repository.fetch('id')}/gitReferences", "limit" => 200).fetch("data")
  refs.select { |ref| ref.dig("attributes", "canonicalName") == "refs/heads/automation/bump-version-1.5.3-35604992876" }.each { |ref| puts JSON.generate(ref) }
  puts "::endgroup::"
end
