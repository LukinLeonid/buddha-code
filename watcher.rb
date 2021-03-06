#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def convert_paths(paths, fileset, klass)
  paths = paths.select { |p| fileset.match(p) }
  paths.map { |p| klass.path_to_id(p) }
end

Listeners = []
def listen(klass)
  klass.filesets.each do |fileset|
    listener = Listen.to(fileset.dir,
                         relative: true) do |updated, added, deleted|
      update_table(klass,
                   convert_paths(updated, fileset, klass),
                   convert_paths(added, fileset, klass),
                   convert_paths(deleted, fileset, klass))
    end
    listener.only(fileset.only) if not fileset.only.nil?
    Listeners << listener
  end
end

def listen_root(table, path, &block)
  Listeners << Listen.to('data',
                         relative: true) do |updated, added, deleted|
    # hack, Regexp.escape doesn't help in :only ...
    if updated.include?(path) ||
        added.include?(path) ||
        deleted.include?(path)
      sync_root_table(table, path) { block.call }
    end
  end
end

def start
  Listeners.each { |l| l.start }
  sleep
end

listen(Cache::Teaching)
listen(Cache::News)
listen(Cache::Book)
listen(Cache::BookCategory)
listen(Cache::Digest)

listen_root(:top_categories, 'data/library.xml') { Cache.load_library() }

start
