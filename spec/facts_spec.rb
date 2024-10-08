require 'spec_helper'
require 'digest'
require 'pathname'

RSpec::Matchers.define :have_a_unique_hash do
  match do |actual|
    actual.count == 1
  end

  failure_message do |actual|
    "expected that fact files #{actual.join(', ')} would be unique"
  end
end

RSpec::Matchers.define :be_valid_json do
  match do |actual|
    content = File.binread(actual)
    valid = false
    begin
      obj = JSON.parse(content)
      valid = true
    rescue JSON::ParserError => e
      raise "Invalid JSON file #{actual}.\n#{e}"
    end
  end

  failure_message do |actual|
    "expected that fact file #{actual} was a valid JSON file."
  end
end

RSpec::Matchers.define :have_facter_version do |expected_facter_version, filepath|
  match do |actual|
    # Simple but naive regex check
    actual =~ /^#{expected_facter_version}($|\.)/
  end

  failure_message do |actual|
    "expected that fact file #{filepath} with facter version #{actual} had a facter version that matched #{expected_facter_version}"
  end
end

describe 'Default Facts' do
  before do
    ENV['FACTERDB_SKIP_DEFAULTDB'] = nil
    FacterDB.instance_variable_set(:@database, nil)
  end

  describe 'fact files' do
    it 'does not contain duplicate fact sets' do
      # Gather all of the default files and hash the content
      file_hashes = {}
      FacterDB.default_fact_files.each do |filepath|
        file_hash = Digest::SHA256.hexdigest(File.binread(filepath))
        file_hashes[file_hash] ||= []
        file_hashes[file_hash] << filepath
      end

      file_hashes.keys.each do |file_hash|
        expect(file_hashes[file_hash]).to have_a_unique_hash
      end
    end
  end

  project_dir = Pathname.new(__dir__).parent
  FacterDB.default_fact_files.each do |filepath|
    relative_path = Pathname.new(filepath).relative_path_from(project_dir).to_s
    describe relative_path do
      subject(:content) do
        JSON.parse(File.binread(filepath))
      end

      it 'contains a valid JSON document' do
        expect(filepath).to be_valid_json
      end

      it 'contains a fact set which matches the facter version' do
        facter_dir_path = File.basename(File.dirname(filepath))

        expect(content['facterversion']).to have_facter_version(facter_dir_path, filepath)
      end

      # when facts are generated with distro facter or rubygems facter the augeas bindings might be missing
      # we need to ensure they exist
      it 'contains the augeas.version fact' do
        if content['kernel'] == 'Linux'
          expect(content['augeas']['version']).to not_be_nil.and not_be_empty
        end
      end

      it 'contains newer networking facts hash' do
        expect(content['networking']['ip']).to not_be_nil.and not_be_empty
        expect(content['networking']['ip6']).to not_be_nil.and not_be_empty
        expect(content['networking']['hostname']).to eq('foo')
        expect(content['networking']['domain']).to eq('example.com')
        expect(content['networking']['fqdn']).to eq('foo.example.com')
      end

      it 'does not contains the legacy ipaddress fact' do
        expect(content['ipaddress']).to be_nil
      end

      it 'contains no facts from puppetlabs/stdlib' do
        expect(content['root_home']).to be_nil
        expect(content['service_provider']).to be_nil
        expect(content['puppet_vardir']).to be_nil
        expect(content['puppet_environmentpath']).to be_nil
        expect(content['puppet_server']).to be_nil
        expect(content['pe_version']).to be_nil
        expect(content['package_provider']).to be_nil
        expect(content['is_pe']).to be_nil
        expect(content['pe_major_version']).to be_nil
        expect(content['pe_minor_version']).to be_nil
        expect(content['pe_patch_version']).to be_nil
      end

      it 'contains no facts from puppetlabs/puppet_agent' do
        expect(content['env_temp_variable']).to be_nil
        expect(content['puppet_agent_appdata']).to be_nil
        expect(content['puppet_agent_pid']).to be_nil
        expect(content['puppet_runmode']).to be_nil
        expect(content['puppet_ssldir']).to be_nil
        expect(content['puppet_digest_algorithm']).to be_nil
        expect(content['puppet_config']).to be_nil
        expect(content['puppet_stringify_facts']).to be_nil
        expect(content['puppet_sslpaths']).to be_nil
        expect(content['puppet_master_server']).to be_nil
        expect(content['puppet_confdir']).to be_nil
        expect(content['puppet_client_datadir']).to be_nil
      end

      it 'contains no facts from puppet/systemd' do
        expect(content['systemd']).to be_nil
        expect(content['systemd_version']).to be_nil
        expect(content['systemd_internal_services']).to be_nil
      end

      # those are used in newer rspec-puppet-facts versions
      # by ensuring those facts exists, we can drop a huge amount of logic in rspec-puppet-facts
      it 'contains the mandatory OS facts' do
        expect(content['os']['release']['major']).to not_be_nil.and not_be_empty
        expect(content['os']['name']).to not_be_nil.and not_be_empty
        expect(content['os']['hardware']).to not_be_nil.and not_be_empty
      end

      it 'does not contain a legacy hostname, domain and fqdn fact' do
        expect(content['hostname']).to be_nil
        expect(content['fqdn']).to be_nil
        expect(content['domain']).to be_nil
      end

      it 'does not contain the legacy osfamily fact' do
        expect(content['osfamily']).to be_nil
      end

      it 'does not contain the legacy operatingsystem fact' do
        expect(content['operatingsystem']).to be_nil
      end

      # those facts aren't default in Open Source Puppet/Facter core
      it 'does not contain the PE facts' do
        expect(content['pe_patch']).to be_nil
        expect(content['puppet_inventory_metadata']).to be_nil
      end

      it 'does not contain random facts from known modules' do
        expect(content['selinux_python_command']).to be_nil
        expect(content['mysql_server_id']).to be_nil
        expect(content['stage']).to be_nil
        expect(content['virt_libvirt']).to be_nil
        expect(content['function_number']).to be_nil
        expect(content['classification']).to be_nil
        expect(content['who2bug']).to be_nil
        expect(content['prometheus_alert_manager_running']).to be_nil
        expect(content['docker_home_dirs']).to be_nil
        expect(content['aio_agent_build']).to be_nil
        expect(content['python2_version']).to be_nil
        expect(content['python_version']).to be_nil
        expect(content['puppet_agent_pid']).to be_nil
      end
    end
  end
end
