class RepositoryObserver < ActiveRecord::Observer

  def before_save(repository)
      repository.logger.debug 'before_save'
      if Setting.plugin_redmine_github_hook[:enabled] && repository.type.include?('Git') && repository.url.match('^(?:http|git|ssh)')
          base_dir_name = repository.url.gsub(/[^a-zA-Z0-9\-_]/, '_')
          url = repository.url
          p "basedir = #{base_dir_name}"
          git_dir = Setting.plugin_redmine_github_hook[:git_dir].to_s
          git_dir = File.join(git_dir, base_dir_name)
          if Dir[git_dir] == []
              repository.logger.info "Cloning a bare git repo into #{git_dir}"
              cmd = 'git clone --bare ' + url + ' ' + git_dir
              if exec(cmd)
                  cmd = git_command('remote add origin '+url, git_dir)
                  exec(cmd)
                  #cmd = git_command('fetch -v', git_dir)
                  #exec(cmd)
                  cmd = git_command('fetch origin', git_dir)
                  exec(cmd)
                  #cmd = git_command('reset --soft refs/remotes/origin/master', git_dir)
                  #exec(cmd)
              else
                  return false
              end
          else
              repository.logger.info "Git repo already exists at #{git_dir} - skipping clone."
          end
          # Set the local clone as the root_url
          repository.root_url = git_dir
      end
  end #defined before_save --------------

  private
      def git_command(command, git_dir)
          "git --git-dir='#{git_dir}' #{command}"
      end
      
      # Executes shell command. Returns output from command  if the shell command exits with a success status code
      def exec(command)
          #logger.debug { "Github: Executing command: '#{command}'" }
          #p "Github: Executing command: '#{command}'"
          
          # Get a path to a temp file
          #logfile = Tempfile.new('github__exec')
          #logfile.close
          
          #success = system("#{command} > #{logfile.path} 2>&1")
          #output_from_command = File.readlines(logfile.path)
          #output_from_command = %x[command]
            shell = Shell.new(command)
            shell.run
            success = (shell.exitstatus == 0)
            output_from_command = shell.output
          if success
              #logger.debug { "Github: Command output: #{output_from_command.inspect}"}
              #p "Github: Command output: #{output_from_command.inspect}"
              return output_from_command
              else
              #logger.error { "Github: Command '#{command}' didn't exit properly. Full output: #{output_from_command.inspect}"}
              p "Github: Command failed '#{command}' didn't exit properly. Full output: #{output_from_command.inspect}"
          end
          
          #ensure
          #logfile.unlink
      end
end
