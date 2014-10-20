require "log4r"

module VagrantPlugins
  module OVirtProvider
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_ovirt::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(
            env[:ovirt_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(ovirt, machine)
          return nil if machine.id.nil?

          # Get config.
          config = machine.provider_config

          # Find the machine
          server = ovirt.servers.get(machine.id.to_s)

          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          ip_address = server.ips.first
          if ip_address == nil or ip_address == ''
            raise Errors::NoIpAddressError
          end

          # Return the info
          # TODO: Some info should be configurable in Vagrantfile
          return {
            :host             => ip_address,
            :port             => machine.config.ssh.guest_port,
            :username         => machine.config.ssh.username,
            :private_key_path => machine.config.ssh.private_key_path,
            :forward_agent    => machine.config.ssh.forward_agent,
            :forward_x11      => machine.config.ssh.forward_x11,
          }
        end 
      end
    end
  end
end
