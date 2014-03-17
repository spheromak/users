require 'chefspec'
require 'chefspec/server'

require_relative '../../libraries/user.rb'

describe 'in_passwd?' do
  let(:passwd) do
    "root:x:0:0:root:/root:/bin/bash\n
     daemon:x:1:1:daemon:/usr/sbin:/bin/sh\n
     bin:x:2:2:bin:/bin:/bin/sh\n"
  end

  before(:each) do
    File.stub(:read).and_return(passwd)
  end

  it 'should return true if user exists' do
    expect(KTC::User.in_passwd?('daemon')).to be true
  end

  it 'should return false if user does not exist' do
    expect(KTC::User.in_passwd?('bob_is_not_here')).to be false
  end
end

describe 'in_group?' do
  let(:group) do
    "root:x:0:\n
     daemon:x:1:\n
     bin:x:2:\n"
  end

  before(:each) do
    File.stub(:read).and_return(group)
  end

  it 'should return true if group exists' do
    expect(KTC::User.in_group?('daemon')).to be true
  end

  it 'should return false if group does not exist' do
    expect(KTC::User.in_group?('bobs_group_is_not_here')).to be false
  end
end

describe 'get_user' do
  let(:fred) do
    {
      id: 'fred',
      groups: %w/wheel/,
      uid: 10_001,
      gid: 'users',
      status: 'create'
    }
  end

  let(:bob) do
    {
      id: 'bob',
      groups: %w/wheel/,
      uid: 10_002,
      gid: 'users',
      status: 'create'
    }
  end

  before(:each) do
    ChefSpec::Server.create_data_bag('users',
                                     fred: fred, bob: bob
    )
    stub_search(:users, 'status:remov').and_return([])
    stub_search(:groups, 'status:remov').and_return([])
  end

  it 'should return the same user databag passed to it' do
    #KTC::User.node = chef_run.node
    expect(KTC::User.get_user(fred)).to eq fred
  end

  let(:chef_run) { ChefSpec::Runner.new(cookbook_path: '/Users/wil/repos') }

  it 'should return user from data bag if cache is false' do
    # chef_run.converge('users::default')
    # chef_run.node.run_state[:helper_cache] = {}
    # chef_run.node.run_state[:helper_cache][:all_users] = [fred]
    # chef_run.node.run_state[:helper_cache][:all_users][0]['uid'] = '10_003'
    # KTC::User.node = chef_run.node
    # expect(KTC::User.get_user('fred', false)['uid']).to eq '10_001'
    true
  end

  it 'should return a cached user if it exists' do
    true
  end

  it 'should return user from data bag if not cached' do
    true
  end
end
