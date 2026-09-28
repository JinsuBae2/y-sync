require 'minitest/autorun'
require 'yaml'

class WorkflowConfigTest < Minitest::Test
  def test_load_test_job_uses_production_environment_secrets
    workflow_path = File.expand_path('../../.github/workflows/k6-load-test.yml', __dir__)
    workflow = YAML.load_file(workflow_path)

    assert_equal 'production', workflow.fetch('jobs').fetch('k6').fetch('environment')
  end
end
