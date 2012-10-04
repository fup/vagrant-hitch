require 'yaml'
require 'vagrant'
require File.join(File.dirname(__FILE__),'deep_merge')

module VagrantHitch
  def self.validate(cfdir)
    unless Dir.exist?(cfdir)
      puts "The directory #{cfdir} is not valid"
      exit
    end
  end

  def self.up!(cfdir)
    self.validate(cfdir)

    return lambda do |config_dir, config|
      #Load up Config Files
      begin
        profiles = YAML::load_file(File.join(config_dir,'nodes.yml'))

        ['chef', 'puppet', 'puppet_server'].each do |type|
          if File.exists?(File.join(config_dir, "provisioner_#{type}.yml"))
            provisioner_data = YAML::load_file(File.join(config_dir, "provisioner_#{type}.yml"))
            instance_variable_set("@" + type + "_provisioner_defaults", provisioner_data)
          end
        end
      rescue => e
        puts "Your config file is missing. Please create the 'nodes.yml' file in the config directory: #{e}"
        exit
      end

      # Ignore any and all YAML blocks with these keys.
      # Typically, this should be used for any YAML anchors
      # that may be reused for other Vagrantbox definitions
      ignore_config = ['default']
      ignore_config.each { |ignore_key| profiles.delete(ignore_key) }

      profiles.each do |profile, node_config|
        # Bail out if it is one of our special 'ignore' config blocks
        config.vm.define profile do |config|
          # Setup VBox
          config.vm.box = node_config['vbox']
          config.vm.box_url = node_config['vbox_url']

          # Configure Hostname
          if node_config.has_key?('hostname')
            config.vm.host_name = node_config['hostname']
          end

          if node_config.has_key?('guest')
            config.vm.guest = node_config['guest']
          end

          # WinRM specific Configuration
          if node_config.has_key?('winrm')
            config.winrm.username = node_config['winrm']['username']
            config.winrm.password = node_config['winrm']['password']
            config.winrm.timeout = node_config['winrm']['timeout'] || 1800
          end

          # Configure memory and CPU
          config.vm.customize ["modifyvm", :id, "--memory", node_config['memory_size'].to_s] if node_config.has_key?('memory_size')
          config.vm.customize ["modifyvm", :id, "--cpus", node_config['cpu_count'].to_s] if node_config.has_key?('cpu_count')

          # Configure Network
          if node_config.has_key?('ip')
            netmask = node_config.has_key?('netmask') ? node_config['netmask'] : '255.255.255.0'
            config.vm.network :hostonly, node_config['ip'], :netmask => netmask
          end

          # Configure any host-based port forwards
          if node_config.has_key?('ports')
            node_config['ports'].each { |k,v| config.vm.forward_port(v['guest'], v['host']) }
          end

          # custom mounts
          if node_config.has_key?('mounts')
            node_config['mounts'].each { |desc, mount| config.vm.share_folder("#{desc}","#{mount['guest']}","#{mount['host']}", :create => 'true', :owner => mount.has_key?('owner') ? mount['owner'] : 'vagrant') }
          end

          # Setup Puppet Provisioner
          if node_config.has_key?('puppet')
            # Import any defaults set by the Puppet Provisioner
            node_config.deep_merge!(@puppet_provisioner_defaults) if !@puppet_provisioner_defaults.nil?

            config.vm.provision :puppet do |puppet|
              puppet.module_path    = node_config['puppet']['modules']
              puppet.manifests_path = node_config['puppet']['manifests_path']
              puppet.manifest_file  =
                node_config['puppet'].has_key?('manifest_file') ? node_config['puppet']['manifest_file'] : "#{profile.to_s}.pp"

              # Setup Puppet Graphing
              if node_config['puppet']['options'].include?('--graph')
                begin
                  graph_dir = File.join(config_dir,'..','graph')
                  [graph_dir, "#{graph_dir}/#{host_name}"].each { |d| Dir.mkdir(d) if !File.directory?(d) }
                  node_config['puppet']['options'] << "--graphdir=/vagrant/graph/#{host_name}"
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
            node_config.deep_merge!(@chef_provisioner_defaults) if !@chef_provisioner_defaults.nil?

            config.vm.provision :chef_solo do |chef|
              chef.log_level      = node_config['chef']['log_level'].to_sym
              chef.cookbooks_path = node_config['chef']['cookbooks_path']
              chef.roles_path     = node_config['chef']['roles_path']
              chef.data_bags_path = node_config['chef']['data_bags_path']
              node_config['chef']['roles'].each { |role| chef.add_role(role) }
            end
          end
        end
      end
    end.curry[cfdir]
  end
end


