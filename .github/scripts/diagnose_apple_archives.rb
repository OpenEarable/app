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
uploads = client.get("/v1/apps/6746388345/buildUploads", limit: 25)
puts "::group::Recent Apple build uploads"
puts "Returned uploads: #{uploads.fetch('data').length}"
uploads.fetch("data").each do |upload|
  puts JSON.generate(id: upload.fetch("id"), attributes: upload.fetch("attributes"))
end
puts "::endgroup::"
{
  "iOS" => "29e12b76-738a-48bf-ba13-113295d857df",
  "macOS" => "908c7876-2dbe-46c8-9f9d-ef5023ae7f3a"
}.each do |platform, run|
  puts "::group::#{platform} run and uploaded builds"
  details = client.get("/v1/ciBuildRuns/#{run}").fetch("data")
  puts JSON.pretty_generate(details)
  builds = client.get("/v1/ciBuildRuns/#{run}/builds").fetch("data")
  builds.each { |build| puts JSON.generate(id: build.fetch("id"), attributes: build.fetch("attributes")) }
  puts "::endgroup::"
end
