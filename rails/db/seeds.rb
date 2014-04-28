# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
source_path = File.expand_path(File.join(__FILE__,"../../.."))
yml_blob = YAML.load_file(File.join(source_path,"crowbar.yml"))
ActiveRecord::Base.transaction do
  Barclamp.import("core",yml_blob,source_path)
  Dir.glob("/opt/opencrowbar/**/crowbar_engine/barclamp_*/db/seeds.rb") do |seedfile|
    "#{seedfile.split('/')[-3].camelize}::Engine".constantize.load_seed
  end
end

# We always need a system deployment
Deployment.find_or_create_by!(name:        "system",
                              description: I18n.t('automatic', :default=>"Created Automatically by System"),
                              system:      true,
                              state:       Deployment::COMMITTED)


u = User.find_or_create_by_username!(:username=>'crowbar', :password=>'crowbar', :is_admin=>true)
u.digest_password('crowbar')
u.save!

if Rails.env.development? or Rails.env.test?
  u = User.find_or_create_by_username!(:username=>'developer', :password=>'replace!me', :is_admin=>true)
  u.digest_password('Cr0wbar!')
  u.save!
end

Nav.find_or_create_by_item :item=>'root', :name=>'nav.root', :description=>'nav.root_description', :path=>"main_app.root_path", :order=>0, :development=>true

# nodes
Nav.find_or_create_by_item :item=>'nodes', :parent_item=>'root', :name=>'nav.nodes', :description=>'nav.nodes_description', :path=>"main_app.nodes_path", :order=>1000
  Nav.find_or_create_by_item :item=>'nodes_child', :parent_item=>'nodes', :name=>'nav.nodes', :description=>'nav.nodes_description', :path=>"main_app.nodes_path", :order=>1000
  Nav.find_or_create_by_item :item=>'groups', :parent_item=>'nodes', :name=>'nav.groups', :description=>'nav.groups_description', :path=>"main_app.nodes_path", :order=>2000
  Nav.find_or_create_by_item :item=>'bulk_edit', :parent_item=>'nodes', :name=>'nav.bulk_edit', :description=>'nav.bulk_edit_description', :path=>"main_app.bulk_edit_path", :order=>3000

# deployments
Nav.find_or_create_by_item :item=>'deploy', :parent_item=>'root', :name=>'nav.deployments', :description=>'nav.deployments_description', :path=>"main_app.deployments_path", :order=>2000
  Nav.find_or_create_by_item :item=>'deploy_child', :parent_item=>'deploy', :name=>'nav.deployments', :description=>'nav.deployments_description', :path=>"main_app.deployments_path", :order=>1000
  Nav.find_or_create_by_item :item=>'roles', :parent_item=>'deploy', :name=>'nav.roles', :description=>'nav.roles_description', :path=>"main_app.roles_path", :order=>2000
  Nav.find_or_create_by_item :item=>'annealer', :parent_item=>'deploy', :name=>'nav.annealer', :description=>'nav.annealer_description', :path=>"main_app.annealer_path", :order=>3000
  Nav.find_or_create_by_item :item=>'overview', :parent_item=>'deploy', :name=>'nav.layercake', :description=>'nav.layercake_description', :path=>"main_app.layercake_path", :order=>4000

# utils
Nav.find_or_create_by_item :item=>'utils', :parent_item=>'root', :name=>'nav.utils', :description=>'nav.utils_description', :path=>"main_app.utils_path", :order=>6000
  Nav.find_or_create_by_item :item=>'utils_child', :parent_item=>'utils', :name=>'nav.utils', :description=>'nav.utils_description', :path=>"main_app.utils_path", :order=>100
  Nav.find_or_create_by_item :item=>'bootstrap', :parent_item=>'utils', :name=>'nav.bootstrap', :description=>'nav.bootstrap_description', :path=>"main_app.bootstrap_path", :order=>150
  Nav.find_or_create_by_item :item=>'util_index', :parent_item=>'utils', :name=>'nav.util_logs', :description=>'nav.util_logs_description', :path=>"main_app.utils_path", :order=>200
  Nav.find_or_create_by_item :item=>'jigs', :parent_item=>'utils', :name=>'nav.jigs', :description=>'nav.jigs_description', :path=>"main_app.jigs_path", :order=>300
  Nav.find_or_create_by_item :item=>'barclamps', :parent_item=>'utils', :name=>'nav.barclamps', :description=>'nav.barclamps_description', :path=>"main_app.barclamps_path", :order=>4000

