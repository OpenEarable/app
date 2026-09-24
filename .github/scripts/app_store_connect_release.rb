#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "time"
require "timeout"
require "uri"

class AppStoreConnectError < StandardError; end

class AppStoreConnectClient
  BASE_URL = "https://api.appstoreconnect.apple.com"

  def initialize(key_id:, issuer_id:, private_key:)
    @key_id = key_id
    @issuer_id = issuer_id
    @private_key = OpenSSL::PKey.read(normalize_private_key(private_key))
  end

  def get(path, query = {})
    request(Net::HTTP::Get, path, query: query)
  end

  def post(path, body)
    request(Net::HTTP::Post, path, body: body)
  end

  def patch(path, body)
    request(Net::HTTP::Patch, path, body: body)
  end

  private

  def normalize_private_key(value)
    key = value.gsub("\\n", "\n").strip
    return key if key.include?("BEGIN PRIVATE KEY") || key.include?("BEGIN EC PRIVATE KEY")

    Base64.strict_decode64(key)
  rescue ArgumentError
    raise AppStoreConnectError,
          "APP_STORE_CONNECT_PRIVATE_KEY must contain the .p8 contents or their base64 encoding"
  end

  def token
    issued_at = Time.now.to_i
    header = { alg: "ES256", kid: @key_id, typ: "JWT" }
    payload = {
      iss: @issuer_id,
      iat: issued_at,
      exp: issued_at + (15 * 60),
      aud: "appstoreconnect-v1"
    }
    signing_input = [header, payload].map { |part| base64url(JSON.generate(part)) }.join(".")
    digest = OpenSSL::Digest::SHA256.digest(signing_input)
    der_signature = @private_key.dsa_sign_asn1(digest)
    sequence = OpenSSL::ASN1.decode(der_signature)
    raw_signature = sequence.value.map { |integer| integer_bytes(integer.value) }.join

    "#{signing_input}.#{base64url(raw_signature)}"
  end

  def integer_bytes(integer)
    [format("%064x", integer)].pack("H*")
  end

  def base64url(value)
    Base64.urlsafe_encode64(value, padding: false)
  end

  def request(request_class, path, query: {}, body: nil)
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(query) unless query.empty?

    attempts = 0
    begin
      attempts += 1
      request = request_class.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"
      if body
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.open_timeout = 30
        http.read_timeout = 60
        http.request(request)
      end

      if response.code.to_i.between?(200, 299)
        return {} if response.body.nil? || response.body.empty?

        return JSON.parse(response.body)
      end

      if (response.code.to_i == 429 || response.code.to_i >= 500) && attempts < 4
        delay = [response["retry-after"].to_i, 5 * attempts].max
        warn "Apple API returned HTTP #{response.code}; retrying in #{delay} seconds"
        sleep delay
        retry
      end

      raise AppStoreConnectError, api_error(response)
    rescue IOError, SocketError, SystemCallError, Timeout::Error => error
      raise if attempts >= 4

      warn "Apple API request failed (#{error.message}); retrying"
      sleep 5 * attempts
      retry
    end
  end

  def api_error(response)
    parsed = JSON.parse(response.body)
    details = Array(parsed["errors"]).map do |error|
      [error["code"], error["title"], error["detail"]].compact.join(": ")
    end
    message = details.empty? ? response.body : details.join(" | ")
    "Apple API request failed with HTTP #{response.code}: #{message}"
  rescue JSON::ParserError
    "Apple API request failed with HTTP #{response.code}: #{response.body}"
  end
end

