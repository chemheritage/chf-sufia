// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.

//= require jquery
//= require jquery_ujs

// Needs to load BEFORE we load anything that loads AMD/almond, which sufia
// does, or the presence of AMD in a non-AMD aware build tool confuses aspectratio.
//= require 'lazysizes/plugins/aspectratio/ls.aspectratio.js'

//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap
// Required by Blacklight
//= require blacklight/blacklight

// We do NOT want to require_tree here, because we do NOT want to require
// the 'sufia' subdir -- we want to let sufia itself use those files
// as overrides when needed. So we require_directory to get the .js
// files in the top-level, then require_tree individual directories
// (not including ./sufia)
//
//= require_directory .
//= require_tree ./hydra-editor

//= require sufia


// For blacklight_range_limit built-in JS, if you don't want it you don't need
// this:
//= require 'blacklight_range_limit'


//= require 'lazysizes'