# users
Nav.find_or_create_by_item :item=>'users', :parent_item=>'root', :name=>'nav.users', :description=>'nav.users_description', :path=>"main_app.users_path", :order=>6000
  Nav.find_or_create_by_item :item=>'manage_users', :parent_item=>'users', :name=>'nav.manage_users', :description=>'nav.manage_users_description', :path=>"main_app.users_path", :order=>100
  Nav.find_or_create_by_item :item=>'user_settings', :parent_item=>'users', :name=>'nav.user_settings', :description=>'nav.user_settings_description', :path=>"main_app.utils_settings_path", :order=>400

# help
Nav.find_or_create_by_item :item=>'help', :parent_item=>'root', :name=>'nav.help', :description=>'nav.help_description', :path=>"main_app.docs_path", :order=>9999
  Nav.find_or_create_by_item :item=>'help_child', :parent_item=>'help', :name=>'nav.help', :description=>'nav.help_description', :path=>"main_app.docs_path", :order=>100
  Nav.find_or_create_by_item :item=>'crowbar_wiki', :parent_item=>'help', :name=>'nav.wiki', :description=>'nav.wiki_description', :path=>"https://github.com/opencrowbar/core/tree/master/doc", :order=>200

# networks
Nav.find_or_create_by_item :item=>'networks', :parent_item=>'root', :name=>'nav.networks', :description=>'nav.networks_description', :path=>"networks_path", :order=>1500
  Nav.find_or_create_by_item :item=>'networks_child', :parent_item=>'networks', :name=>'nav.networks', :description=>'nav.networks_description', :path=>"networks_path", :order=>1000
  Nav.find_or_create_by_item :item=>'network_map', :parent_item=>'networks', :name=>'nav.network_map', :description=>'nav.network_map_description', :path=>"network_map_path", :order=>5000
  Nav.find_or_create_by_item :item=>'interfaces', :parent_item=>'networks', :name=>'nav.interfaces', :description=>'nav.interfaces_description', :path=>"interfaces_path", :order=>5000

# scaffolds
Nav.find_or_create_by_item :item=>'scaffold', :name=>'nav.scaffold.top', :path=>"main_app.scaffolds_deployments_path", :description=>'nav.scaffold.top_description', :order=>7000
  Nav.find_or_create_by_item :item=>'scaffold_attribs',  :parent_item=>'scaffold', :name=>'nav.scaffold.attribs',  :path=>"main_app.scaffolds_attribs_path", :order=>1100
  Nav.find_or_create_by_item :item=>'scaffold_jigs',  :parent_item=>'scaffold', :name=>'nav.scaffold.jigs',  :path=>"main_app.scaffolds_jigs_path", :order=>1400
  Nav.find_or_create_by_item :item=>'scaffold_barclamps', :parent_item=>'scaffold', :name=>'nav.scaffold.barclamps',  :path=>"main_app.scaffolds_barclamps_path", :order=>1800
  Nav.find_or_create_by_item :item=>'scaffold_deployments', :parent_item=>'scaffold', :name=>'nav.scaffold.deployments',  :path=>"main_app.scaffolds_deployments_path", :order=>1810
  Nav.find_or_create_by_item :item=>'scaffold_roles', :parent_item=>'scaffold', :name=>'nav.scaffold.roles',  :path=>"main_app.scaffolds_roles_path", :order=>1810
  Nav.find_or_create_by_item :item=>'scaffold_nodes', :parent_item=>'scaffold', :name=>'nav.scaffold.nodes', :path=>"main_app.scaffolds_nodes_path", :order=>2000
  Nav.find_or_create_by_item :item=>'scaffold_groups', :parent_item=>'scaffold', :name=>'nav.scaffold.groups', :path=>"main_app.scaffolds_groups_path", :order=>2300
  Nav.find_or_create_by_item :item=>'scaffold_nav', :parent_item=>'scaffold', :name=>'nav.scaffold.menus', :path=>"main_app.scaffolds_navs_path", :order=>5400
  Nav.find_or_create_by_item :item=>'scaffold_docs', :parent_item=>'scaffold', :name=>'nav.scaffold.docs', :path=>"main_app.scaffolds_docs_path", :order=>5500
  Nav.find_or_create_by_item :item=>'scaffold_networks',  :parent_item=>'scaffold', :name=>'nav.scaffold.networks',  :path=>"scaffolds_networks_path", :order=>2000
  Nav.find_or_create_by_item :item=>'scaffold_allocations',  :parent_item=>'scaffold', :name=>'nav.scaffold.allocations',  :path=>"scaffolds_network_allocations_path", :order=>2040