class AppStoreRelease
  SUBMITTED_STATES = %w[
    ACCEPTED
    IN_REVIEW
    PENDING_APPLE_RELEASE
    PENDING_DEVELOPER_RELEASE
    PROCESSING_FOR_DISTRIBUTION
    READY_FOR_DISTRIBUTION
    READY_FOR_SALE
    WAITING_FOR_EXPORT_COMPLIANCE
    WAITING_FOR_REVIEW
  ].freeze

  def initialize(client:, options:)
    @client = client
    @options = options
    @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + options.fetch(:timeout)
  end

  def run
    validate_release_notes!
    return puts("Release inputs are valid") if @options[:validate_only]

    build_run = wait_for_xcode_cloud_run
    build = wait_for_processed_build(build_run.fetch("id"))
    version = find_or_create_version

    if submitted?(version)
      puts "App Store version #{@options[:version]} is already in #{version_state(version)}"
      return
    end

    update_release_type(version.fetch("id"))
    update_release_notes(version.fetch("id"))
    attach_build(version.fetch("id"), build.fetch("id"))
    submit_for_review(version.fetch("id"))

    puts "Submitted #{@options[:platform]} version #{@options[:version]} for App Review"
  end

  private

  def validate_release_notes!
    default_path = File.join(@options[:release_notes_dir], "default.txt")
    raise AppStoreConnectError, "Missing release notes: #{default_path}" unless File.file?(default_path)

    validate_note!(default_path)
    Dir.glob(File.join(@options[:release_notes_dir], "*.txt")).each { |path| validate_note!(path) }
  end

  def validate_note!(path)
    note = File.read(path, encoding: "UTF-8").strip
    raise AppStoreConnectError, "Release notes are empty: #{path}" if note.empty?
    return if note.length <= 4000

    raise AppStoreConnectError, "Release notes exceed Apple's 4000-character limit: #{path}"
  end

  def wait_for_xcode_cloud_run
    puts "Waiting for Xcode Cloud workflow #{@options[:workflow_id]} at #{@options[:tag]}"
    loop do
      response = @client.get(
        "/v1/ciWorkflows/#{@options[:workflow_id]}/buildRuns",
        "sort" => "-number",
        "limit" => 25,
        "include" => "sourceBranchOrTag"
      )
      references = Array(response["included"]).each_with_object({}) do |resource, index|
        index[resource["id"]] = resource if resource["type"] == "scmGitReferences"
      end
      matching_runs = Array(response["data"]).select do |run|
        commit_sha = run.dig("attributes", "sourceCommit", "commitSha").to_s
        reference_id = run.dig("relationships", "sourceBranchOrTag", "data", "id")
        reference = references[reference_id]
        names = [reference&.dig("attributes", "name"), reference&.dig("attributes", "canonicalName")]
        same_commit = commit_sha == @options[:git_sha] || commit_sha.start_with?(@options[:git_sha]) ||
                      @options[:git_sha].start_with?(commit_sha)
        same_commit && names.compact.any? do |name|
          name == @options[:tag] || name == "refs/tags/#{@options[:tag]}"
        end
      end
      run = matching_runs.max_by { |candidate| candidate.dig("attributes", "number").to_i }

      if run
        progress = run.dig("attributes", "executionProgress")
        if progress == "COMPLETE"
          status = run.dig("attributes", "completionStatus")
          raise AppStoreConnectError, "Xcode Cloud build finished with #{status}" unless status == "SUCCEEDED"

          puts "Xcode Cloud build ##{run.dig('attributes', 'number')} succeeded"
          return run
        end
        puts "Xcode Cloud build ##{run.dig('attributes', 'number')} is #{progress}"
      else
        puts "The tag-triggered Xcode Cloud build has not appeared yet"
      end

      wait_or_timeout!
    end
  end

  def wait_for_processed_build(build_run_id)
    puts "Waiting for App Store Connect to process the Xcode Cloud archive"
    loop do
      response = @client.get(
        "/v1/ciBuildRuns/#{build_run_id}/builds",
        "filter[app]" => @options[:app_id],
        "filter[preReleaseVersion.version]" => @options[:version],
        "filter[preReleaseVersion.platform]" => @options[:platform],
        "sort" => "-uploadedDate",
        "limit" => 10
      )
      builds = Array(response["data"])
      invalid = builds.find { |build| %w[FAILED INVALID].include?(build.dig("attributes", "processingState")) }
      if invalid
        raise AppStoreConnectError,
              "Apple rejected build #{invalid.dig('attributes', 'version')} as " \
              "#{invalid.dig('attributes', 'processingState')}"
      end

      build = builds.find { |candidate| candidate.dig("attributes", "processingState") == "VALID" }
      if build
        audience = build.dig("attributes", "buildAudienceType")
        unless audience == "APP_STORE_ELIGIBLE"
          raise AppStoreConnectError,
                "Build #{build.dig('attributes', 'version')} is #{audience}; configure the Xcode Cloud " \
                "archive for TestFlight and App Store distribution"
        end

        puts "Build #{build.dig('attributes', 'version')} is valid and App Store eligible"
        return build
      end

      puts builds.empty? ? "No uploaded build is associated with the run yet" : "The build is still processing"
      wait_or_timeout!
    end
  end

  def find_or_create_version
    response = @client.get(
      "/v1/apps/#{@options[:app_id]}/appStoreVersions",
      "filter[platform]" => @options[:platform],
      "filter[versionString]" => @options[:version],
      "limit" => 10
    )
    version = Array(response["data"]).first
    return version if version

    puts "Creating #{@options[:platform]} App Store version #{@options[:version]}"
    @client.post(
      "/v1/appStoreVersions",
      data: {
        type: "appStoreVersions",
        attributes: {
          platform: @options[:platform],
          versionString: @options[:version],
          reviewType: "APP_STORE",
          releaseType: @options[:release_type]
        },
        relationships: {
          app: { data: { type: "apps", id: @options[:app_id] } }
        }
      }
    ).fetch("data")
  end

  def submitted?(version)
    SUBMITTED_STATES.include?(version_state(version))
  end

  def version_state(version)
    version.dig("attributes", "appVersionState") || version.dig("attributes", "appStoreState")
  end

  def update_release_type(version_id)
    @client.patch(
      "/v1/appStoreVersions/#{version_id}",
      data: {
        type: "appStoreVersions",
        id: version_id,
        attributes: { releaseType: @options[:release_type] }
      }
    )
  end

  def update_release_notes(version_id)
    localizations = wait_for_localizations(version_id)
    default_note = File.read(File.join(@options[:release_notes_dir], "default.txt"), encoding: "UTF-8").strip

    localizations.each do |localization|
      locale = localization.dig("attributes", "locale")
      localized_path = File.join(@options[:release_notes_dir], "#{locale}.txt")
      note = File.file?(localized_path) ? File.read(localized_path, encoding: "UTF-8").strip : default_note
      @client.patch(
        "/v1/appStoreVersionLocalizations/#{localization.fetch('id')}",
        data: {
          type: "appStoreVersionLocalizations",
          id: localization.fetch("id"),
          attributes: { whatsNew: note }
        }
      )
      puts "Updated What's New for #{locale}"
    end
  end

  def wait_for_localizations(version_id)
    6.times do
      response = @client.get(
        "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
        "limit" => 200
      )
      localizations = Array(response["data"])
      return localizations unless localizations.empty?

      sleep 10
    end

    raise AppStoreConnectError,
          "The new App Store version has no localizations. Configure its store metadata in App Store Connect first."
  end

  def attach_build(version_id, build_id)
    @client.patch(
      "/v1/appStoreVersions/#{version_id}/relationships/build",
      data: { type: "builds", id: build_id }
    )
    puts "Attached build #{build_id} to App Store version #{version_id}"
  end

  def submit_for_review(version_id)
    existing = review_submission_for(version_id)
    if existing
      state = existing.dig("attributes", "state")
      if state == "READY_FOR_REVIEW"
        submit_review(existing.fetch("id"))
      else
        puts "Review submission is already #{state}"
      end
      return
    end

    submission = @client.post(
      "/v1/reviewSubmissions",
      data: {
        type: "reviewSubmissions",
        attributes: { platform: @options[:platform] },
        relationships: {
          app: { data: { type: "apps", id: @options[:app_id] } }
        }
      }
    ).fetch("data")
    submission_id = submission.fetch("id")

    @client.post(
      "/v1/reviewSubmissionItems",
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: {
            data: { type: "reviewSubmissions", id: submission_id }
          },
          appStoreVersion: {
            data: { type: "appStoreVersions", id: version_id }
          }
        }
      }
    )
    submit_review(submission_id)
  end

  def review_submission_for(version_id)
    response = @client.get(
      "/v1/apps/#{@options[:app_id]}/reviewSubmissions",
      "filter[platform]" => @options[:platform],
      "include" => "appStoreVersionForReview",
      "limit" => 50
    )
    Array(response["data"]).find do |submission|
      submission.dig("relationships", "appStoreVersionForReview", "data", "id") == version_id
    end
  end

  def submit_review(submission_id)
    @client.patch(
      "/v1/reviewSubmissions/#{submission_id}",
      data: {
        type: "reviewSubmissions",
        id: submission_id,
        attributes: { submitted: true }
      }
    )
  end

  def wait_or_timeout!
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    raise AppStoreConnectError, "Timed out waiting for Apple release processing" if now >= @deadline

    sleep [20, @deadline - now].min
  end
