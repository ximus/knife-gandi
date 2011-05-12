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
    class GandiServerDelete < Knife
      
      deps do
        require 'knife-gandi'
        require 'knife-gandi/plugin_helper'
        require 'xmlrpc/client'
      end
      
      banner "knife gandi server delete SERVER_ID (options)"

      option :gandi_api_key,
        :short => "-K KEY",
        :long => "--gandi-api-key KEY",
        :description => "Your Gandi API key",
        :proc => Proc.new { |key| Chef::Config[:knife][:gandi_api_key] = key }

      attr_reader :connection, :api_key
        
      def run
        # Unsual to extend here but enables 'plugin_helper' to be require'd lazily
        extend KnifeGandi::PluginHelper
        $stdout.sync = true
        
        # Necessary changes to xmlrpc's defaults, prevent warnings from showing up in prompt
        suppress_warnings do
          XMLRPC::Config.const_set(:ENABLE_NIL_PARSER, true)
          XMLRPC::Config.const_set(:ENABLE_NIL_CREATE, true)
        end
        
        @connection = XMLRPC::Client.new2(KnifeGandi::API_ENDPOINT_URL)
        @api_key    = Chef::Config[:knife][:gandi_api_key] || config[:gandi_api_key] || raise("Please provide an API key")
        
        server = connection.call('vm.info', api_key, @name_args[0].to_i)
        
        puts "\n"
        puts "#{ui.color("Server ID", :cyan)}: #{server['id']}"
        puts "#{ui.color("Name", :cyan)}: #{ui.color(server['hostname'], :bold)}"
        puts "#{ui.color("Description", :cyan)}: #{server['description']}" if server['description']
        puts "#{ui.color("Memory", :cyan)}: #{server['memory']}"
        puts "#{ui.color("Cores", :cyan)}: #{server['cores']}"
        puts "#{ui.color("Datacenter ID", :cyan)}: #{server['datacenter_id']}"
        puts "#{ui.color("Image", :cyan)}: #{server['disks'].find{ |disk| disk['is_boot_disk'] }['label']}"
        puts "#{ui.color("State", :cyan)}: #{server['state']}"
        
        raise "This server is being created, wait for this to end and try again" if server['state'] == 'being_created'

        puts "\n"
        puts "==============================================="
        confirm("Do you really want to delete this server?")
        
        # Stop the server, the API requires a server to be halted before it can be deleted
        unless (server['state'] == 'halted')
          puts "\n"
          print ui.color("Stopping server.", :magenta)
          halt_operation = connection.call('vm.stop', api_key, server['id'])
          until_done(halt_operation) { print '.' }
        end
        
        vm_delete_operation = connection.call('vm.delete', api_key, server['id'])
        
        puts "\n\n"
        print ui.color("Deleting server.", :magenta)
        
        until_done(vm_delete_operation) { print '.' }
        
        puts "\n\n"
        ui.warn("Deleted server #{ui.color(server['id'], :bold)} named #{ui.color(server['hostname'], :bold)}")
      end
    end
  end

end
