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
    class GandiImageList < Knife

      deps do
        require 'knife-gandi'
        require 'knife-gandi/plugin_helper'
        require 'xmlrpc/client'
      end

      banner "knife gandi image list (options)"

      option :gandi_api_key,
        :short => "-K KEY",
        :long => "--gandi-api-key KEY",
        :description => "Your Gandi API key",
        :proc => Proc.new { |key| Chef::Config[:knife][:gandi_api_key] = key }
        
      option :gandi_datacenter_id,
        :short => "-D ID",
        :long => "--gandi-datacenter-id ID",
        :description => "Filter using a specific datacenter ID",
        :proc => Proc.new { |d| Chef::Config[:knife][:gandi_datacenter_id] = d.to_i }
        
      option :gandi_os_arch_32,
        :short => "--32",
        :description => "List only 32 bit images",
        :boolean => true,
        :proc => Proc.new { |d| Chef::Config[:knife][:gandi_os_arch] = 'x86-32' }
        
      option :gandi_os_arch_64,
        :short => "--64",
        :description => "List only 64 bit images",
        :boolean => true,
        :proc => Proc.new { |d| Chef::Config[:knife][:gandi_os_arch] = 'x86-64' }
        
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
        @api_key    = Chef::Config[:knife][:gandi_api_key] || config[:gandi_api_key] || raise("No Gandi API key was specified")
        
        image_list = [ 
          ui.color('ID', :bold), 
          ui.color('Name', :bold), 
          ui.color('Arch', :bold),
          ui.color('Datacenter_id', :bold)
        ]
        
        # Filter the result set
        filters = { 
          :sort_by => 'label', 
          :datacenter_id => Chef::Config[:knife][:gandi_datacenter_id] || nil,
          :os_arch  => Chef::Config[:knife][:gandi_os_arch] || nil
        }
        
        connection.call('image.list', api_key, filters).each do |image|
          image_list << image['id'].to_s
          image_list << ui.color(image['label'], :bold)
          image_list << image['os_arch']
          image_list << image['datacenter_id'].to_s
        end
        
        puts ui.list(image_list, :columns_across, 4)
      end
    end
  end
end
