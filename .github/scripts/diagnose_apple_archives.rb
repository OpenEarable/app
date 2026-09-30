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
expected_sha = "9d16f16adeafc3da3aab030c224e680f91e0d347"
canonical_name = "refs/heads/automation/bump-version-1.5.3-35604992876"
workflows = {
  "IOS" => "4b7988a0-f836-4601-8ba4-5efa3dc8539e",
  "MAC_OS" => "342E9851-0012-4329-BF37-1CCEB39FF030"
}
runs = []
workflows.each do |platform, workflow_id|
  workflow = client.get("/v1/ciWorkflows/#{workflow_id}").fetch("data")
  expected_name = platform == "IOS" ? "iOS TestFlight - main" : "macOS TestFlight - main"
  raise "Unexpected workflow" unless workflow.dig("attributes", "name") == expected_name
  repository = client.get("/v1/ciWorkflows/#{workflow_id}/repository").fetch("data")
  ref_path = "/v1/scmRepositories/#{repository.fetch('id')}/gitReferences"
  query = { "fields[scmGitReferences]" => "name,canonicalName,isDeleted,kind", "limit" => 200 }
  reference = nil
  loop do
    response = client.get(ref_path, query)
    reference = response.fetch("data").find do |ref|
      ref.dig("attributes", "canonicalName") == canonical_name && !ref.dig("attributes", "isDeleted")
    end
    break if reference || !response.dig("links", "next")
    next_page = URI(response.fetch("links").fetch("next"))
    raise "Unexpected pagination host" unless next_page.host == "api.appstoreconnect.apple.com"
    ref_path = next_page.path
    query = URI.decode_www_form(next_page.query.to_s).to_h
  end
  raise "Apple has not indexed #{canonical_name}" unless reference
  puts "Starting #{expected_name} at #{canonical_name} (#{reference.fetch('id')})"
  run = client.post("/v1/ciBuildRuns", data: {
    type: "ciBuildRuns",
    attributes: {},
    relationships: {
      workflow: { data: { type: "ciWorkflows", id: workflow_id } },
      sourceBranchOrTag: { data: { type: "scmGitReferences", id: reference.fetch("id") } }
    }
  }).fetch("data")
  entry = { platform: platform, id: run.fetch("id"), number: run.dig("attributes", "number") }
  runs << entry
  puts JSON.generate(entry)
  File.write("apple-archive-verification.json", JSON.pretty_generate(runs))
end

deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1200
pending = runs.dup
until pending.empty?
  pending.delete_if do |entry|
    run = client.get("/v1/ciBuildRuns/#{entry.fetch(:id)}").fetch("data")
    attrs = run.fetch("attributes")
    sha = attrs.dig("sourceCommit", "commitSha")
    raise "Build used unexpected commit #{sha}" if sha && sha != expected_sha
    puts "#{entry.fetch(:platform)} build #{attrs['number']}: #{attrs['executionProgress']} #{attrs['completionStatus']}"
    next false unless attrs["executionProgress"] == "COMPLETE"
    entry[:completionStatus] = attrs["completionStatus"]
    entry[:sha] = sha
    if attrs["completionStatus"] == "SUCCEEDED"
      builds = client.get("/v1/ciBuildRuns/#{entry.fetch(:id)}/builds", "filter[app]" => "6746388345").fetch("data")
      entry[:builds] = builds.map { |build| { id: build.fetch("id"), attributes: build.fetch("attributes") } }
    else
      actions = client.get("/v1/ciBuildRuns/#{entry.fetch(:id)}/actions").fetch("data")
      entry[:errors] = actions.flat_map do |action|
        client.get("/v1/ciBuildActions/#{action.fetch('id')}/issues", "limit" => 200).fetch("data")
      end.select { |issue| issue.dig("attributes", "issueType") == "ERROR" }.map { |issue| issue.fetch("attributes") }
    end
    puts JSON.generate(entry)
    File.write("apple-archive-verification.json", JSON.pretty_generate(runs))
    true
  end
  break if pending.empty?
  raise "Verification timeout; inspect existing run IDs before continuing" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  sleep 30
end
uploads = client.get("/v1/apps/6746388345/buildUploads", limit: 25).fetch("data")
uploads.select { |upload| upload.dig("attributes", "cfBundleShortVersionString") == "1.5.3" }.each do |upload|
  puts JSON.generate(upload.fetch("attributes"))
end
raise "An archive failed" unless runs.all? { |run| run[:completionStatus] == "SUCCEEDED" }
