# frozen_string_literal: true

# Read build diagnostics only; do not start builds or execute release operations.
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
  result = {
    run: run,
    workflow: {
      id: workflow.fetch("id"),
      attributes: workflow.fetch("attributes").select { |key, _|
        %w[name description isEnabled isLocked clean pullRequestStartCondition branchStartCondition tagStartCondition scheduledStartCondition actions].include?(key)
      }
    },
    actions: actions.map do |action|
      issues = client.get("/v1/ciBuildActions/#{action.fetch('id')}/issues", "limit" => 200).fetch("data")
      { action: action, issues: issues }
    end
  }
  results[platform] = result
  puts JSON.pretty_generate(platform => result)
end
File.write("apple-pr-diagnosis.json", JSON.pretty_generate(results))
