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

runs = {
  "iOS" => "30b722c3-a76d-4dac-b870-886c859ade8f",
  "macOS" => "29e409bc-15c3-470a-b544-89b45f746336"
}
results = {}
runs.each do |platform, id|
  response = client.get("/v1/ciBuildRuns/#{id}", "include" => "workflow")
  run = response.fetch("data")
  actions = client.get("/v1/ciBuildRuns/#{id}/actions").fetch("data")
  workflow = response.fetch("included").find { |entry| entry.fetch("type") == "ciWorkflows" }
  workflow_details = client.get("/v1/ciWorkflows/#{workflow.fetch('id')}", "include" => "xcodeVersion,macOsVersion")
  history = client.get("/v1/ciWorkflows/#{workflow.fetch('id')}/buildRuns", "limit" => 200).fetch("data")
  result = {
    run: run,
    workflow: {
      id: workflow.fetch("id"),
      attributes: workflow.fetch("attributes").select { |key, _|
        %w[name description isEnabled isLocked clean pullRequestStartCondition branchStartCondition tagStartCondition scheduledStartCondition actions].include?(key)
      }
    },
    environment: workflow_details.fetch("included", []).map { |item|
      { type: item.fetch("type"), id: item.fetch("id"), attributes: item.fetch("attributes").select { |key, _| %w[name version].include?(key) } }
    },
    recent_runs: history.map { |item| { id: item.fetch("id"), attributes: item.fetch("attributes") } },
    actions: actions.map do |action|
      issues = client.get("/v1/ciBuildActions/#{action.fetch('id')}/issues", "limit" => 200).fetch("data")
      { action: action, issues: issues }
    end
  }
  results[platform] = result
  puts JSON.pretty_generate(platform => result)
end
File.write("apple-pr-diagnosis.json", JSON.pretty_generate(results))

if ENV["RETRY_CANCELLED_BUILD"] == "true"
  ios = results.fetch("iOS")
  raise "Not the expected PR validation workflow" unless ios.dig(:workflow, :attributes, "name") == "iOS PR Validation"
  raise "Unexpected release action" if ios.dig(:workflow, :attributes, "actions").any? { |action| action["actionType"] == "ARCHIVE" }
  begin
    repository = client.get("/v1/ciWorkflows/#{ios.dig(:workflow, :id)}/repository").fetch("data")
    reference = nil
    ref_path = "/v1/scmRepositories/#{repository.fetch('id')}/gitReferences"
    query = { "limit" => 200 }
    loop do
      refs = client.get(ref_path, query)
      reference = refs.fetch("data").find { |ref|
        ref.dig("attributes", "canonicalName") == "refs/heads/automation/bump-version-1.5.4-36858743484" && !ref.dig("attributes", "isDeleted")
      }
      break if reference || !refs.dig("links", "next")
      page = URI(refs.fetch("links").fetch("next"))
      raise "Unexpected pagination host" unless page.host == "api.appstoreconnect.apple.com"
      ref_path = page.path
      query = URI.decode_www_form(page.query.to_s).to_h
    end
    raise "App 1.6.0 source branch not indexed by Apple" unless reference
    retry_response = client.post("/v1/ciBuildRuns", data: {
      type: "ciBuildRuns",
      attributes: {},
      relationships: {
        workflow: { data: { type: "ciWorkflows", id: ios.dig(:workflow, :id) } },
        sourceBranchOrTag: { data: { type: "scmGitReferences", id: reference.fetch("id") } }
      }
    })
    results["retry"] = retry_response
  rescue AppStoreConnectError => error
    results["retry"] = { error: error.message }
  end
  puts JSON.pretty_generate("retry" => results.fetch("retry"))
  File.write("apple-pr-diagnosis.json", JSON.pretty_generate(results))
end
