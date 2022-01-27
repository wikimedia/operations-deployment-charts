# frozen_string_literal: true

require_relative '../tester/asset'
require_relative '../utils'
require 'rake'

kubeyaml = which('kubeyaml').nil?

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
      it 'should not run when marked bad, and be not ok' do
        asset.bad('msg', 'cmd')
        expect(asset.should_run?).to be false
        expect(asset.ok?).to be false
      end
    end
    context 'when void' do
      let(:asset) { factory nil }
      it 'should run' do
        expect(asset.should_run?).to be true
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
        expect(outcome.out).to be_empty
      end

      it 'should have no error' do
        expect(outcome.err).to be_empty
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
        expect(outcome.out).to be_empty
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
  describe 'validate_kubeyaml', unless: kubeyaml do
    context 'when the output contains multiple valid documents' do
      let(:results) do
        input = Tester::TestOutcome.new(valid_manifest, '', 0, 'foobar')
        asset.validate_kubeyaml(input, '1.19')
      end

      it 'should be ok' do
        expect(results.ok?).to eq(true)
      end
      it 'should have no errors' do
        expect(results.err).to be_empty
      end
      it 'should have scanned the whole document' do
        # The fixture contains 7 docs, one of which empty
        # But we only have 5 valid sources
        expect(results.outcomes.values.count).to eq(5)
        # OTOH, we have 6 total validations that happened:
        expect(results.outcomes.values.flatten.count).to eq(6)
      end
    end
    context 'when the output has invalid documents' do
      let(:results) do
        input = Tester::TestOutcome.new(invalid_manifest, '', 0, 'foobar')
        asset.validate_kubeyaml(input, '1.19')
      end

      it 'should not be ok' do
        expect(results.ok?).to eq(false)
      end
      it 'should contain 3 errors' do
        expect(results.err.keys).to(
          contain_exactly(
            'foobar/templates/deployment.yaml[0]',
            'foobar/templates/configmap.yaml[0]',
            'foobar/templates/configmap.yaml[1]'
          )
        )
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
      context 'without kubeyaml' do
        let(:result) do
          asset.validate({})
          asset.result[:validate]
        end
        it 'should pass validation' do
          expect(asset.ok?).to be true
        end
        it 'should not run kubeyaml' do
          expect(result[:foobar]).not_to be_a(Tester::KubeyamlTestOutcome)
        end
      end
      context 'with kubeyaml' do
        let(:result) do
          asset.validate({ kubeyaml: true, kube_versions: '1.19' })
          asset.result[:validate]
        end
        it 'should pass validation' do
          expect(asset.ok?).to be true
        end
        it 'should have run kubeyaml' do
          expect(result[:foobar]).to be_a(Tester::KubeyamlTestOutcome)
        end
      end
    end
    context 'an invalid manifest' do
      let(:asset) do
        tpl = Tester::TestOutcome.new(invalid_manifest, '', 0, 'test --foo')
        asset = factory
        allow(asset).to receive(:templates).and_return({ 'foobar': tpl })
        allow(asset).to receive(:collect_fixtures).and_return({ 'foobar': nil })
        asset.validate({ kubeyaml: true, kube_versions: '1.19' })
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
end

describe Tester::ChartAsset do
  let(:asset) do
    Tester::ChartAsset.new 'charts/mediawiki/Charts.yaml'
  end

  describe '.new' do
    it 'should contain multiple fixtures' do
      expect(asset.fixtures).not_to be_empty
    end
  end

  describe 'lint' do
    it 'a valid chart results in success' do
      cmd = 'helm lint charts/mediawiki'
      resp = Tester::TestOutcome.new('Linting charts', '', 0, cmd)
      allow(asset).to receive(:_exec).with(cmd).and_return(resp)
      asset.lint
      expect(asset.ok?).to be true
      expect(asset.result[:lint]).to be_a(Tester::TestOutcome)
    end

    it 'a non-valid chart results in failure' do
      cmd = 'helm lint charts/mediawiki'
      resp = Tester::TestOutcome.new('Linting charts', 'pinkunicorn missing!', 1, cmd)
      allow(asset).to receive(:_exec).with(cmd).and_return(resp)
      asset.lint
      expect(asset.ok?).to be false
    end
  end
end
