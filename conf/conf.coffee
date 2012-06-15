fs   = require('fs')
util = require('util')

# Until this is incorporated into busser, perhaps as an option to straight
# preparation of the .json file, this will be a standalone .json generator.
#
# Modify the coffeescript config (projectConfig and contents). Then runun as:
#
#     coffee conf.coffee
#
# conf.json is saved.
#
# Use this .json file # in the call to start busser.
#
class ProjectConfig
  constructor: (options) ->
    @serverConfig = {}
    @devSCFrameworkConfigs = {}
    @prodSCFrameworkConfigs = {}
    @applicationConfigs = {}
    @[key] = options[key] for own key of options

    config.initPathWithName(name) for own name,config of @devSCFrameworkConfigs
    config.initPathWithName(name) for own name,config of @prodSCFrameworkConfigs
    config.initPathWithName(name) for own name,config of @applicationConfigs
    
  hash_console_colors: ->
    console.log '{'
    console.log "\"server\": #{util.inspect(@serverConfig, true, null, true)}"
    console.log "\"default-app-dev\": #{(util.inspect(config, true, null, true) for own name,config of @devSCFrameworkConfigs).join(',')}"
    console.log "\"default-app-prod\": #{(util.inspect(config, true, null, true) for own name,config of @prodSCFrameworkConfigs).join(',')}"
    console.log "\"apps\": #{(util.inspect(config, true, null, true) for own name,config of @applicationConfigs).join(',')}"
    console.log '}'

  hash_console: ->
    console.log '{'
    console.log "\"server\": #{util.inspect(@serverConfig, true, null)}"
    console.log "\"default-app-dev\": #{(util.inspect(config, true, null) for own name,config of @devSCFrameworkConfigs).join(',')}"
    console.log "\"default-app-prod\": #{(util.inspect(config, true, null) for own name,config of @prodSCFrameworkConfigs).join(',')}"
    console.log "\"apps\": #{(util.inspect(config, true, null) for own name,config of @applicationConfigs).join(',')}"
    console.log '}'
  

class ServerConfig
  constructor: (options) ->
    @hostname = 'localhost'
    @port = 8000
    @allowCrossSiteRequest = false
    @[key] = options[key] for own key of options


class FrameworkConfig
  constructor: (options) ->
    @name=''
    @buildLanguage="english"
    @path=""
    @saveDir="build"
    @stageDir="stage"
    @theme="sc-theme"
    @cssTheme="ace"
    @useSprites=true
    @optimizeSprites=false
    @padSpritesForDebugging=false
    @combineScripts=true
    @combineStylesheets=true
    @minifyScripts=false
    @minifyStylesheets=false
    @[key] = options[key] for own key of options

    if @name.length > 0
      @initPathWithName(@name)

  initPathWithName: (name) ->
    @name = name
    if @path.length is 0
      @path = "frameworks/sproutcore/frameworks/#{@name}"


class ApplicationConfig
  constructor: (options) ->
    @name="TodosThree-dev"
    @title="Todos Three"
    @path="TodosThree"
    @urlPrefix="/"
    @saveDir="build"
    @proxies=[]
    @sc_frameworks=[]
    @customFrameworkConfigs={}
    @[key] = options[key] for own key of options

    if @name.length > 0
      @initPathWithName(@name)

  initPathWithName: (name) ->
    @name = name
    if @path.length is 0
      @path = "frameworks/sproutcore/frameworks/#{@name}"


