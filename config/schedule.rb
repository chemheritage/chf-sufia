# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

env :PATH, ENV['PATH']

every 1.month, roles: [:app] do
  rake "chf:metadata_report"
end

# if we decide to move this to the jobs box, wse'll need to
# update the postgres configuration to accept non-localhost connections
# will require brief downtime of staff functionality
every 1.day, :at => '2:30 am', roles: [:app] do
  rake "chf:fixity_checks"
end

every 1.day, :at => '2:00 am', roles: [:app] do
  rake "blacklight:delete_old_searches[7]"
end

every :tuesday, :at => '4:00 am', roles: [:cron] do
  rake "sitemap:create"
end
