# gitlabff generates json or yaml config file using Gitlab Feature Flags
# the command allow pass the Gitlab url and token by parameters and env variables
# the result is outputted into STDOUT

require "option_parser"
require "http/client"
require "uri"
require "json"
require "yaml"

def check_scope (scope : String, list : JSON::Any) : Bool
  list.as_a.each do |item|
    item["scopes"].as_a.each do |scopes|
      return true if scopes["environment_scope"]? == scope
    end
  end
  false
end

def get_userids_from_scope (scope : String, list : JSON::Any) : String
  user_ids = ""

  list.as_a.each do |item|
    if item["name"] == "userWithId" 
      item["scopes"].as_a.each do |scopes|
        user_ids += item["parameters"]["userIds"].as_s if scopes["environment_scope"]? == scope
      end
    end
    
  end
  user_ids
end

module Gitlabff
  VERSION = "1.0.0"

  # Control variables
  gitlab_uri = ENV["GITLABFF_URI"]? || ""
  project_uri = ENV["GITLABFF_PROJECT"]? || ""
  token = ENV["GITLABFF_TOKEN"]? || ""
  scope = ENV["GITLABFF_SCOPE"]? || ""
  use_yaml = false

  # Parse parameters
  OptionParser.parse do |parser|
    parser.banner = "Usage: gitlabff [arguments]
    
    You can use also *env* variables:
     * GITLABFF_URI     - The main url with protocol ex: https://migitlab.uri.com
     * GITLABFF_PROJECT - The project name ID ex: group/project_name or project_name
     * GITLABFF_TOKEN   - The Gitlab user access Token (permissions: read_user, read_api, read_repository, read_registry)
     * GITLABFF_SCOPE   - The environment FF tag to filter
    "
    parser.on("-u URI", "--uri=URI", "Gitlab url") { |gg_url| gitlab_uri = gg_url }
    parser.on("-p PROJECT", "--uri=PROJECT", "Gitlab project name") { |gg_prj| project_uri = gg_prj }
    parser.on("-u TOKEN", "--uri=TOKEN", "Gitlab API Token") { |gg_token| token = gg_token }
    parser.on("-u SCOPE", "--uri=SCOPE", "Feature Flags scope") { |gg_scope| scope = gg_scope }
    parser.on("-y", "--yaml", "Export as YAML instead JSON") { use_yaml = true }
    parser.on("-h", "--help", "Show this help") do
      puts parser
      exit
    end
    parser.invalid_option do |flag|
      STDERR.puts "ERROR: #{flag} is not a valid option."
      STDERR.puts parser
      exit(1)
    end
  end

  if gitlab_uri == "" || project_uri == ""  || token == "" || scope == ""
    abort("Error, please fill all the parameters")
  end
  

  response = HTTP::Client.get("#{gitlab_uri}/api/v4/projects/#{URI.encode_path_segment(project_uri)}/feature_flags", 
                              headers: HTTP::Headers{"PRIVATE-TOKEN" => "#{token}"})

  if response.status_code == 200
    parsed_json = JSON.parse(response.body)

    # Filter FF by selected scope
    filtered_ff = parsed_json.as_a.select! do |ff_item|
      check_scope scope, ff_item["strategies"]
    end
  
    result = Array( Hash(String, String | Bool) ).new
    filtered_ff.each do |filtered_item|
      result.push Hash{
        "name" => filtered_item["name"].as_s,
        "active" => filtered_item["active"].as_bool,
        "userIds" => get_userids_from_scope(scope, filtered_item["strategies"])
      }
    end
  
    # Displays the result
    if use_yaml
      puts result.to_yaml
    else
      puts result.to_json
    end
  else
    abort("Error connecting to Gitlab Feature Flags API")
  end

  
end
