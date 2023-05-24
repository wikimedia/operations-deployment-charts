# frozen_string_literal: true

require_relative '../tester/asset'
require_relative '../utils'
require 'rake'

# When adding kubernetes versions here the corresponding schemata
# need to be made available in https://gitlab.wikimedia.org/repos/sre/kubernetes-json-schema
KUBERNETES_VERSIONS = ['1.23.6', '1.27.2'].freeze
kubeconform = which('kubeconform').nil?

def factory(to_run = nil)
  Tester::BaseTestAsset.new 'charts/foobar/Chart.yaml', to_run
end

valid_manifest = File.read(File.join(__dir__, 'fixtures/asset/valid.yaml'))
invalid_manifest = File.read(File.join(__dir__, 'fixtures/asset/errors.yaml'))
describe Tester::BaseTestAsset do
  let(:asset) do
    factory
  end
  describe '.new' do
    it 'has name foobar' do
      expect(asset.name).to eql('foobar')
    end

    it 'has path charts/foobar' do
      expect(asset.path).to eql('charts/foobar')
    end
    it 'has result set up and unfrozen' do
      expect(asset.result).to eql(Tester::BaseTestAsset::INIT_RESULT)
      expect(asset.result.frozen?).to be false
    end
    it 'should run' do
      expect(asset.should_run?).to be true
    end
    it 'has no fixtures' do
      expect(asset.fixtures.length).to eq(0)
    end
  end

  describe '.should_run?' do
    context 'when excluded' do
      let(:asset) { factory %w[baz bar] }
      it 'should not run' do
        expect(asset.should_run?).to be false
        expect(asset.ok?).to be true
      end
    end
    context 'when included' do
      let(:asset) { factory %w[baz foobar] }
      it 'should run' do
        expect(asset.should_run?).to be true
        expect(asset.ok?).to be true
      end
    end
    context 'when void' do
      let(:asset) { factory nil }
      it 'should run' do
        expect(asset.should_run?).to be true
      end
    end
  end

  describe '.should_test?' do
    context 'when excluded' do
      let(:asset) { factory %w[baz bar] }
      it 'should not test' do
        expect(asset.should_test?).to be false
        expect(asset.ok?).to be true
      end
    end
    context 'when included' do
      let(:asset) { factory %w[baz foobar] }
      it 'should test' do
        expect(asset.should_test?).to be true
        expect(asset.ok?).to be true
      end
      it 'should not test when marked bad, and be not ok' do
        asset.bad('msg', 'cmd')
        expect(asset.should_test?).to be false
        expect(asset.ok?).to be false
      end
    end
  end

  describe '._diff' do
    context 'with identical strings' do
      let(:outcome) do
        asset._diff("a\nstring", "a\nstring")
      end

      it 'should exit with status zero' do
        expect(outcome.exit_status).to eql(0)
      end

      it 'should have no output' do
        expect(outcome.out).to eql(nil)
      end
    end

    context 'with differences' do
      let(:outcome) do
        asset._diff("a\nstring", "another\nstring\n")
      end
      it 'should exit with status 1' do
        expect(outcome.exit_status).to eql(1)
      end
      it 'should include output' do
        expect(outcome.out).not_to be_empty
      end
    end
  end

  describe '.validate_yaml' do
    context 'on valid yaml' do
      let(:outcome) do
        asset.validate_yaml(Tester::TestOutcome.new("test: [1, 2]\n", '', 0, 'lol'))
      end

      it 'should have no output' do
        expect(outcome.out).to be_nil
      end

      it 'should have no error' do
        expect(outcome.err).to be_nil
      end

      it 'should have exit status 0' do
        expect(outcome.exit_status).to eql(0)
      end
      it 'should set the command to yaml-valdiate <prev command>' do
        expect(outcome.command).to eql('yaml-validate $(lol)')
      end
    end

    context 'on invalid yaml' do
      let(:outcome) do
        asset.validate_yaml(Tester::TestOutcome.new("a: test: [1, 2]\n - 1", '', 0, 'lol'))
      end
      it 'should have no output' do
        expect(outcome.out).to be_nil
      end

      it 'should have proper error reporting' do
        expect(outcome.err).to match(/Error is at line 1, column 8 of the output of `lol`/)
        expect(outcome.err).to match(/a\: test\: \[1, 2\]/)
      end

      it 'should have exit status 1' do
        expect(outcome.exit_status).to eql(1)
      end
    end
  end
  describe 'validate_kubeconform', unless: kubeconform do
    context 'when the output contains multiple valid documents' do
      let(:results) do
        input = Tester::TestOutcome.new(valid_manifest, '', 0, 'foobar')
        asset.validate_kubeconform('dummy-label', input, KUBERNETES_VERSIONS)
      end

      it 'should be ok' do
        expect(results.ok?).to eq(true)
      end
      it 'should have no errors' do
        expect(results.err).to be_empty
      end
      it 'should have scanned the whole document' do
        KUBERNETES_VERSIONS.each do |kubernetes_version|
          # The fixture contains 7 docs, one of which empty
          expect(results.outcomes[kubernetes_version].out.include?('Valid: 6')).to be_truthy
        end
      end
    end
    context 'when the output has invalid documents' do
      let(:results) do
        input = Tester::TestOutcome.new(invalid_manifest, '', 0, 'foobar')
        asset.validate_kubeconform('dummy-label', input, KUBERNETES_VERSIONS)
      end

      it 'should not be ok' do
        expect(results.ok?).to eq(false)
      end
      it 'should contain 2 invalid ressources and 1 error' do
        KUBERNETES_VERSIONS.each do |kubernetes_version|
          expect(results.err["k8s v#{kubernetes_version}"].include?('Invalid: 2, Errors: 1')).to be_truthy
        end
      end
    end
  end

  # Please note: we can't test validate or diff here unless we implement a stub version of
  # the templates function and of the collect_fixtures one.
  describe '.validate' do
    context 'a valid manifest' do
      let(:tpl) do
        Tester::TestOutcome.new(valid_manifest, '', 0, 'test --foo')
      end
      let(:asset) do
        asset = factory
        allow(asset).to receive(:templates).and_return({ 'foobar': tpl })
        allow(asset).to receive(:collect_fixtures).and_return({ 'foobar': nil })
        asset
      end
      context 'without kubeconform' do
        let(:result) do
          asset.validate({})
          asset.result[:validate]
        end
        it 'should pass validation' do
          expect(asset.ok?).to be true
        end
        it 'should not run kubeconform' do
          expect(result[:foobar]).not_to be_a(Tester::KubeconformTestOutcome)
        end
      end
      context 'with kubeconform' do
        let(:result) do
          asset.validate({ kubeconform: true, kube_versions: KUBERNETES_VERSIONS })
          asset.result[:validate]
        end
        it 'should pass validation' do
          expect(asset.ok?).to be true
        end
        it 'should have run kubeconform' do
          expect(result[:foobar]).to be_a(Tester::KubeconformTestOutcome)
        end
      end
    end
    context 'an invalid manifest' do
      let(:asset) do
        tpl = Tester::TestOutcome.new(invalid_manifest, '', 0, 'test --foo')
        asset = factory
        allow(asset).to receive(:templates).and_return({ 'foobar': tpl })
        allow(asset).to receive(:collect_fixtures).and_return({ 'foobar': nil })
        asset.validate({ kubeconform: true, kube_versions: KUBERNETES_VERSIONS })
        asset
      end
      let(:result) do
        asset.result[:validate]
      end
      it 'should contain validation errors' do
        # Please remember: until we use "result"
        # the validation won
        expect(asset.validate_errors).not_to be_empty
      end
      it 'should not pass validation' do
        expect(asset.result).not_to eq(Tester::BaseTestAsset::INIT_RESULT)
        expect(asset.ok?).to be false
      end
    end
  end

  describe '.diff' do
    def diff_fixture(orig, change)
      asset = factory
      # In python this would be: tpl = lambda what: ...
      tpl = ->(what) { Tester::TestOutcome.new(what, '', 0, 'test --foo') }

      allow(asset).to receive(:templates).and_return({ 'foobar': tpl.call(orig) })
      allow(asset).to receive(:templates).with('testdir').and_return({ 'foobar': tpl.call(change) })
      asset.diff 'testdir'
      asset
    end

    context 'no changes' do
      let(:asset) do
        diff_fixture('a string', 'a string')
      end
      it 'should have no differences' do
        expect(asset.diffs).to be_empty
        expect(asset.diffs?).to be false
      end
    end

    context 'changes' do
      let(:asset) do
        diff_fixture('a string', 'another_string')
      end
      it 'should have differences' do
        expect(asset.diffs).not_to be_empty
        expect(asset.diffs?).to be true
      end
    end
  end

  describe 'select_satisfied_versions' do
    it 'should return all versions if kube_version is nil' do
      allow(asset).to receive(:kube_version).and_return(nil)
      expect(asset.select_satisfied_versions('dummy-label', ['1.0.1' , '2.0.1'])).to eql(
        ['1.0.1' , '2.0.1']
      )
    end

    it 'should return only versions which satisfy kube_version' do
      allow(asset).to receive(:kube_version).and_return({ 'dummy-label' => '>=1.0.2'})
      expect(asset.select_satisfied_versions('dummy-label', ['1.0.1' , '2.0.1'])).to eql(
        ['2.0.1']
      )
    end
  end
