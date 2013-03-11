require 'yaml'
require 'vagrant'
require 'backports'
require 'deep_merge'

module VagrantHitch
  def self.validate(cfdir)
    unless File.exist?(cfdir) && File.directory?(cfdir)
      puts "The directory #{cfdir} is not valid"
      exit
    end
  end

  def self.setup_dns(profile, node_config, config)
    # Vagrant-DNS Support
    if node_config['dns']
      if node_config['dns']['tld']
        config.dns.tld = node_config['dns']['tld']
      end

      if node_config['dns']['patterns']
        config.dns.patterns = node_config['dns']['patterns']
      end
    end
  end

  def self.setup_vbox(profile, node_config, config)
    config.vm.box = node_config['vbox']
    config.vm.box_url = node_config['vbox_url']
  end

  def self.setup_hostname(profile, node_config, config)
    # Setup VBox
    # Configure Hostname
    hostname = node_config.has_key?('orgname') ? "#{profile.to_s}.#{node_config['orgname']}" : "#{profile.to_s}.vagrant"
    config.vm.host_name = hostname
  end

  def self.setup_bootmode(profiile, node_config, config)
    if node_config.has_key?('boot_mode')
      config.vm.boot_mode = node_config['boot_mode'].to_sym
    end
  end

  def self.setup_cpu(profile, node_config, config)
    # Configure CPU
    config.vm.customize ["modifyvm", :id, "--cpus", node_config['cpu_count'].to_s] if node_config.has_key?('cpu_count')
  end

  def self.setup_memory(profile, node_config, config)
    # Configure Memory
    config.vm.customize ["modifyvm", :id, "--memory", node_config['memory_size'].to_s] if node_config.has_key?('memory_size')
  end

  def self.setup_network(profile, node_config, config)
    # Configure Network
    if node_config.has_key?('ip')
      netmask = node_config.has_key?('netmask') ? node_config['netmask'] : '255.255.255.0'
      config.vm.network :hostonly, node_config['ip'], :netmask => netmask
    end
  end

  def self.setup_guest(profile, node_config, config)
    if node_config.has_key?('guest')
      config.vm.guest = node_config['guest'].to_sym
    end
  end

  def self.setup_ports(profile, node_config, config)
    # Configure any host-based port forwards
    if node_config.has_key?('ports')
      node_config['ports'].each { |k,v| config.vm.forward_port(v['guest'], v['host']) }
    end
  end

  def self.setup_winrm(profile, node_config, config)
    # WinRM specific Configuration
    if node_config.has_key?('winrm')
      config.winrm.username = node_config['winrm']['username']
      config.winrm.password = node_config['winrm']['password']
      config.winrm.timeout = node_config['winrm']['timeout'] || 1800
    end
  end

  def self.setup_mounts(profile, node_config, config)
    # custom mounts
    if node_config.has_key?('mounts')
      node_config['mounts'].each { |desc, mount| config.vm.share_folder("#{desc}","#{mount['guest']}","#{mount['host']}", :create => 'true', :owner => mount.has_key?('owner') ? mount['owner'] : 'vagrant') }
    end
  end

  def self.setup_provisioners(profile, node_config, config, config_dir)
    # Setup Shell provisioner
    if node_config.has_key?('shell')
      node_config.deep_merge(@shell_provisioner_defaults) if !@shell_provisioner_defaults.nil?
      config.vm.provision :shell do |shell|
        shell.inline = node_config['shell']['inline'] if node_config['shell'].has_key?('inline')
        shell.args   = node_config['shell']['args'] if node_config['shell'].has_key?('args')
        shell.path   = node_config['shell']['path'] if node_config['shell'].has_key?('path')
      end
    end

    # Setup Puppet Provisioner
    if node_config.has_key?('puppet')
      # Import any defaults set by the Puppet Provisioner
      node_config.deep_merge(@puppet_provisioner_defaults) if !@puppet_provisioner_defaults.nil?

      config.vm.provision :puppet do |puppet|
        puppet.module_path    = node_config['puppet']['modules']
        puppet.manifests_path = node_config['puppet']['manifests_path']
        puppet.manifest_file  =
          node_config['puppet'].has_key?('manifest_file') ? node_config['puppet']['manifest_file'] : "#{profile.to_s}.pp"

        # Setup Puppet Graphing
        if node_config['puppet']['options'].include?('--graph')
          begin
            graph_dir = File.join(config_dir,'..','graph')
            [graph_dir, "#{graph_dir}/#{config.vm.host_name}"].each { |d| Dir.mkdir(d) if !File.directory?(d) }
            node_config['puppet']['options'] << "--graphdir=/vagrant/graph/#{config.vm.host_name}"
          rescue => e
            puts "Unable to create Puppet Graph Directory: #{e}"
          end
        end

        # Puppet Options must be the last option to ensure any additions are included
        puppet.options = node_config['puppet']['options'].join(' ')
      end
    end

    # Setup Chef Provisioner
    if node_config.has_key?('chef')
      # Import any defaults set by the Chef Provisioner
      node_config.deep_merge(@chef_provisioner_defaults) if !@chef_provisioner_defaults.nil?

      config.vm.provision :chef_solo do |chef|
        chef.log_level      = node_config['chef']['log_level'].to_sym
        chef.cookbooks_path = node_config['chef']['cookbooks_path']
        chef.roles_path     = node_config['chef']['roles_path']
        chef.data_bags_path = node_config['chef']['data_bags_path']
        node_config['chef']['roles'].each { |role| chef.add_role(role) }
      end
    end

    # Setup Puppet Server Provisioner
    if node_config.has_key?('puppet_server')
      # Import any defaults set by the Puppet Server Provisioner
      node_config.deep_merge(@puppet_server_provisioner_defaults) if !@puppet_server_provisioner_defaults.nil?

      config.vm.provision :puppet_server do |puppet|
        puppet.puppet_server = node_config['puppet_server']['server']
        puppet.puppet_node = config.vm.host_name

        # Setup Puppet Graphing
        if node_config['puppet_server']['options'].include?('--graph')
          begin
            graph_dir = File.join(config_dir,'..','graph')
            [graph_dir, "#{graph_dir}/#{config.vm.host_name}"].each { |d| Dir.mkdir(d) if !File.directory?(d) }
            node_config['puppet_server']['options'] << "--graphdir=/vagrant/graph/#{config.vm.host_name}"
          rescue => e
            puts "Unable to create Puppet Graph Directory: #{e}"
          end
        end

        # Puppet Options must be the last option to ensure any additions are included
        puppet.options = node_config['puppet_server']['options'].join(' ')
      end
    end

  end

  def self.configure_node(profile, node_config, config, config_dir)
    # Bail out if it is one of our special 'ignore' config blocks
    config.vm.define profile do |config|
      # Setup the environment
      self.setup_dns(profile, node_config, config)
      self.setup_vbox(profile, node_config, config)
      self.setup_bootmode(profile, node_config, config)

      # set up the server
      self.setup_hostname(profile, node_config, config)
      self.setup_cpu(profile, node_config, config)
      self.setup_memory(profile, node_config, config)
      self.setup_network(profile, node_config, config)
      self.setup_guest(profile, node_config, config)
      self.setup_winrm(profile, node_config, config)

      # set up the integrations
      self.setup_ports(profile, node_config, config)
      self.setup_mounts(profile, node_config, config)

      # set up the provisioners
      self.setup_provisioners(profile, node_config, config, config_dir)
    end
  end

  def self.up!(cfdir)
    self.validate(cfdir)
    return lambda do |config_dir, config|
      #Load up Config Files
      begin
        profiles = YAML::load_file(File.join(config_dir,'nodes.yml'))

        ['shell','chef','puppet','puppet_server'].each do |type|
          if File.exists?(File.join(config_dir, "provisioner_#{type}.yml"))
            provisioner_data = YAML::load_file(File.join(config_dir, "provisioner_#{type}.yml"))
            instance_variable_set("@" + type + "_provisioner_defaults", provisioner_data)
          end
        end
      rescue => e
        puts "Your config file is missing. Please create the 'nodes.yml' file in the config directory: #{e}"
        exit
      end

      # Ignore any and all YAML blocks with "default" in the key name
      # Typically, this should be used for any YAML anchors
      # that may be reused for other Vagrantbox definitions
      ignore_config = ['default']
      profiles.delete_if do |p, c|
        true if ignore_config.find_index { |ignore_key| p.include?(ignore_key) }
      end

      # Set up each profile
      profiles.each do |profile, node_config|
        self.configure_node(profile, node_config, config, config_dir)
      end
    end.curry[cfdir]
  end
end
