require 'tmpdir'

require File.join(File.dirname(__FILE__),'..','/lib/vagrant-hitch')
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
      thisdir = File.dirname(__FILE__)
      vagrantfile = <<-HERE.gsub(/^ {6}/, '')
        require '#{thisdir}/../lib/vagrant_init.rb'
        Vagrant::Config.run &VagrantHitch.up!(File.join(File.dirname(__FILE__),'..','example','config'))
      HERE
      # create new Vagrantfile in ../tmp
      File.open(File.join(thisdir,"../tmp/Vagrantfile"), "w") {|f| f.write(vagrantfile) }
      Dir.chdir(File.join(thisdir,"../tmp"))
    end

    # clean up the temporary directory
    after(:all) do
    end

    it 'should not include the default node information' do
      output = Array.new
      IO.popen("vagrant status") { |io|
        output = io.readlines.collect { |l| l.chomp }
      }
      output.should include("test1                    not created","test2                    not created")
      output.should_not include("default                  not created")
    end
  end
end
