#
# Author:: Maxime Liron (<maximeliron@gmail.com>)
# Copyright:: Copyright (c) 2011 Maxime Liron
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'

class Chef
  class Knife
    class GandiServerCreate < Knife

      deps do
        require 'knife-gandi'
        require 'knife-gandi/plugin_helper'
        require 'xmlrpc/client'
        require 'chef/knife/bootstrap'
        require 'resolv'
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife gandi server create (options)"

      option :memory,
        :short => "-M MEMORY",
        :long => "--memory MEMORY",
        :description => "The amount of memory (ram) of server",
        :proc => Proc.new { |f| Chef::Config[:knife][:memory] = f.to_i }
      
      option :cores,
        :short => "-C CORES",
        :long => "--cores CORES",
        :description => "The number of cores (cpu) of server",
        :proc => Proc.new { |f| Chef::Config[:knife][:cores] = f.to_i }
          
      option :bandwidth,
        :short => "-B BANDWIDTH",
        :long => "--bandwidth BANDWIDTH",
        :description => "The amount of bandwidth (network) of server (optional)",
        :proc => Proc.new { |f| Chef::Config[:knife][:bandwidth] = f.to_i }
        

      option :ip_version,
        :short => "-W VERSION",
        :long => "--ip-version VERSION",
        :description => "The version of the IP protocol",
        :proc => Proc.new { |f| Chef::Config[:knife][:ip_version] = f.to_i }

      option :image_id,
        :short => "-I IMAGE_ID",
        :long => "--image-id IMAGE_ID",
        :description => "The image id of the desired server image",
        :proc => Proc.new { |i| Chef::Config[:knife][:image_id] = i.to_i }
        
      option :disk_name,
        :short => "-H NAME",
        :long => "--disk-name NAME",
        :description => "The name of the server's system disk. default: {server name}_disk",
        :proc => Proc.new { |i| Chef::Config[:knife][:disk_name] = i }
        
      option :datacenter_id,
        :short => "-D DATACENTER_ID",
        :long => "--datacenter-id DATACENTER_ID",
        :description => "The datacenter's id in which the server will be created",
        :proc => Proc.new { |i| Chef::Config[:knife][:datacenter_id] = i.to_i }

      option :server_name,
        :short => "-S NAME",
        :long => "--server-name NAME",
        :description => "The server name"

      option :chef_node_name,
        :short => "-N NAME",
        :long => "--node-name NAME",
        :description => "The Chef node name for your new node, defaults to server name"

      option :login,
        :short => "-x USERNAME",
        :long => "--login USERNAME",
        :description => "The login for the server"

      option :password,
        :short => "-P PASSWORD",
        :long => "--password PASSWORD",
        :description => "The password for the server"

      option :gandi_api_key,
        :short => "-K KEY",
        :long => "--gandi-api-key KEY",
        :description => "Your Gandi API key",
        :proc => Proc.new { |key| Chef::Config[:knife][:gandi_api_key] = key }

      option :prerelease,
        :long => "--prerelease",
        :description => "Install the pre-release chef gems"

      option :bootstrap_version,
        :long => "--bootstrap-version VERSION",
        :description => "The version of Chef to install",
        :proc => Proc.new { |v| Chef::Config[:knife][:bootstrap_version] = v }

      option :distro,
        :short => "-d DISTRO",
        :long => "--distro DISTRO",
        :description => "Bootstrap a distro using a template",
        :proc => Proc.new { |d| Chef::Config[:knife][:distro] = d },
        :default => "ubuntu10.04-gems"

      option :use_sudo,
        :long => "--sudo",
        :description => "Execute the bootstrap via sudo",
        :boolean => true,
        :default => true

      option :template_file,
        :long => "--template-file TEMPLATE",
        :description => "Full path to location of template to use",
        :proc => Proc.new { |t| Chef::Config[:knife][:template_file] = t },
        :default => false

      option :run_list,
        :short => "-r RUN_LIST",
        :long => "--run-list RUN_LIST",
        :description => "Comma separated list of roles/recipes to apply",
        :proc => lambda { |o| o.split(/[\s,]+/) },
        :default => []
      
      attr_reader :connection, :api_key

      def run
        # Unsual to extend here but enables 'plugin_helper' to be require'd lazily (in deps)
        extend KnifeGandi::PluginHelper
        $stdout.sync = true
        
        # Necessary changes to xmlrpc's defaults, prevent warnings from showing up in prompt
        suppress_warnings do
          XMLRPC::Config.const_set(:ENABLE_NIL_PARSER, true)
          XMLRPC::Config.const_set(:ENABLE_NIL_CREATE, true)
        end
        
        # The connection used to communicate with the Gandi API throught this command invokation
        @connection = XMLRPC::Client.new2(KnifeGandi::API_ENDPOINT_URL)
        @api_key    = Chef::Config[:knife][:gandi_api_key] || config[:gandi_api_key] || raise("Please provide an API key")
        
        print "\n"
        
        # Server spec
        # Sent as a param to the Gandi API
        # For mandatory params that were not passed in through the command line, ask for them interactively
        # The code may try to validate given values but we expect the API will throw errors.
        server_spec = Hash.new
        
        # Server Name
        server_spec[:hostname]   = locate_config_value(:server_name)
        server_spec[:hostname] ||= ui.ask('Name of the server: ') do |question| 
          question.answer_type  = String
        end
        
        # CPU Cores
        server_spec[:cores]   = locate_config_value(:cores)
        server_spec[:cores] ||= ui.ask('Number of CPU cores: ') do |question|
          question.answer_type  = Integer
          question.default      = 1
          question.in           = 1..6
        end
        
        # Memory
        server_spec[:memory]   = locate_config_value(:memory)
        server_spec[:memory] ||= ui.ask('Amount of memory (MB): ') do |question|
          question.answer_type  = Integer
          question.default      = 256
          #  Make sure this is a valid memory value
          question.validate     = lambda { |ans| ans.to_i.modulo(64) == 0 }
          question.in           = 256..12288
          question.responses[:not_valid] = "Your answer isn't valid (must be a valid memory value ex: 256, 512, 2048, ...)"
        end
        
        # Network Bandwidth
        bandwidth   = locate_config_value(:bandwidth)
        bandwidth ||= ui.ask('Bandwidth (MB): ') do |question|
          question.answer_type = Integer
          question.default     = 5
        end
        server_spec[:bandwidth] = bandwidth * 1024
        
        # IP Version
        server_spec[:ip_version]   = locate_config_value(:ip_version)
        server_spec[:ip_version] ||= ui.ask('IP protocol version: ') do |question|
          question.answer_type  = Integer
          question.default      = 4
          question.in           = [4, 6]
        end
        
        # Datacenter
        # TODO: Query the API and list the datacenters inline, there is only two of them currently.
        server_spec[:datacenter_id]   = locate_config_value(:datacenter_id)
        server_spec[:datacenter_id] ||= ui.ask('Datacenter id: ') do |question|
          question.answer_type  = Integer
        end
        
        # User Name
        # WARN: The Gandi hosting platform will not allow use of 'root'
        server_spec[:login]   = locate_config_value(:login)
        server_spec[:login] ||= ui.ask('Username: ') do |question|
          question.answer_type  = String
          question.default      = 'admin'
        end
        
        # User Password
        server_spec[:password]   = locate_config_value(:password)
        server_spec[:password] ||= ui.ask('Password: ') do |question|
          question.answer_type  = String
          question.validate     = /^[ -~]{8,64}$/
        end
        
        # Server Image
        # To create a server instance, Gandi requires a disk spec of the server's system disk
        disk_spec = Hash.new
        disk_spec[:datacenter_id] = server_spec[:datacenter_id]
        disk_spec[:name] = locate_config_value(:disk_name) || "disk_#{server_spec[:hostname]}"
        
        server_image_id   = locate_config_value(:image_id)
        server_image_id ||= ui.ask('Image id (see `knife gandi image list` command output): ') do |question|
          question.answer_type = Integer
        end
        
        # Lookup the server image
        server_image = connection.call('image.info', api_key, server_image_id)

        # Create the server
        # 'vm.create_from' is a shortcut method that creates the vm, its system disk and network interface
        # in one method call. It returns three operations, one describing each create operation.
        create_operations   = connection.call('vm.create_from', api_key, server_spec, disk_spec, server_image['disk_id'])
        vm_create_operation = create_operations.find { |op| op['type'] == 'vm_create' }

        print "\n"
        print ui.color("Creating the server.", :magenta)
        
        # Wait for it to be created to do stuff...
        until_done(vm_create_operation) { print '.' }
        
        # Server is created, now get its specs
        server = connection.call('vm.info', api_key, vm_create_operation['vm_id'])
        # Server's public IP resource representation (IP address, reverse dns, ...). See Gandi API docs
        public_ip_info = ip_objects_of(server, :type => 'public', :version => server_spec[:ip_version]).first
        
        
        puts "\n"
        puts "#{ui.color("Public DNS Name", :cyan)}: #{public_ip_info['reverse']}"
        puts "#{ui.color("Public IP Address", :cyan)}: #{public_ip_info['ip']}"
        puts "#{ui.color("Password", :cyan)}: #{server_spec[:password]}"

        print "\n"
        print ui.color("Waiting for sshd.", :magenta)

        print(".") until tcp_test_ssh(public_ip_info['reverse']) { sleep @initial_sleep_delay ||= 10; puts("done") }
        
        # Now that we have SSH access, bootstrap Chef on the server 
        # and hand over control to the Chef infrastructure
        bootstrap_for_node(server_spec, server, public_ip_info['reverse']).run

        puts "\n"
        puts "#{ui.color("Instance ID", :cyan)}: #{server['id']}"
        puts "#{ui.color("Name", :cyan)}: #{server['hostname']}"
        puts "#{ui.color("Memory", :cyan)}: #{server['memory']}"
        puts "#{ui.color("Cores", :cyan)}: #{server['cores']}"
        puts "#{ui.color("Image", :cyan)}: #{server_image['label']}"
        puts "#{ui.color("Public DNS Name", :cyan)}: #{public_ip_info['reverse']}"
        puts "#{ui.color("Public IP Address", :cyan)}: #{public_ip_info['ip']}"
        puts "#{ui.color("Password", :cyan)}: #{server_spec[:password]}"
        puts "#{ui.color("Environment", :cyan)}: #{config[:environment] || '_default'}"
        puts "#{ui.color("Run List", :cyan)}: #{config[:run_list].join(', ')}"
      end
      
      # Test if an SSH deamon is listening.
      # AKA: is my server up and running?
      def tcp_test_ssh(hostname)
        tcp_socket = TCPSocket.new(hostname, 22)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
          yield
          true
        else
          false
        end
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::ECONNREFUSED
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end

      def bootstrap_for_node(server_spec, server, fqdn)
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [fqdn]
        bootstrap.config[:run_list] = config[:run_list]
        bootstrap.config[:ssh_user] = 'root'
        bootstrap.config[:ssh_password] = server_spec[:password]
        bootstrap.config[:identity_file] = config[:identity_file]
        bootstrap.config[:chef_node_name] = server[:chef_node_name] || "#{server['hostname']}_gandi-#{server['id']}"
        bootstrap.config[:prerelease] = config[:prerelease]
        bootstrap.config[:bootstrap_version] = locate_config_value(:bootstrap_version)
        bootstrap.config[:distro] = locate_config_value(:distro)
        # bootstrap will run as root...sudo (by default) also messes up Ohai on CentOS boxes
        bootstrap.config[:use_sudo] = config[:use_sudo]
        bootstrap.config[:template_file] = locate_config_value(:template_file)
        bootstrap.config[:environment] = config[:environment]
        bootstrap
      end
    end
  end
end
