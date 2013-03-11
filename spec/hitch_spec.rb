require 'tmpdir'

require File.join(File.dirname(__FILE__),'..','/lib/vagrant-hitch')
describe 'Hash' do
  let(:a) { {:string => "a", :array => [ 0,1,2 ], :hash => { :one => '1', :two => '2' } } }
  let(:b) { {:string => "b", :array => [ 3,4,5 ], :hash => { :three => '3', :four => '4' } } }
  let(:ab) { {:string => "a", :array => [0,1,2,3,4,5 ], :hash => {:one => '1', :two => '2', :three => '3', :four => '4' } } }

  it 'Hashes should have deep merge available' do
    a.should respond_to(:deep_merge)
    a.should respond_to(:deep_merge!)
  end

  it 'merges should work as expected' do
    a.deep_merge(b).should eql(ab)
  end
end

describe VagrantHitch do
  it 'should return a proc' do
    VagrantHitch.up!('.').should be_a(Proc)
  end

  it 'should require an argument' do
    expect { VagrantHitch.up! }.to raise_error
  end

  it 'should require a valid configuration path' do
    expect { VagrantHitch.up!('somepath') }.to raise_error
  end


  context "with a valid Vagrantfile" do
    # set up Vagrantfile
    before(:all) do
      rootdir = File.join(File.dirname(__FILE__),'..')
      @tempdir = Dir.tmpdir
      vagrantfile = <<-HERE.gsub(/^ {6}/, '')
        require '#{rootdir}/lib/vagrant_init.rb'
        Vagrant::Config.run &VagrantHitch.up!(File.join('#{rootdir}','example','config'))
      HERE
      # create new Vagrantfile in ../tmp
      File.open(File.join(@tempdir,"Vagrantfile"), "w") {|f| f.write(vagrantfile) }
      Dir.chdir(@tempdir)
    end

    # clean up the temporary directory
    after(:all) do
    end

    context 'single vagrant box configuration' do
      let(:vagrant_env) { ::Vagrant::Environment.new(:cwd => @tempdir) }
      let(:test1) { vagrant_env.vms[:test1] }
      let(:test2) { vagrant_env.vms[:test2] }

      it 'should configure cpu' do
        test1.config.vm.customizations.should include(["modifyvm", :id, "--cpus", "2"])
      end

      it 'should configure memory' do
        test1.config.vm.customizations.should include(["modifyvm", :id, "--memory", "512"])
      end

      it 'should have a hostname' do
        test1.config.vm.host_name.should eql("test1.vagrant.test")
      end

      it 'should have a network' do
        test1.config.vm.networks.should include([:hostonly, ["10.10.10.10", {:netmask=>"255.255.255.0"}]])
      end

      it 'should have dns' do
        pending("what does config.dns.tld and config.dns.patterns provide?")
      end

      it 'should have a provisioner' do
        test1.config.vm.provisioners.first.provisioner.should eql(Vagrant::Provisioners::Puppet)
      end

      it 'should configure a guest' do
        test1.config.vm.guest.should eql(:solaris)
      end

      it 'should have network ports forward' do
        test1.config.vm.forwarded_ports.should include({:name=>"ssh", :guestport=>22,
                                                                                :hostport=>2222, :protocol=>:tcp,
                                                                                :adapter=>1, :auto=>true})
      end

      it 'should mounted folders' do
        test1.config.vm.shared_folders.should have(3).items
        test1.config.vm.shared_folders.should include(
          "webapp"=> {:guestpath=>"/opt/www/", :hostpath=>"./", :create=>"true",
                      :owner=>"vagrant", :group=>nil, :nfs=>false,
                      :transient=>false, :extra=>nil},
          "database"=> {:guestpath=>"/opt/mysql/database", :hostpath=>"./",
                      :create=>"true", :owner=>"vagrant", :group=>nil,
                      :nfs=>false, :transient=>false, :extra=>nil},
          "v-root"=> {:guestpath=>"/vagrant", :hostpath=>".", :create=>false, :owner=>nil, :group=>nil, :nfs=>false,
                      :transient=>false, :extra=>nil}
          )
      end
    end

    context 'property merging' do
      let(:vagrant_env) { ::Vagrant::Environment.new(:cwd => @tempdir) }
      let(:test1) { vagrant_env.vms[:test1] }
      let(:test2) { vagrant_env.vms[:test2] }

      it 'should create a vagrant environment' do
        vagrant_env.should_not be_nil
      end

      it 'should merge the default mounts properly' do
        pending "this feature either uses YAML anchors or code-based 'default' merge"
        #vagrant_env.vms_ordered.first.config.vm.shared_folders.should have(3).items
      end

      it 'should merge the default provisioner settings properly' do
        puppet_provisioner = test1.config.vm.provisioners.first
        puppet_provisioner.provisioner.should eql(Vagrant::Provisioners::Puppet)
        puppet_provisioner.config.module_path.should have(2).items
        puppet_provisioner.config.manifests_path.should eql("../manifests")
        puppet_provisioner.config.manifest_file.should eql("test1.pp")
      end

      it 'should configure multiple provisioners' do
        test2.config.vm.provisioners.should have(2).items
      end
    end

    it 'should not include the default node information' do
      output = Array.new
      # should this be fixed to test the environment instead of output from a piped command?
      IO.popen("vagrant status") { |io| output = io.readlines.collect { |l| l.chomp } }
      output.should include("test1                    not created","test2                    not created")
      output.should_not include("default                  not created")
    end
  end
end
