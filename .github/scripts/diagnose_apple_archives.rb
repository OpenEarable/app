# frozen_string_literal: true

# Reuse only the API client; do not execute any release operations.
source = File.read(File.join(__dir__, "app_store_connect_release.rb"))
eval(source.split("\nclass AppStoreRelease", 2).first, TOPLEVEL_BINDING, "app_store_connect_client.rb")
client = AppStoreConnectClient.new(
  key_id: ENV.fetch("APP_STORE_CONNECT_KEY_ID"),
  issuer_id: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
  private_key: ENV.fetch("APP_STORE_CONNECT_PRIVATE_KEY")
)
{
  "iOS" => "fe94dbb4-fdb4-4d23-b5bb-d0e015b3baea",
  "macOS" => "4a874fc3-0342-464d-a0ef-40c405eb9c65"
}.each do |platform, action|
  puts "::group::#{platform} archive diagnostics"
  details = client.get("/v1/ciBuildActions/#{action}").fetch("data")
  puts JSON.pretty_generate(details.fetch("attributes"))
  issues = client.get("/v1/ciBuildActions/#{action}/issues", limit: 200).fetch("data")
  issues.each do |issue|
    attrs = issue.fetch("attributes")
    puts JSON.generate(attrs) if attrs["issueType"] == "ERROR"
  end
  artifacts = client.get("/v1/ciBuildActions/#{action}/artifacts", limit: 200).fetch("data")
  artifacts.each do |artifact|
    attrs = artifact.fetch("attributes")
    puts JSON.generate(id: artifact.fetch("id"), fileType: attrs["fileType"], fileName: attrs["fileName"], fileSize: attrs["fileSize"])
  end
  puts "::endgroup::"
end
