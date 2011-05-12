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
    class GandiServerList < Knife

      deps do
        require 'knife-gandi'
        require 'knife-gandi/plugin_helper'
        require 'xmlrpc/client'
      end

      banner "knife gandi server list (options)"

      option :gandi_api_key,
        :short => "-K KEY",
        :long => "--gandi-api-key KEY",
        :description => "Your Gandi API key",
        :proc => Proc.new { |key| Chef::Config[:knife][:gandi_api_key] = key }
        
      option :ip_version,
        :short => "-W VERSION",
        :long => "--ip-version VERSION",
        :description => "The version of the IP protocol (4|6) displayed in the listings",
        :proc => Proc.new { |f| Chef::Config[:knife][:ip_version] = f.to_i },
        :default => 4

      attr_reader :connection, :api_key
        
      def run
        # Unsual to extend here but enables 'plugin_helper' to be require'd lazily
        extend KnifeGandi::PluginHelper
        $stdout.sync = true
        
        # Necessary changes to xmlrpc's defaults, prevent warnings from showing up in prompt
        suppress_warnings do
          XMLRPC::Config.const_set(:ENABLE_NIL_PARSER, true)
        end
        
        @connection = XMLRPC::Client.new2(KnifeGandi::API_ENDPOINT_URL)
        @api_key    = Chef::Config[:knife][:gandi_api_key] || config[:gandi_api_key] || raise("Please provide an API key")
        
        server_list = [
          ui.color('ID', :bold),
          ui.color('Hostname', :bold),
          ui.color('Date Created', :bold),
          ui.color('Cores', :bold),
          ui.color('Memory', :bold),
          ui.color('Image', :bold),
          ui.color('State', :bold),
          ui.color('Public IPs', :bold)
        ]
        
        connection.call('vm.list', api_key).each do |server|
          # Adds a some overhead but returns much more vm attributes including IPs and Image
          server = connection.call('vm.info', api_key, server['id'])
          server_list << server['id'].to_s
          server_list << server['hostname']
          server_list << server['date_created'].to_date.to_s
          server_list << server['cores'].to_s
          server_list << server['memory'].to_s + 'mb'
          server_list << server['disks'].find{ |disk| disk['is_boot_disk'] }['label']
          server_list << server['state']
          server_list << public_ips_of(server, :version => locate_config_value(:ip_version)).join(', ')
        end
      
        puts ui.list(server_list, :columns_across, 8)
      end
    end # GandiServerList
  end
end
