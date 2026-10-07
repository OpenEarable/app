# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../app_store_connect_release'

class AppStoreConnectReleaseTest < Minitest::Test
  def setup
    @notes_dir = Dir.mktmpdir
    File.write(File.join(@notes_dir, "default.txt"), "Release improvements.")
  end

  def teardown
    FileUtils.remove_entry(@notes_dir)
  end

  class Client
    attr_reader :requests
    def initialize(builds)
      @builds = builds
      @requests = []
    end
    def get(path, query = {})
      @requests << [path, query]
      raise "Unexpected API request: #{path}" unless path == '/v1/builds'
      { 'data' => @builds }
    end
  end

  def build(state = 'VALID', audience = 'APP_STORE_ELIGIBLE')
    { 'id' => 'uploaded-build', 'attributes' => {
      'version' => '2610.0710.1234', 'processingState' => state,
      'buildAudienceType' => audience
    } }
  end

  def release(client, **overrides)
    AppStoreRelease.new(client: client, options: {
      app_id: 'app-id', platform: 'IOS', version: '1.6.0',
      build_number: '2610.0710.1234', timeout: 0,
      release_notes_dir: @notes_dir,
      process_only: true
    }.merge(overrides))
  end

  def test_processing_only_selects_exact_app_platform_version_and_build_without_submission
    client = Client.new([build])
    capture_io { release(client).run }
    assert_equal 1, client.requests.length
    path, query = client.requests.first
    assert_equal '/v1/builds', path
    assert_equal 'app-id', query['filter[app]']
    assert_equal 'IOS', query['filter[preReleaseVersion.platform]']
    assert_equal '1.6.0', query['filter[preReleaseVersion.version]']
    assert_equal '2610.0710.1234', query['filter[version]']
  end

  def test_macos_uses_its_own_platform_filter
    client = Client.new([build])
    capture_io { release(client, platform: 'MAC_OS').run }
    assert_equal 'MAC_OS', client.requests.first.last['filter[preReleaseVersion.platform]']
  end

  def test_rejected_build_cannot_be_submitted
    %w[FAILED INVALID].each do |state|
      error = assert_raises(AppStoreConnectError) do
        capture_io { release(Client.new([build(state)])).run }
      end
      assert_match(/Apple rejected build/, error.message)
    end
  end

  def test_internal_only_build_cannot_be_submitted
    assert_raises(AppStoreConnectError) do
      capture_io { release(Client.new([build('VALID', 'INTERNAL_ONLY')])).run }
    end
  end

  def test_absent_and_processing_builds_time_out
    [[], [build('PROCESSING')]].each do |builds|
      error = assert_raises(AppStoreConnectError) do
        capture_io { release(Client.new(builds)).run }
      end
      assert_match(/Timed out/, error.message)
    end
  end

  def test_validate_only_makes_no_api_requests
    client = Client.new([])
    capture_io { release(client, validate_only: true).run }
    assert_empty client.requests
  end
  class BetaClient < Client
    attr_reader :mutations
    def initialize(builds, groups:, state: 'READY_FOR_BETA_SUBMISSION')
      super(builds)
      @groups = groups
      @state = state
      @mutations = []
    end
    def get(path, query = {})
      case path
      when '/v1/builds' then super
      when '/v1/apps/app-id/betaGroups' then { 'data' => @groups }
      when '/v1/builds/uploaded-build/betaBuildLocalizations' then { 'data' => [] }
      when '/v1/builds/uploaded-build/buildBetaDetail'
        { 'data' => { 'id' => 'beta-detail', 'attributes' => { 'externalBuildState' => @state } } }
      else raise "Unexpected API request: #{path}"
      end
    end
    def post(path, body)
      @mutations << [:post, path, body]
      {}
    end
    def patch(path, body)
      @mutations << [:patch, path, body]
      {}
    end
  end

  def beta_groups
    [
      { 'id' => 'internal', 'attributes' => { 'name' => 'Internal Testing', 'isInternalGroup' => true, 'hasAccessToAllBuilds' => true } },
      { 'id' => 'external', 'attributes' => { 'name' => 'External Testing', 'isInternalGroup' => false } }
    ]
  end

  def test_testflight_uses_only_existing_groups_and_beta_review
    client = BetaClient.new([build], groups: beta_groups)
    capture_io do
      release(client, process_only: false, testflight_groups: ['Internal Testing', 'External Testing']).run
    end
    assert client.mutations.any? { |_, path, _| path == '/v1/betaAppReviewSubmissions' }
    assignments = client.mutations.select { |_, path, _| path.start_with?('/v1/betaGroups/') }
    assert_equal [[:post, '/v1/betaGroups/external/relationships/builds',
                   { data: [{ type: 'builds', id: 'uploaded-build' }] }]], assignments
    refute client.mutations.any? { |_, path, _| path.end_with?('/relationships/betaGroups') }
    refute client.mutations.any? { |_, path, _| path.include?('appStoreVersions') || path.include?('reviewSubmissions') }
  end

  def test_automatic_internal_group_needs_no_assignment_or_beta_review
    client = BetaClient.new([build], groups: beta_groups)
    output, = capture_io do
      release(client, process_only: false, testflight_groups: ['Internal Testing']).run
    end
    assert_match(/already has automatic access/, output)
    refute client.mutations.any? { |_, path, _| path.include?('/relationships/') || path == '/v1/betaAppReviewSubmissions' }
  end

  def test_manual_internal_group_uses_group_build_relationship_without_beta_review
    groups = beta_groups
    groups.first['attributes']['hasAccessToAllBuilds'] = false
    client = BetaClient.new([build], groups: groups)
    capture_io do
      release(client, process_only: false, testflight_groups: ['Internal Testing']).run
    end
    assert_equal [:post, '/v1/betaGroups/internal/relationships/builds',
                  { data: [{ type: 'builds', id: 'uploaded-build' }] }], client.mutations.last
    refute client.mutations.any? { |_, path, _| path == '/v1/betaAppReviewSubmissions' }
  end

  def test_missing_testflight_group_fails_without_changing_apple
    client = BetaClient.new([build], groups: beta_groups)
    assert_raises(AppStoreConnectError) do
      capture_io { release(client, process_only: false, testflight_groups: ['Wrong group']).run }
    end
    assert_empty client.mutations
  end

  def test_approved_beta_is_not_resubmitted
    client = BetaClient.new([build], groups: beta_groups, state: 'IN_BETA_TESTING')
    capture_io { release(client, process_only: false, testflight_groups: ['External Testing']).run }
    refute client.mutations.any? { |_, path, _| path == '/v1/betaAppReviewSubmissions' }
  end

end
