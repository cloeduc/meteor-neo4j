Package.describe({
  name: 'ccorcos:neo4j',
  summary: 'Neo4j API for Meteor',
  version: '0.0.7',
  git: 'https://github.com/ccorcos/meteor-neo4j'
});

Package.onUse(function(api) {
  api.versionsFrom('1.0');
  api.use([
    'coffeescript',
    'http',
    'ramda:ramda@0.14.0'
  ], 'server');
  api.addFiles('src/driver.coffee', 'server');
  api.export('Neo4jDB');
});

Package.onTest(function(api) {
  api.use('ccorcos:neo4j');
  api.use('tinytest');
  api.use('test-helpers');

  // api.add_files('test/helpers.js');
  api.add_files('test/driver-tests.js', 'server');
});