end

begin
  options = {
    timeout: 7200,
    release_type: "AFTER_APPROVAL",
    validate_only: false
  }

  OptionParser.new do |parser|
    parser.banner = "Usage: app_store_connect_release.rb [options]"
    parser.on("--workflow-id ID") { |value| options[:workflow_id] = value }
    parser.on("--app-id ID") { |value| options[:app_id] = value }
    parser.on("--platform PLATFORM") { |value| options[:platform] = value }
    parser.on("--version VERSION") { |value| options[:version] = value }
    parser.on("--tag TAG") { |value| options[:tag] = value }
    parser.on("--git-sha SHA") { |value| options[:git_sha] = value }
    parser.on("--release-notes-dir PATH") { |value| options[:release_notes_dir] = value }
    parser.on("--release-type TYPE") { |value| options[:release_type] = value }
    parser.on("--timeout SECONDS", Integer) { |value| options[:timeout] = value }
    parser.on("--validate-only") { options[:validate_only] = true }
  end.parse!

  required = %i[platform version release_notes_dir]
  required += %i[workflow_id app_id tag git_sha] unless options[:validate_only]
  missing = required.select { |key| options[key].nil? || options[key].empty? }
  raise AppStoreConnectError, "Missing options: #{missing.join(', ')}" unless missing.empty?
  unless %w[IOS MAC_OS].include?(options[:platform])
    raise AppStoreConnectError, "Unsupported platform: #{options[:platform]}"
  end
  unless %w[MANUAL AFTER_APPROVAL].include?(options[:release_type])
    raise AppStoreConnectError, "Release type must be MANUAL or AFTER_APPROVAL"
  end

  client = if options[:validate_only]
             nil
           else
             AppStoreConnectClient.new(
               key_id: ENV.fetch("APP_STORE_CONNECT_KEY_ID"),
               issuer_id: ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
               private_key: ENV.fetch("APP_STORE_CONNECT_PRIVATE_KEY")
             )
           end

  AppStoreRelease.new(client: client, options: options).run
rescue AppStoreConnectError, KeyError, OpenSSL::PKey::PKeyError => error
  warn "::error::#{error.message}"
  exit 1
end
