# README

[![Build Status](https://travis-ci.org/chemheritage/chf-sufia.svg?branch=master)](https://travis-ci.org/chemheritage/chf-sufia)

## Description
The Sufia-based application powering CHF's digital collections site. CHF's digitical collections team is currently hard at work ingesting content before making the site publicly available!

## Dependencies
All system setup for development and production machines is managed and documented via ansible playbooks that use the roles defined in https://github.com/curationexperts/ansible-hydra.

## Development

One way to do development might be to set up a ubuntu VM and use the
ansible scripts. But these are instructions for setting it up on an OSX
dev box, without a VM.

* Dependencies (also check at https://github.com/projecthydra/sufia#prerequisites)
	* `brew install imagemagick`
	* `brew install fits`
	* `brew install redis`
		* `brew services start redis`
	* postgres (on osx, i like https://postgresapp.com/)
  * `brew install vips` **IF** you want to turn on .dzi tile creation for deep-zooming
     in dev. See [dzi_tiles_on_s3](./docs/dzi_tiles_on_s3.md)

* `cp config/secrets.yml.example config/secrets.yml`
	* you will need to fill out some secret sierra connection config in here

* db setup
	* `./bin/rake db:create db:schema:load`

* To run the rails app, you Fedora instance running and a Solr instance running. You can:
   * run `./bin/rake dev:servers` to start fedora and solr (according to config in `./.solr_wrapper`
     and `./.fc_repo_wrapper`), leave that running, and _then_ in a different terminal
     start `rails server` as normal.
   * start fedora, solr, _and_ rails with `./bin/rake hydra:server` (but you may have
     trouble with byebug/pry when you do it this way)
   * The above methods both use the `solr_wrapper` and `fcrepo_wrapper` gems to
     automatically start (and install if needed) fedora and solr. If you want
     to install/run them some other way yourself, you may want to set
     some ENV variables to tell the Rails app where to find them at wherever
     you have them running:
      * `HYDRA_SOLR_URL_DEVELOPMENT`
      * `HYDRA_FEDORA_URL_DEVELOPMENT`
      * `HYDRA_FEDORA_BASE_PATH_DEVELOPMENT`
      * `HYDRA_FEDORA_USER_DEVELOPMENT`
      * `HYDRA_FEDORA_PASSWORD_DEVELOPMENT`

## Load default Workflow and add default Admin Set

After Fedora and Solr are running, load the default workflow and create the default administrative set. Both of these need to be run any time the app is deployed to a new environment:
```
rake curation_concerns:workflow:load
rake sufia:default_admin_set:create
```


### Create sample data

* You can createcreate some sample data and a user account to get started quicker:
  * `./bin/rake dev:data[email@example.com,password]` will create account with that
     email/password, and create 6 sample works (5 public one private) attached to that account.
  * `./bin/rake dev:data` will create the same 6 sample works, but each belonging to a different
    newly created random user.

### Running tests locally

You also need a hydra and a fedora server running to run tests. You can:

* Use `./bin/rake dev:spec_with_app_load` to automatically start hydra and fedora,
  then run Rspec tests, then shut the down. (This is what we do on travis)
* _Or_, you can use `RAILS_ENV=test ./bin/rake dev:servers` to run the fedora
  and solr apps in test mode (using config from `./config/solr_wrapper_test.yml` and
  `./config/fcrepo_wrapper_test.yml`), just leave it running in a terminal, and
  then run tests with `./bin/rspec` or `./bin/rake rspec` or however you want.
* Or, if you have a solr and fedora installed and running yourself in your own
  way, you may want to set `ENV` variables to the app knows where to find them
  when running tests. See `ENV` keys mentioned above in "development setup",
  but replace `_DEVELOPMENT` with `_TEST`.

### Other docs

See [docs](./docs) subdir.


* Using full [Derivatives in Dev](./derivative_in_dev.md).
* [DZI Tiles on S3](./docs/dzi_tiles_on_s3.md)
* [Our Custom Derivatives](./docs/our_custom_derivatives.md) architecture

## Deployment
bundle exec cap [target machine] deploy

See more at: https://chemheritage.atlassian.net/wiki/spaces/HDCSD/pages/5668869/Deployment+Capistrano

### Maintenance mode

Maintenance mode makes the entire app unavailable.

    bundle exec cap staging maintenance:enable REASON="a test of maintenance mode" UNTIL="12pm Eastern Time"

    bundle exec cap staging maintenance:disable

### Remote rake tasks

Run a rake task with downtime:

    TASK=chf:data_fix:library_division REASON="testing things" UNTIL="12pm Eastern Time" bundle exec cap staging invoke:rake:with_maintenance

Will turn maint mode on for you, run task, turn it back off -- even if task fails. If you want to leave it on if task fails, SAFE_MAINT=false.

Or to just run a rake task on a remote server without maint mode:

    cap staging invoke:rake TASK=chf:data_fix:whatever

## Run Tests
bundle exec rspec

## Run tests continuously using Guard
bundle exec guard -p -l 10
