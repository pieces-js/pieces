exports.config =
  conventions:
    assets: /(assets|vendor\/assets|fonts)[\\/]/
  modules:
    definition: false
    wrapper: false
  paths:
    public: 'public'
  server: 
    path: 'app.js' 
    port: 3333 
    base: '/' 
    run: yes
  files:
    javascripts:
      defaultExtension: 'coffee'
      joinTo:
        'js/static.js': /^app\/.*.jade$/
        'js/pieces.core.js': /^app[\\/]core/
        'js/pieces.js': /^app[\\/](components|plugins)/
        'js/demo.js': /^app[\\/]demo/
        'js/pieces.rest.js': /^app[\\/](net|resources|views|controllers)/
        'js/vendor.js': /^(bower_components|vendor)[\\/](?!test)/
        'test/js/test.helpers.js': /^test\/helpers\.coffee/
        'test/js/test.js': /^test[\\/](?!rvc)/
        'test/js/test.rvc.js': /^test[\\/](?=rvc)/
        'test/js/test-vendor.js': /^vendor[\\/](?=test)/
      order:
        before:
          [
            'app/core/utils/utils.coffee',
            'app/core/core.coffee',
            'app/core/events/events.coffee',
            'app/core/events/nod_events.coffee',
            'app/core/nod.coffee',
            'app/components/app.coffee',
            'app/components/guess/guesser.coffee',
            'app/components/pieces.coffee',
            /^app[\\/]components/,
            'app/plugins/plugin.coffee',
            'app/resources/base.coffee',
            'app/controllers/base.coffee',
            'app/controllers/page.coffee',
            'app/controllers/modules/scoped.coffee',
            'app/views/view.coffee',
            'test/helpers.coffee'
          ]
        after:
          [
            /^app[\\/]plugins/,
            'app/net/iframe.upload.coffee',
            'app/components/action_list.coffee',
            'app/components/toggle_button.coffee',
            /^app[\\/]components[\\/]renderers/,
            /^app[\\/]controllers/,
          ]
    stylesheets:
      defaultExtension: 'sass'
      joinTo:
        'css/app.css' : /^(bower_components|app|vendor[\\/](?!test))/
        'test/stylesheets/test.css': /^(test|vendor[\\/](?=test))/
      order:
        before: [
          'app/styles/reset.css'
        ]
    templates:
      joinTo: 
        'js/templates.js': /.+\.jade$/
  plugins:
    uglify:
      mangle: 
        toplevel: false
      ignored: /^(bower_components|vendor|test)/
    jade:
      options:
        pretty: yes
      locals:
        baseurl: '/'
        nav: {}
    autoprefixer:
      browsers: ["last 1 version", "> 1%", "ie 9"]