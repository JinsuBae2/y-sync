require 'minitest/autorun'
require 'yaml'

class WorkflowConfigTest < Minitest::Test
  def test_load_test_job_uses_production_environment_secrets
    workflow_path = File.expand_path('../../.github/workflows/k6-load-test.yml', __dir__)
    workflow = YAML.load_file(workflow_path)

    assert_equal 'production', workflow.fetch('jobs').fetch('k6').fetch('environment')
  end


  def test_workflow_exposes_staged_and_soak_profiles
    workflow_path = File.expand_path('../../.github/workflows/k6-load-test.yml', __dir__)
    workflow_text = File.read(workflow_path)

    assert_includes workflow_text, 'test_profile:'
    assert_includes workflow_text, "- staged"
    assert_includes workflow_text, "- soak"
    assert_includes workflow_text, 'TEST_PROFILE: ${{ inputs.test_profile }}'
  end


  def test_workflow_collects_restart_counts_and_recent_errors
    workflow_path = File.expand_path('../../.github/workflows/k6-load-test.yml', __dir__)
    workflow_text = File.read(workflow_path)

    assert_includes workflow_text, 'RestartCount'
    assert_includes workflow_text, 'docker logs --since'
  end


  def test_ssh_key_is_removed_after_final_diagnostic
    workflow_path = File.expand_path('../../.github/workflows/k6-load-test.yml', __dir__)
    workflow_text = File.read(workflow_path)

    diagnostic_position = workflow_text.index('server-diagnostic-output.txt 2>&1')
    key_cleanup_position = workflow_text.rindex('rm -f "$ssh_key"')

    assert_operator key_cleanup_position, :>, diagnostic_position
  end
end
