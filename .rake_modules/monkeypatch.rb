# frozen_string_literal: true

require 'git'
require 'pathname'

REPO_URL = 'https://gerrit.wikimedia.org/r/operations/deployment-charts'

# Extend string to add color output
class String
  def red
    colour(31)
  end

  def green
    colour(32)
  end

  private

  def colour(colour_code)
    "\e[#{colour_code}m#{self}\e[0m"
  end
end

class Git::Base
  def refresh_remote(remote_name, force = false)
    # If we're forcing, try to remove the remote.
    # We ignore errors because we do this before verifying
    # if the remote exists.
    begin
      remove_remote(remote_name) if force
    rescue Git::GitExecuteError
    end
    # Here we can't use the git remote(name) method
    # as that will just generate a remote of this name if not present
    rems = remotes.select { |r| r.name == remote_name }
    if rems.empty?
      add_remote(remote_name, REPO_URL, fetch: true)
    else
      rems.pop.fetch
    end
  end

  def back_to(ref)
    remote_name, branch_name = ref.split '/'
    refresh_remote remote_name
    checkout(ref)
    yield
    checkout('-')
  end
end

module FileUtils
  # Copy recursively also resolving all symlinks
  def cp_Lr(src, dst, options = {})
    # First of all, let's copy over the files
    FileUtils.cp_r(src, dst, options)
    # now find symlinks, dereference them, and copy them over
    path = Pathname.new(src)
    path.find do |x|
      next unless x.symlink?
      begin
        # this will raise Errno::ENOENT if the link is broken
        # we avoid failing CI because someone added a broken link,
        # but leave it in place instead.
        actual_src = x.realpath
        actual_dst = File.join(dst, x.relative_path_from(path))
        # remove the symlink
        FileUtils.rm_rf actual_dst
        # copy recursively from the original source.
        FileUtils.cp_r actual_src, actual_dst, options
      rescue Errno::ENOENT
        puts "warning: file #{x} is a broken link"
      end
    end
  end
  module_function :cp_Lr
end
