#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sys/proctable'
require 'tty/table'
require 'pastel'
require 'pry'

# The ProcNode class is used to represent the process tree.
class ProcNode
  attr_accessor :proc, :children

  def initialize(prc)
    @proc = prc
    @children = []
  end
end

class ProcTree
  COLORS = %i[red green yellow bright_blue magenta cyan white].freeze
  VERTICAL_FIRST = '┌'
  VERTICAL = '│'
  HORIZONTAL = '─'
  HORIZONTAL_CHILDREN = '┬'
  CONNECTOR = '├'
  CONNECTOR_LAST = '└'

  attr_accessor :pastel
  attr_reader :tree, :procs

  def initialize
    @procs = Sys::ProcTable.ps(smaps: false)
    @tree = gen_tree(@procs)
    @pastel = Pastel.new
  end

  def depth_color(depth)
    COLORS[depth % COLORS.length]
  end

  def gen_tree(procs)
    tree = procs.each_with_object({}) do |prc, h|
      h[prc.pid] = ProcNode.new(prc)
    end

    kproc = Struct::ProcTableStruct.new
    kproc.name = 'Kernel'
    tree[0] = ProcNode.new(kproc)

    tree.each_pair do |pid, prtr|
      next if pid.zero?

      parent = tree[prtr.proc.ppid]
      parent.children << prtr
    end
  end

  def print_node(prc, depth, last)
    pipes = []
    (depth - 1).times do |i|
      color = depth_color(i)
      pipes << @pastel.send(color, VERTICAL)
    end
    pipes << @pastel.send(depth_color(depth - 1), last ? CONNECTOR_LAST : CONNECTOR)
    dash = @pastel.send(depth_color(depth), prc.children.empty? ? HORIZONTAL : HORIZONTAL_CHILDREN)
    puts "#{pipes.join}#{dash}#{prc.proc.name}"
    prc.children.each { |chld| print_node(chld, depth + 1, chld == prc.children.last) }
  end

  def print_tree
    print_node(@tree[0], 0, false)
  end
end

ProcTree.new.print_tree
