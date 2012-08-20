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
end
