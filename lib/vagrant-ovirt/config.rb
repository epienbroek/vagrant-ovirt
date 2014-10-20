require 'vagrant'

module VagrantPlugins
  module OVirtProvider
    class Config < Vagrant.plugin('2', :config)

      attr_accessor :url
      attr_accessor :username
      attr_accessor :password
      attr_accessor :datacenter
      attr_accessor :cluster

      # Domain specific settings used while creating new machine.
      attr_accessor :memory
      attr_accessor :cpus
      attr_accessor :template
      attr_accessor :console
      attr_accessor :disk_size

      def initialize
        @url            = UNSET_VALUE
        @username       = UNSET_VALUE
        @password       = UNSET_VALUE
        @datacenter     = UNSET_VALUE
        @cluster        = UNSET_VALUE

        # Domain specific settings.
        @memory     = UNSET_VALUE
        @cpus       = UNSET_VALUE
        @template   = UNSET_VALUE
        @console    = UNSET_VALUE
        @disk_size  = UNSET_VALUE
      end

      def finalize!
        @url = nil if @url == UNSET_VALUE
        @username = nil if @username == UNSET_VALUE
        @password = nil if @password == UNSET_VALUE
        @datacenter = nil if @datacenter == UNSET_VALUE
        @cluster = nil if @cluster == UNSET_VALUE

        # Domain specific settings.
        @memory = 512 if @memory == UNSET_VALUE
        @cpus = 1 if @cpus == UNSET_VALUE
        @template = 'Blank' if @template == UNSET_VALUE
        @console = 'spice' if @console == UNSET_VALUE
        @disk_size = nil if @disk_size == UNSET_VALUE
      end

      def validate(machine)
        valid_console_types = ['vnc', 'spice']
        raise Error::InvalidConsoleType,
          :console => @console unless valid_console_types.include? @console
      end
    end
  end
end

