# load the gem
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'rbac-api-client', :git => 'https://github.com/RedHatInsights/insights-rbac-api-client-ruby', :branch => 'master'
end
require 'yaml'
require_relative 'rbac_pagination'
include RBAC::Paginate

def create_groups(groups)
  api_instance = RBACApiClient::GroupApi.new
  current = current_groups
  names = current.collect(&:name)
  group = RBACApiClient::Group.new # Group | Group to create in tenant
  begin
    #Create a group in a tenant
    groups.each do |grp|
      next if names.include?(grp['name'])
      puts "Creating #{grp['name']}"
      group.name = grp['name']
      group.description = grp['description']
      result = api_instance.create_group(group)
    end
  rescue RBACApiClient::ApiError => e
    puts "Exception when calling GroupApi->create_group: #{e}"
  end
end

def current_groups
  api_instance = RBACApiClient::GroupApi.new
  RBAC::Paginate.call(api_instance, :list_groups, {}).to_a
end

def create_roles(roles)
  current = current_roles
  names = current.collect(&:name)
  api_instance = RBACApiClient::RoleApi.new
  role_in = RBACApiClient::RoleIn.new # RoleIn | Role to create
  begin
    #Create a roles for a tenant
    roles.each do |role|
      next if names.include?(role['name'])
      role_in.name = role['name']
      role_in.access = []
      role['access'].each do |obj|
        access = RBACApiClient::Access.new
        access.permission = obj['permission']
        access.resource_definitions = obj['resource_definitions'] || []
        role_in.access  << access
      end
      result = api_instance.create_roles(role_in)
      p result
    end
  rescue RBACApiClient::ApiError => e
    puts "Exception when calling RoleApi->create_roles: #{e}"
    raise
  end
end

def current_roles
  api_instance = RBACApiClient::RoleApi.new
  RBAC::Paginate.call(api_instance, :list_roles, {}).to_a
end

def create_policies(policies)
  names = current_policies.collect(&:name)
  groups = current_groups
  roles = current_roles
  api_instance = RBACApiClient::PolicyApi.new
  policy_in = RBACApiClient::PolicyIn.new # PolicyIn | Policy to create
  begin
    #Create a policy in a tenant
    policies.each do |policy|
      next if names.include?(policy['name'])
      policy_in.name = policy['name']
      policy_in.description = policy['description']
      policy_in.group = find_uuid('Group', groups, policy['group']['name'])
      policy_in.roles = [find_uuid('Role', roles, policy['role']['name'])]
      result = api_instance.create_policies(policy_in)
      p result
    end
  rescue RBACApiClient::ApiError => e
    puts "Exception when calling PolicyApi->create_policies: #{e}"
  end
end

def current_policies
  #List the policies in the tenant
  api_instance = RBACApiClient::PolicyApi.new
  RBAC::Paginate.call(api_instance, :list_policies, {}).to_a
end

def find_uuid(type, data, name)
  result = data.detect { |item| item.name == name }
  raise "#{type} #{name} not found in RBAC service" unless result
  result.uuid
end

# setup authorization
RBACApiClient.configure do |config|
  hash  = YAML.load_file('./rbac_config.yml')
  hash.keys.each do |key|
    config.send("#{key}=".to_sym, hash[key])
  end
end

#acl_data = JSON.parse(File.read('./rbac.json'))
acl_data = YAML.load_file('./rbac.yml')
create_groups(acl_data['groups'])
create_roles(acl_data['roles'])
create_policies(acl_data['policies'])
