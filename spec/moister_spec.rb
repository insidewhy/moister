require 'spec_helper'

describe Moister do
  def make_subc_parser
    Moister::SubcommandOptionParser.new do |op|
      op.banner = 'blah'

      op.on '-o stuff', 'global opt', 'opt'

      op.subcommand 'subc', 'subc description' do |subop|
        subop.on '-s stuff', 'subc opt', 'subopt'
      end
    end
  end

  it 'has a version number' do
    expect(Moister::VERSION).not_to be nil
  end

  it 'supports config setting shortcut of #on' do
    parsed = Moister::SubcommandOptionParser.new do |op|
      op.on '-o stuff', 'opt'
    end.parse ['-o', 'val' ]

    expect(parsed).to have_attributes(command: nil, positionals: [], config: { 'opt' => 'val' })
  end

  it 'supports subcommand with option set via #on shortcut' do
    parsed = make_subc_parser.parse ['-o', 'val', 'subc', '-s', 'subval', 'positional']

    expect(parsed).to have_attributes(
      command: 'subc',
      positionals: ['positional'],
      config: { 'opt' => 'val', 'subc' => { 'subopt' => 'subval' } }
    )
  end

  it 'supports subcommand aliases' do
    parsed = Moister::SubcommandOptionParser.new do |op|
      op.subcommand 'subc,s', 'subc description'
    end.parse ['s']

    expect(parsed).to have_attributes(command: 'subc')
  end

  it 'generates help string including subcommand' do
    help_str = make_subc_parser.to_s
    expect(help_str).to eq("blah\n    -o stuff                         global opt\n\ncommands:\n    subc    subc description\n")
  end
end
