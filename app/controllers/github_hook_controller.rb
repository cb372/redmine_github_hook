require 'json'

class GithubHookController < ApplicationController

  skip_before_filter :verify_authenticity_token, :check_if_login_required

  def index
    if request.post?
      repositories = find_repositories

      repositories.each { |x| 
        # Fetch the changes from remote repo
        update_repository(x) 
      
        # Fetch the new changesets into Redmine
        x.fetch_changesets
      }

    end

    render(:text => 'OK')
  end

  private

  def system(command)
    Kernel.system(command)
  end

  # Executes shell command. Returns true if the shell command exits with a success status code
  def exec(command)
    logger.debug { "GithubHook: Executing command: '#{command}'" }

    # Get a path to a temp file
    logfile = Tempfile.new('github_hook_exec')
    logfile.close

    success = system("#{command} > #{logfile.path} 2>&1")
    output_from_command = File.readlines(logfile.path)
    if success
      logger.debug { "GithubHook: Command output: #{output_from_command.inspect}"}
#p "GithubHook: Command output: #{output_from_command.inspect}"
    else
      logger.error { "GithubHook: Command '#{command}' didn't exit properly. Full output: #{output_from_command.inspect}"}
#p "GithubHook: Command '#{command}' didn't exit properly. Full output: #{output_from_command.inspect}"
    end

    return success
  ensure
    logfile.unlink
  end

  def git_command(command, repository)
    "git --git-dir='#{repository.root_url}' #{command}"
  end

  # Fetches updates from the remote repository
  def update_repository(repository)
    command = git_command('fetch origin', repository)
    if exec(command)
      command = git_command("fetch origin '+refs/heads/*:refs/heads/*'", repository)
      exec(command)
    end
  end

  # Gets the project identifier from the querystring parameters and if that's not supplied, assume
  # the Github repository name is the same as the project identifier.
  def get_identifier
    payload = JSON.parse(params[:payload] || '{}')
    identifier = params[:project_id] || payload['repository']['name']
    raise ActiveRecord::RecordNotFound, "Project identifier not specified" if identifier.nil?
    return identifier
  end

  # Finds the Redmine project in the database based on the given project identifier
  def find_project
    identifier = get_identifier
    project = Project.find_by_identifier(identifier.downcase)
    raise ActiveRecord::RecordNotFound, "No project found with identifier '#{identifier}'" if project.nil?
    return project
  end

  # Returns the Redmine Repository object(s) we are trying to update
  def find_repositories
    project = find_project
    repositories = project.repositories
    return repositories.select { |x| x.is_a?(Repository::Git) }
  end

end
