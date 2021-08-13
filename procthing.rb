#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sys/proctable'
require 'tty/table'
require 'pastel'
require 'optparse'

# The ProcNode class is used to represent the process tree.
class ProcNode
  attr_accessor :proc, :children

  def initialize(prc)
    @proc = prc
    @children = []
  end
end

# Class used to create and render the process tree
class ProcTree
  COLORS = %i[red green yellow bright_blue magenta cyan white].freeze
  VERTICAL = '│'
  HORIZONTAL_FIRST = '┌'
  HORIZONTAL = '─'
  HORIZONTAL_CHILDREN = '┬'
  CONNECTOR = '├'
  CONNECTOR_LAST = '└'

  attr_accessor :pastel, :options
  attr_reader :tree, :procs

  def initialize(options = {})
    @options = options
    @procs = Sys::ProcTable.ps(smaps: false)
    @tree = gen_tree(@procs)
    color = options[:nocolor]
    @pastel = Pastel.new(enabled: !color)
  end

  def depth_color(depth)
    COLORS[depth % COLORS.length]
  end

  def kproc
    kproc = Struct::ProcTableStruct.new
    kproc.name = 'Kernel'
    kproc.comm = Gem::Platform.local.os
    kproc.pid = 0
    kproc
  end

  def gen_tree(procs)
    tree = procs.each_with_object({}) do |prc, h|
      h[prc.pid] = ProcNode.new(prc)
    end

    tree[0] = ProcNode.new(kproc)

    tree.each_pair do |pid, prtr|
      next if pid.zero?
      next if pid == 2 && !@options[:kernel]

      parent = tree[prtr.proc.ppid]
      parent.children << prtr
    end
  end

  def print_node(prc, depth, last, depth_map)
    pipes = []
    (depth - 1).times do |i|
      if depth_map[i + 1]
        color = depth_color(i)
        pipes << @pastel.send(color, VERTICAL)
      else
        pipes << ' '
      end
    end
    if depth.zero?
      pipes << @pastel.send(depth_color(depth), HORIZONTAL_FIRST)
    else
      pipes << @pastel.send(depth_color(depth - 1), last ? CONNECTOR_LAST : CONNECTOR)
      pipes << @pastel.send(depth_color(depth), prc.children.empty? ? HORIZONTAL : HORIZONTAL_CHILDREN)
    end
    pid_str = "[#{prc.proc.pid}] " if @options[:pid]
    comm_str = " (#{prc.proc.comm})" if @options[:comm]
    cmd_str = " [#{prc.proc.cmdline}]" if @options[:cmd]
    puts "#{pipes.join}#{pid_str}#{prc.proc.name}#{comm_str}#{cmd_str}"
    prc.children.each do |chld|
      print_node(chld, depth + 1, chld == prc.children.last, depth_map.clone << !last)
    end
  end

  def print_tree
    print_node(@tree[0], 0, false, [])
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename $PROGRAM_NAME} [options]"

  opts.on('-p', '--pid', 'Display process ID') do
    options[:pid] = true
  end
  opts.on('-c', '--comm', 'Display process command name') do
    options[:comm] = true
  end
  opts.on('-m', '--cmd', 'Display process command line') do
    options[:cmd] = true
  end
  opts.on('-n', '--no-color', 'Disable color output') do
    options[:nocolor] = true
  end
  opts.on('-k', '--kernel', 'Include kernel threads') do
    options[:kernel] = true
  end
end.parse!

ProcTree.new(options).print_tree