# The config, specified in coffeescript, from here down, except for the
# call at the bottom to fire the .json output.
#
projectConfig = new ProjectConfig
  serverConfig: new ServerConfig
    hostname: "localhost"
    port: 8000
    allowCrossSiteRequests: false
  devSCFrameworkConfigs:
    ajax:            new FrameworkConfig() # Take all defaults on most of these.
    animation:       new FrameworkConfig()
    bootstrap:       new FrameworkConfig()
    core_foundation: new FrameworkConfig()
    core_tools:      new FrameworkConfig()
    datastore:       new FrameworkConfig()
    datetime:        new FrameworkConfig()
    debug:           new FrameworkConfig()
    desktop:         new FrameworkConfig()
    documentation:   new FrameworkConfig()
    split_view:      new FrameworkConfig(path: "frameworks/sproutcore/frameworks/experimental/frameworks/split_view")
    formatters:      new FrameworkConfig()
    foundation:      new FrameworkConfig()
    jquery:          new FrameworkConfig()
    media:           new FrameworkConfig()
    qunit:           new FrameworkConfig()
    routing:         new FrameworkConfig()
    runtime:         new FrameworkConfig()
    statechart:      new FrameworkConfig()
    table:           new FrameworkConfig()
    template_view:   new FrameworkConfig()
    testing:         new FrameworkConfig()
    yuireset:        new FrameworkConfig()
  prodSCFrameworkConfigs:
    ajax:            new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    animation:       new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    bootstrap:       new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    core_foundation: new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    core_tools:      new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    datastore:       new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    datetime:        new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    debug:           new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    desktop:         new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    documentation:   new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    split_view:      new FrameworkConfig
      path: "frameworks/sproutcore/frameworks/experimental/frameworks/split_view"
      minifyScripts: true
      minifyStylesheets: true
    formatters:      new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    foundation:      new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    jquery:          new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    media:           new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    qunit:           new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    routing:         new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    runtime:         new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    statechart:      new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    table:           new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    template_view:   new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    testing:         new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
    yuireset:        new FrameworkConfig(minifyScripts: true, minifyStylesheets: true)
  applicationConfigs:
    todos_three_dev: new ApplicationConfig
      name: "TodosThree-dev"
      title: "Todos Three"
      path: "apps/TodosThree"
      urlPrefix: "/"
      saveDir: "build"
      proxies: []
      sc_frameworks: [
        { name: "jquery",          conf: "dev" },
        { name: "runtime",         conf: "dev" },
        { name: "core_foundation", conf: "dev" },
        { name: "datetime",        conf: "dev" },
        { name: "foundation",      conf: "dev" },
        { name: "statechart",      conf: "dev" },
        { name: "datastore",       conf: "dev" },
        { name: "desktop",         conf: "dev" },
        { name: "template_view",   conf: "dev" }]
      customFrameworkConfigs:
        empty_theme: new FrameworkConfig
          buildLanguage: "english"
          path: "frameworks/sproutcore/themes/empty_theme"
          saveDir: "build"
          stageDir: "stage"
          theme: "sc-theme"
          useSprites: true
          optimizeSprites: false
          padSpritesForDebugging: false
          combineScripts: true
          combineStylesheets: true
          minifyScripts: false
          minifyStylesheets: false
        ace: new FrameworkConfig
          buildLanguage: "english"
          path: "frameworks/sproutcore/themes/ace"
          saveDir: "build"
          stageDir: "stage"
          theme: "sc-theme"
          cssTheme: "ace"
          useSprites: true
          optimizeSprites: false
          padSpritesForDebugging: false
          combineScripts: true
          combineStylesheets: true
          minifyScripts: false
          minifyStylesheets: false
        todos_three: new FrameworkConfig
          buildLanguage: "english"
          path: "apps/TodosThree"
          saveDir: "build"
          stageDir: "stage"
          theme: "sc-theme"
          cssTheme: "ace.todos-three"
          useSprites: true
          optimizeSprites: false
          padSpritesForDebugging: false
          combineScripts: true
          combineStylesheets: true
          minifyScripts: false
          minifyStylesheets: false
    todos_three_prod: new ApplicationConfig
      name: "TodosThree-prod"
      title: "Todos Three"
      path: "apps/TodosThree"
      saveDir: "build"
      stageDir: "stage"
      theme: "sc-theme"
      buildLanguage: "english"
      combineScripts: true
      combineStylesheets: true
      minifyScripts: true
      minifyStylesheets: true
      cssTheme: "ace.todos-three"
      proxies: []
      pathsToExclude: [ "/fixtures\//" ]
      sc_frameworks: [
        { name: "jquery",          conf: "prod" },
        { name: "runtime",         conf: "prod" },
        { name: "core_foundation", conf: "prod" },
        { name: "datetime",        conf: "prod" },
        { name: "foundation",      conf: "prod" },
        { name: "datastore",       conf: "prod" },
        { name: "desktop",         conf: "prod" },
        { name: "template_view",   conf: "prod" }]
      customFrameworkConfigs:
        empty_theme: new FrameworkConfig
          name: "empty_theme"
          path: "frameworks/sproutcore/themes/empty_theme"
          combineScripts: true
          combineStylesheets: true
          minifyScripts: false
          minifyStylesheets: false
        ace: new FrameworkConfig
          name: "ace"
          path: "frameworks/sproutcore/themes/ace"
          combineScripts: true
          combineStylesheets: true
          minifyScripts: false
          minifyStylesheets: false

#projectConfig.hash_console_color()
#projectConfig.hash_console()

fs.writeFile "conf.json", JSON.stringify(projectConfig, null, 2), (err) ->
    if err
      console.log err
    else
      console.log "JSON config file was saved."