end

describe Tester::ChartAsset do
  before(:all) do
    @oldpwd = Dir.pwd
    Dir.chdir(File.join(__dir__, 'fixtures/asset'))
  end

  let(:asset) do
    Tester::ChartAsset.new 'charts/test-chart1/Chart.yaml'
  end

  describe '.new' do
    it 'should contain multiple fixtures' do
      expect(asset.fixtures).not_to be_empty
    end
  end

  describe 'lint' do
    it 'a valid chart results in success' do
      cmd = 'helm lint charts/test-chart1'
      resp = Tester::TestOutcome.new('Linting charts', '', 0, cmd)
      allow(asset).to receive(:_exec).with(cmd).and_return(resp)
      asset.lint
      expect(asset.ok?).to be true
      expect(asset.result[:lint]).to be_a(Tester::TestOutcome)
    end

    it 'a non-valid chart results in failure' do
      cmd = 'helm lint charts/test-chart1'
      resp = Tester::TestOutcome.new('Linting charts', 'pinkunicorn missing!', 1, cmd)
      allow(asset).to receive(:_exec).with(cmd).and_return(resp)
      asset.lint
      expect(asset.ok?).to be false
    end
  end

  describe 'kube_version' do
    context 'chart without kubeVersion' do
      let(:asset) do
        Tester::ChartAsset.new 'charts/test-chart1/Chart.yaml'
      end
      it 'should not return a version' do
        expect(asset.kube_version).to be nil
      end
    end
    context 'chart with kubeVersion' do
      let(:asset) do
        Tester::ChartAsset.new 'charts/test-chart2/Chart.yaml'
      end
      it 'should return a version' do
        expect(asset.kube_version).to eql(
          {
            "charts/test-chart2" => ">= 1.21"
          }
        )
      end
    end
    context 'chart with kubeVersion and fixtures' do
      let(:asset) do
        Tester::ChartAsset.new 'charts/test-chart3/Chart.yaml'
      end
      it 'should return a version for each fixture' do
        expect(asset.kube_version).to eql(
          {
            "charts/test-chart3" => ">= 1.21",
            "charts/test-chart3 => fixture1" => ">= 1.21",
            "charts/test-chart3 => fixture2" => ">= 1.21",
          }
        )
      end
    end
  end

  after(:all) do
    Dir.chdir(@oldpwd)
  end
end

describe Tester::AdminAsset do
  before(:all) do
    @oldpwd = Dir.pwd
    Dir.chdir(File.join(__dir__, 'fixtures/asset'))
  end

  describe 'kube_version' do
    it 'should raise an error if kubernetesVersion is not defined' do
      stub_const("Tester::HelmfileAsset::ENV_EXPLORE", ['moon'])
      expect {
        Tester::AdminAsset.new 'helmfile.d-1/admin_ng/helmfile.yaml'
      }.to raise_error(RuntimeError, /^Required key/)
    end
  end

  describe 'kube_version' do
    it 'should return a mapping of env to Kubernetes version' do
      stub_const("Tester::HelmfileAsset::ENV_EXPLORE", ['sun'])
      asset = Tester::AdminAsset.new 'helmfile.d-2/admin_ng/helmfile.yaml'
      expect(asset.kube_version).to eql(
        {
          "helmfile.d-2/admin_ng/sun" => "1.16",
        }
      )
    end
  end

  after(:all) do
    Dir.chdir(@oldpwd)
  end
end
