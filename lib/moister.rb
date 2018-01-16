require 'optparse'
require_relative 'moister/version'

module Moister
  ParseResults = Struct.new :command, :positionals, :config

  class OptionParserExtra < OptionParser
    def initialize(config = {})
      @config = config
      super
    end

    # like OptionParser#on but if a block is not supplied the last argument (which
    # should be a string) is used as a hash key to store that value within @config.
    def on *opts, &block
      if block
        super *opts, &block
      else
        key = opts.pop
        super *opts do |val|
          @config[key] = val
        end
      end
    end
  end

  class SubcommandOptionParser < OptionParserExtra
    def initialize
      # options applicable to all subcommands
      @for_all = []
      @subcommands = {}
      @aliases = {}
      super
    end

    def subcommand name, banner, &block
      name, *positionals = name.split ' '
      name, *aliases = name.split(',')
      subcmd = { name: name, banner: banner, parse_cmdline: block }
      subcmd[:positionals] = positionals unless positionals.empty?
      @subcommands[name] = subcmd
      aliases.each { |_alias| @aliases[_alias] = name }
    end

    # add a block to configure every subcommand
    def for_all &block
      @for_all.push block
    end

    def to_s
      ret = super
      prefixes = @subcommands.values.map do |subcmd|
        prefix = subcmd[:name]
        prefix +=  ' ' + subcmd[:positionals].join(' ') if subcmd.has_key? :positionals
        prefix
      end
      max_len = prefixes.map(&:length).max

      ret += "\ncommands:\n"
      @subcommands.values.each_with_index do |subcmd, idx|
        prefix = prefixes[idx]
        prefix += ' ' * (max_len - prefix.length + 2)
        ret += "    #{prefix}  #{subcmd[:banner]}\n"
      end
      ret
    end

    alias :help :to_s

    def parse!(args = ARGV)
      apply_for_all self
      order! args
      if args.empty?
        ParseResults.new(nil, [], @config)
      else
        cmd = args.first
        _alias = @aliases[cmd]
        cmd = _alias if _alias
        subcmd_meta = @subcommands[cmd]
        raise "invalid subcommand: #{cmd}" unless @subcommands.has_key? cmd
        args.shift

        subcmd_config = @config[cmd] = {}
        positionals = OptionParserExtra.new(@config[cmd]) do |subop|
          apply_for_all subop
          subop.banner = subcmd_meta[:banner]
          parse_cmdline = subcmd_meta[:parse_cmdline]
          parse_cmdline.call(subop) if parse_cmdline
        end.order! args

        positionals_meta = subcmd_meta[:positionals]
        if positionals_meta
          positionals_meta.each do |positional_meta|
            array_match = false
            optional = if positional_meta =~ /^\[.+\]$/
              optional = true
              positional_meta = positional_meta[1..-2]
            end

            positional_name = if positional_meta =~ /^\*[a-z\-]+$/
              array_match = true
              positional_meta[1..-1]
            else
              positional_meta
            end

            if array_match
              if positionals.empty?
                if optional
                  subcmd_config[positional_name] = []
                  next
                end
                raise "`#{cmd}' subcommand requires at least one `#{positional_name}' parameter"
              end
              subcmd_config[positional_name] = positionals
              positionals = []
            else
              if positionals.empty?
                next if optional
                raise "`#{cmd}' subcommand requires `#{positional_name}' parameter"
              end
              subcmd_config[positional_name] = positionals.shift
            end
          end
        end

        ParseResults.new(cmd, positionals, @config)
      end
    end

    def parse(args = ARGV)
      parse! args.clone
    end

   private
    def apply_for_all op
      @for_all.each { |block| block.call op } unless @for_all.empty?
    end
  end
end
