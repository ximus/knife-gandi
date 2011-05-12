module KnifeGandi
  module PluginHelper
    
    # Keeps the vm's warnings out of $stdout.
    # Helpful when changing the value of a constant.
    def suppress_warnings
      original_verbosity = $VERBOSE
      $VERBOSE = nil
      result = yield
      $VERBOSE = original_verbosity
      return result
    end
    
    def locate_config_value(key)
      key = key.to_sym
      Chef::Config[:knife][key] || config[key]
    end
    
    def config_has_value?(key)
      key = key.to_sym
      Chef::Config[:knife].has_key?(key) || config.has_key?(key)
    end
    
    def until_done(operation)
      while operation['step'] != 'DONE' 
        operation = connection.call('operation.info', api_key, operation['id'])
        yield
        sleep 2
      end
    end
    
    def public_ips_of(server, opts={})
      options = opts.merge({:type => 'public'})
      public_ips = ip_objects_of(server, options)
      public_ips.collect { |ip| ip['ip'] }
    end
    
    def public_reverses_of(server, opts={})
      options = opts.merge({:type => 'public'})
      public_ips = ip_objects_of(server, options)
      public_ips.collect { |ip| ip['reverse'] }
    end
    
    # Returns the public IP Resource objects sent from the server.
    # Look up their representation in the Gandi API docs.
    def ip_objects_of(server, opts={})
      # Server has n ifaces which hold 2 IPs (IPv4 and IPv6)
      public_ifaces = server['ifaces']
      if opts.has_key?(:type)
        public_ifaces = public_ifaces.find_all { |iface| iface['type'] == 'public' }
      end
      
      public_ips = public_ifaces.collect_concat { |iface| iface['ips'] }
      if opts.has_key?(:version)
        # Filter IP version (4|6)
        public_ips = public_ips.find_all { |ip| ip['version'] == opts[:version] }
      end
      
      public_ips
    end
    
  end # EOF PluginHelper
end