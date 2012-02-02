# -----
 
util         = require "util"
fs           = require "fs"
http         = require "http"
url          = require "url"
path_module  = require "path"
nconf        = require "nconf"
prompt       = require "prompt"
colors       = require "colors"
{exec}       = require "child_process"
{spawn}      = require "child_process"
EventEmitter = require('events').EventEmitter
uglify =
  parser: require("uglify-js").parser
  processor: require("uglify-js").uglify

try
  less = require("less")
catch e
  util.puts "WARNING: 'less' could not be required."
  util.puts "         You won't be able to parse .less files."
  util.puts "         Install it with `npm install less`."

# Input Arguments Handling
# ------------------------
#
# *appTargets* are normal looking "filename" style app names as used in the busser.json
# conf file, such as HelloWorld-dev, where the -dev is a user chosen suffix to
# distinguish between another configuration of theirs, say HelloWorld-prod, as you can
# see in the default conf/busser.json file. So, the regular expression here allows any
# alphanumeric characters with numbers, dashes, or underscores.
#
appTargetsValidator = /^([A-Za-z0-9_\s\-])+(,[A-Za-z0-9_\s\-]+)*$/

# See the user input-handling method, *parseActionsArgument*, for design of this regular
# expression, which allows any combination of the action verbs build, save, and run, in
# any order, and even jammed-up, as buildsave or buildsaverun.
#
actionsValidator = /// ^ (                # from beginning of input
                     [\s*\<build\>*\s*]*  # build, save, or run, with or without whitespace
                     [\s*\<save\>*\s*]*
                     [\s*\<run\>*\s*]*
                   ) + (
                     ,                    # comma, then build, save, or run with or without whitespace
                     [\s*\<build\>*\s*]*
                     [\s*\<save\>*\s*]*
                     [\s*\<run\>*\s*]*
                   )*$                    # to end of input
                   ///

# The *appTargets* input, having passed the validator above, is split
# on comma, then the items are trimmed. Commas don't have to be present.
#
parseAppTargetsArgument = (appTargetsResult) ->
  (target.trim() for target in appTargetsResult.split(','))

# Match for presence of build, save, run words and construct one of several
# possible actionItems.
#
parseActionsArgument = (actionsResult) ->
  actionsResult = actionsResult.toLowerCase()

  actions = []
  actions.push 'build' if actionsResult.indexOf('build') isnt -1
  actions.push 'save' if actionsResult.indexOf('save') isnt -1
  actions.push 'run' if actionsResult.indexOf('run') isnt -1
       
  # The possible combinations for actions are these four compound actionItems, 
  # as used internally. As noted above, the user has the freedom to type build,
  # save, run in any manner, as csv input, as blank-delimited, or as a compound
  # word with no blanks.
  #
  actionItems = 'build'        if actions.length is 1 and 'build' in actions
  actionItems = "buildsave"    if actions.length is 2 and 'build' in actions and 'save' in actions
  actionItems = "buildsave"    if actions.length is 1 and 'save' in actions
  actionItems = "buildrun"     if actions.length is 2 and 'build' in actions and 'run' in actions
  actionItems = "buildrun"     if actions.length is 1 and 'run' in actions
  actionItems = "buildsaverun" if actions.length is 3 and 'build' in actions and 'save' in actions and 'run' in actions

  actionItems

# File Extension and Type Functions
# ---------------------------------

# Use the node.js path module to pull the file extension from the path.
#
extname = (path) ->
  path_module.extname(path)

# The *fileType* function is used to identify paths by their file extension.
#
fileType = (path) ->
  ext = extname(path)
  return "stylesheet" if /^\.(css|less)$/.test ext
  return "script"     if (ext is ".js") or (ext is ".handlebars") and not /tests\//.test(path)
  return "test"       if ext is ".js" and /tests\//.test(path)
  return "resource"   if ext in ResourceFile.resourceExtensions
  return "unknown"

# *isStylesheet* and the others in this set of functions are for shorthand reference.
#
isStylesheet = (file) -> fileType(file.path) is "stylesheet"
isScript =     (file) -> fileType(file.path) is "script"
isTest =       (file) -> fileType(file.path) is "test"
isResource =   (file) -> fileType(file.path) is "resource"

# *fileClassType* is a utility function for use on the **File** class and its
# derivatives.
#
# *fileClassType* uses instanceof, which would be true for superclasses, as
# well as the actual class, so put subclasses before superclasses in the checks.
#
fileClassType = (file) ->
  return "VirtualStylesheetFile" if file instanceof VirtualStylesheetFile
  return "StylesheetFile" if file instanceof StylesheetFile
  return "VirtualScriptFile" if file instanceof VirtualScriptFile
  return "ScriptFile" if file instanceof ScriptFile
  return "ResourceFile" if file instanceof ResourceFile
  return "TestFile" if file instanceof TestFile
  return "RootHtmlFile" if file instanceof RootHtmlFile
  return "BootstrapVirtualScriptFile" if file instanceof BootstrapVirtualScriptFile
  return "File" if file instanceof File

# Language Handling
# -----------------
#
# *defaultLanguage* and *buildLanguage* are set as globals for now, but should
# be handled in general busser.conf. [TODO]
#
defaultLanguage = "english"
buildLanguage = "english"

# *buildLanguageAbbreviations* is a global hash, where keys are language names
# and values are abbreviations.
#
buildLanguageAbbreviations =
  english:  "en"
  french:   "fr"
  german:   "de"
  japanese: "ja"
  spanish:  "es"
  italian:  "it"

# *buildLanguageAbbreviation* is a utility function for returning the abbreviation
# matching the buildLanguage given in the configuration.
#
buildLanguageAbbreviation = (buildLanguage) ->
  if buildLanguage?
    buildLanguageAbbreviations[buildLanguage] if buildLanguage of buildLanguageAbbreviations
  else
    "en"

# *languageInPath* returns null or the language abbreviation in the path, where
# the path "apps/myapp/en.lproj/main.js" would evaluate to "en". Use of a language
# fullname, e.g., "english.lproj", is also possible.
#
languageInPath = (path) ->
  match = /([a-z]+)\.lproj\//.exec(path)
  match[1] if match?

# File Reading Queue System
# -------------------------
#
# This section is for the system setting to allow a higher number of open
# files during processing. See the mauritslamers versions of garcon for the history
# of "upping" the values.
#
openedFileDescriptorsCount = 0

maxSimultaneouslyOpenedFileDescriptors = 32

guessMaxSimultaneouslyOpenedFileDescriptors = ->
  exec "ulimit -n", (err, stdout, stderr) ->
    if not err?
      m = parseInt(stdout.trim(), 10)
      maxSimultaneouslyOpenedFileDescriptors = (if (m/16 >= 4) then m/16 else 4) if m > 0

guessMaxSimultaneouslyOpenedFileDescriptors()

# *queue*, *dequeue*, and *readFile*, are tied to the system settings for file descriptors 
# above. Look at the content method in **File** and derivatives for calls to *readFile*.
#
queue = (method) ->
  @_queue = []  unless @_queue?
  @_queue.push method
  dequeue()

dequeue = ->
  if @_queue.length > 0 and openedFileDescriptorsCount < maxSimultaneouslyOpenedFileDescriptors
    openedFileDescriptorsCount += 1
    method = @_queue.shift()
    if method[0] is "readFile"
      fs.readFile method[1], (err, data) ->
        method[2] err, data
        openedFileDescriptorsCount -= 1
        dequeue()

readFile = (path, callback) ->
  queue [ "readFile", path, callback ]

# Date Handling
# -------------
#
# This block of Date Format code is from the martoche version of garcon. The
# mauritslamers version of garcon improves date handling.
#

# Date Format 1.2.3
# (c) 2007-2009 Steven Levithan <stevenlevithan.com>
# MIT license
#
# Includes enhancements by Scott Trenda <scott.trenda.net>
# and Kris Kowal <cixar.com/~kris.kowal/>
#
# Accepts a date, a mask, or a date and a mask.
# Returns a formatted version of the given date.
# The date defaults to the current date/time.
# The mask defaults to dateFormat.masks.default.
#
dateFormat = ->
  token = /d{1,4}|m{1,4}|yy(?:yy)?|([HhMsTt])\1?|[LloSZ]|"[^"]*"|'[^']*'/g
  timezone = /\b(?:[PMCEA][SDP]T|(?:Pacific|Mountain|Central|Eastern|Atlantic) (?:Standard|Daylight|Prevailing) Time|(?:GMT|UTC)(?:[-+]\d{4})?)\b/g
  timezoneClip = /[^-+\dA-Z]/g
  pad = (val, len) ->
    val = String(val)
    len = len or 2
    val = "0" + val  while val.length < len
    val

  (date, mask, utc) ->
    dF = dateFormat
    if arguments.length is 1 and Object::toString.call(date) is "[object String]" and not /\d/.test(date)
      mask = date
      date = undefined
    date = (if date then new Date(date) else new Date())
    throw SyntaxError("invalid date")  if isNaN(date)
    mask = String(dF.masks[mask] or mask or dF.masks["default"])
    if mask.slice(0, 4) is "UTC:"
      mask = mask.slice(4)
      utc = true
    _ = (if utc then "getUTC" else "get")
    d = date[_ + "Date"]()
    D = date[_ + "Day"]()
    m = date[_ + "Month"]()
    y = date[_ + "FullYear"]()
    H = date[_ + "Hours"]()
    M = date[_ + "Minutes"]()
    s = date[_ + "Seconds"]()
    L = date[_ + "Milliseconds"]()
    o = (if utc then 0 else date.getTimezoneOffset())
    flags =
      d: d
      dd: pad(d)
      ddd: dF.i18n.dayNames[D]
      dddd: dF.i18n.dayNames[D + 7]
      m: m + 1
      mm: pad(m + 1)
      mmm: dF.i18n.monthNames[m]
      mmmm: dF.i18n.monthNames[m + 12]
      yy: String(y).slice(2)
      yyyy: y
      h: H % 12 or 12
      hh: pad(H % 12 or 12)
      H: H
      HH: pad(H)
      M: M
      MM: pad(M)
      s: s
      ss: pad(s)
      l: pad(L, 3)
      L: pad((if L > 99 then Math.round(L / 10) else L))
      t: (if H < 12 then "a" else "p")
      tt: (if H < 12 then "am" else "pm")
      T: (if H < 12 then "A" else "P")
      TT: (if H < 12 then "AM" else "PM")
      Z: (if utc then "UTC" else (String(date).match(timezone) or [ "" ]).pop().replace(timezoneClip, ""))
      o: (if o > 0 then "-" else "+") + pad(Math.floor(Math.abs(o) / 60) * 100 + Math.abs(o) % 60, 4)
      S: [ "th", "st", "nd", "rd" ][(if d % 10 > 3 then 0 else (d % 100 - d % 10 isnt 10) * d % 10)]

    mask.replace token, ($0) ->
      (if $0 of flags then flags[$0] else $0.slice(1, $0.length - 1))

dateFormat()

dateFormat.masks =
  default: "ddd mmm dd yyyy HH:MM:ss"
  shortDate: "m/d/yy"
  mediumDate: "mmm d, yyyy"
  longDate: "mmmm d, yyyy"
  fullDate: "dddd, mmmm d, yyyy"
  shortTime: "h:MM TT"
  mediumTime: "h:MM:ss TT"
  longTime: "h:MM:ss TT Z"
  isoDate: "yyyy-mm-dd"
  isoTime: "HH:MM:ss"
  isoDateTime: "yyyy-mm-dd'T'HH:MM:ss"
  isoUtcDateTime: "UTC:yyyy-mm-dd'T'HH:MM:ss'Z'"
  httpDateTime: "ddd, d mmm yyyy HH:MM:ss o"

dateFormat.i18n =
  dayNames: [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ]
  monthNames: [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]

Date::format = (mask, utc) ->
  dateFormat this, mask, utc

# String Substitution
# -------------------
#
# *gsub*, from Ruby, is added to the prototyp of String here. See:
# http://flochip.com/2011/09/06/rubys-string-gsub-in-javascript/
#
# [TODO] Is there another web reference needed for this? 
#
String::gsub = (re, callback) ->
  result = ""
  source = this
  while source.length > 0
    if match = re.exec(source)
      result += source.slice(0, match.index)
      result += callback(match)
      source = source.slice(match.index + match[0].length)
    else
      result += source
      source = ""
  result

# -----

# File Handler System
# ===================
#
# Handler
# -------
# 
# Synopsis: 
#   
#   A **Handler** handles some type of file or content processing, for reading file
#   content, for minifying, for text replacement, etc.
#
# Constructor:
#
#   Parameters:
#
#     @name -- the name of the one of the properties in the Busser class for handlers,
#              e.g., ifModifiedSince, contentType, minify, join.
#
#     @exec -- the method to do the work, perhaps involving other functions or classes.
#
#     @next -- a link to the next handler.
#     
#   **Handler** exec functions are held in the **Busser** class. **HandlerSet** instances are 
#   created by calls to **Busser**, with a subset of available handlers.
#   
class Handler
  constructor: (options) ->
    @name = ""
    @next = null
    @exec = -> ""

    @[key] = options[key] for own key of options

# HandlerSet
# ----------
# 
# Synopsis: 
#
#   **HandlerSet** is a container for handlers which work on files and content in a 
#   SproutCore project to build an system for development or deployment. A **HandlerSet**
#   consists of a linked-list of handlers built from the available set. A **HandlerSet**
#   instance is fired with exec(). A HandlerSet contains one or more handlers.
#
# Constructor:
#
#   Parameters:
#
#     @name -- for reference in labeling each HandlerSet singleton instance, e.g.
#              stylesheetHandlerSet or joinHandlerSet.
#
#     @urlPrefix -- to be prepended to resulting paths.
#
#   Each **Handler** instance has exec and next, which are called during traversal
#   from a HandlerSet exec call.
#
#   The exec() method fires on the head handler, beginning an "async waterfall,"
#   wherein the sequence of handlers is called in succession, each one passing along
#   a callback function. When the final "tail" handler executes, there is a return 
#   through callbacks back up to the head handler. In the end, the handler has 
#   performed one or more operations, finally returning the data via the head callback.
#
class HandlerSet
  constructor: (@name, @urlPrefix="/") ->
    @handlers  = []

  # *head* returns the first handler.
  #
  head: ->
    @handlers[0] if @handlers.length > 0

  # *exec* fires on the head handler. The file and callback parameters are always used;
  # request is used during server operations for passing a modification time.
  #
  exec: (file, request, callback) ->
    headHandler = @head()
    headHandler.exec(file, request, callback)

# Busser
# ------
#
# The **Busser** class is the workhorse for the build system. It contains the
# code for available handlers and related utility functions. The handlerSet
# method is used to create **HandlerSet** instances with a subset of available
# handlers, instantiated and returned as a singly-linked-list.
#
class Busser
  constructor ->

  # The handlerSet method returns a HandlerSet instance that contains a linked-list
  # of Handler objects, instantiated and ready for processing.
  #
  # Parameters:
  #
  #    name -- handlerSet instance label.
  #
  #    urlPrefix -- default is "/"... [TODO] should be customizable for apps? 
  #                                          Also, check when this should be used...
  #
  #    handlerNames -- an array of handler names from the list of those available.
  #                    These are the names of handlers, keys to properties of the Busser
  #                    class.
  #
  # A new **HandlerSet** instance is created with the name and urlPrefix. Then
  # a list of handlers is created from handlerNames, setting handlerSet.handlers, the
  # linked-list of handlers. All but the last handler have their next property set.
  # The @[handlerName].exec reference, seen in Handler creation calls, is a lookup to the
  # given handler property definition in the Busser class. If you examine, for example,
  # the ifModifiedSince property in the Busser class, you will see an exec function,
  # which is given a parameter in creating a new Handler instance of that type.
  # 
  # The completed **HandlerSet** instance, with linked-list of handlers, is returned.
  #
  handlerSet: (name, urlPrefix, handlerNames) ->
    urlPrefix ?= "/"

    handlerSet = new HandlerSet name, urlPrefix

    for handlerName in handlerNames
      handlerSet.handlers.push new Handler
        name: handlerName
        next: null
        exec: @[handlerName].exec

    # Set handler.next for all but the last handler, which will have the default next = null.
    handler.next = handlerSet.handlers[i+1]  for handler,i in handlerSet.handlers[0...handlerSet.handlers.length-1]

    handlerSet

  # *mtimeScanner* is a static utility function that takes a list of files,
  # scans each file for modification time, finding the max (most recent),
  # then calls the callback.
  #
  @mtimeScanner: (files, callback) ->
    mtime = 0

    # The **Scanner** class scans files for modification time, keeping a
    # maxMtime value that is returned upon completion of the scan.
    #
    class Scanner extends process.EventEmitter
      constructor: (@files=[]) ->
        @count = @files.length
        @maxMtime = 0

      scan: ->
        for file in @files
          fs.stat file.path, (err, stats) =>
            if err
              util.puts "WARNING: " + err.message
            else
              @maxMtime = stats.mtime  if stats.mtime > @maxMtime
            @count -= 1
            @emit('end', @maxMtime) if @count <= 0
        @emit('end', @maxMtime) if @count <= 0
  
    scanner = new Scanner(files)
    scanner.on 'end', (mtime) ->
      callback mtime
    scanner.scan()

  # The *ifModifiedSince* handler checks if a file's children have been modified since
  # a time given in the request argument. If no request is passed, then control
  # passes on, without checking, to the next handler, if there is one.
  #
  # This handler can be used at the head of a handler set as a gatekeeper to processs
  # only those files that have been modified.
  #
  ifModifiedSince:
    exec: (file, request, callback) ->
      files = if file.children? then file.children else [ file ]

      if not request? or not request.headers? or not request.headers["if-modified-since"]?
        if @next?
          @next.exec file, request, (response) ->
            callback response
        else
          callback status: 304
      else
        Busser.mtimeScanner files, (mtime) ->
          if mtime > Date.parse(request.headers["if-modified-since"])
            if @next?
              @next.exec file, request, (response) ->
                response.lastModified = (if mtime is 0 then undefined else mtime)
                callback response
            else
              callback status: 304
          else
            callback status: 304

  # The *cache* handler creates a cache if it doesn't exist. The first time
  # control passes through here for a given file, the downstream response for
  # the file is cached. Subsequent calls for the file will get the cached value.
  #
  # The *cache* handler can be used at the head of a handler set to avoid unneeded
  # processing.
  #
  cache:
    exec: (file, request, callback) ->
      @cache ?= {}

      if not @cache[file.path]?
        if @next?
          @next.exec file, request, (response) =>
            @cache[file.path] = response
            callback response
        else
          @cache[file.path] = null   # Or ""? [TODO]
          callback @cache[file.path]
      else
        callback @cache[file.path]

  # The *contentType* handler adds the content type of the file to the response for
  # the handler set.
  #
  contentType:
    exec: (file, request, callback) ->
      contentTypes =
        ".js": "text/javascript; charset=utf-8"
        ".css": "text/css; charset=utf-8"
        ".png": "image/png"
        ".jpg": "image/jpeg"
        ".gif": "image/gif"
        ".json": "application/json"
        ".svg": "image/svg+xml"
    
      if @next?
        @next.exec file, request, (response) ->
          response.contentType = contentTypes[extname(file.path)]
          callback response
      else
        callback contentType: contentTypes[extname(file.path)]

  # *minifyStylesheet* is a static utility method that uses yuicompressor
  # to minify data. 
  #
  @minifyStylesheet: (dataToMinify, callback) ->
    class Minifier extends process.EventEmitter
      constructor: (@incomingData) ->
        @minifiedData = ''

      minify: ->
        min = spawn("java", [ "-jar", path_module.join(__dirname, "..", "bin", "yuicompressor-2.4.7.jar"), "--type", "css" ])
        min.stdout.on "data", (newData) =>
          @minifiedData += newData
        min.stderr.on "data", (data) ->
          util.print data
        min.on "exit", (code) =>
          util.puts "ERROR: Minifier exited with code #{code}" if code isnt 0
          @emit 'end'
        min.stdin.write @incomingData
        min.stdin.end()

    minifier = new Minifier(dataToMinify)
    minifier.on "end", ->
      callback minifier.minifiedData
    minifier.minify()

  # *minifyScript* is a static utility method that uses uglify to minify data. 
  #
  @minifyScript: (dataToMinify, callback) ->
    class Minifier extends process.EventEmitter
      constructor: (@incomingData) ->
        @minifiedData = ''

      minify: ->
        ast = uglify.parser.parse(@incomingData)
        ast = uglify.processor.ast_mangle(ast)
        ast = uglify.processor.ast_squeeze(ast)
        @minifiedData = uglify.processor.gen_code(ast)
        @emit 'end'

    minifier = new Minifier(dataToMinify)
    minifier.on "end", ->
      callback minifier.minifiedData
    minifier.minify()

  # The *minify* handler minifies the downstream response for stylesheets and scripts. 
  # Stylesheets are minified with yuicompressor. Scripts are minified with uglify.
  #
  minify:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          if isStylesheet(file)
            Busser.minifyStylesheet response.data, (minifiedData) ->
              response.data = minifiedData
              callback response
          else if isScript(file)
            Busser.minifyScript response.data, (minifiedData) ->
              response.data = minifiedData
              callback response
      else
        file.content (err, data) ->
          if err
            throw err
          else
            Busser.minifyScript data, (minifiedData) ->
              callback data: minifiedData

  # The *rewriteSuper* handler replaces instances of sc_super in SproutCore javascript
  # with the magic equivalent: arguments.callee.base.apply(this,arguments).
  #
  rewriteSuper:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          if /sc_super\(\s*[^\)\s]+\s*\)/.test(response.data)
            util.puts "ERROR in #{file.path}: sc_super() should not be called with arguments. Modify the arguments array instead."
          response.data = response.data.replace(/sc_super\(\)/g, "arguments.callee.base.apply(this,arguments)")
          callback response
      else
        file.content (err, data) ->
          if err
            throw err
          else
            callback data: data.replace(/sc_super\(\)/g, "arguments.callee.base.apply(this,arguments)")

  # *rewriteStatic* is a static utility method, pardon the pun, that replaces sc_static or
  # static_url, and their file references, with references to files in the resources 
  # directory, per the format argument.
  #
  # A warning is given if the file in the reference is not found. The reference is tested
  # against the path of the containing framework.
  # 
  @rewriteStatic: (format, file, data) ->
    re = new RegExp("(sc_static|static_url)\\(\\s*['\"](resources/){0,1}(.+?)['\"]\\s*\\)")
    dirname = file.framework.url()

    if data?
      resourceUrls = (resourceFile.url() for resourceFile in file.framework.resourceFiles)
      data = data.toString("utf8").gsub re, (match) =>
        path = path_module.join(dirname, match[3])

        if path not in resourceUrls
          for prefix in [ "", "images" ]
            for extname in ResourceFile.resourceExtensions
              alternatePath = path_module.join(dirname, prefix, match[3] + extname)
              if alternatePath in resourceUrls
                path = alternatePath
                break
    
          unless path in resourceUrls
            util.puts "WARNING: #{path} referenced in #{file.path} but was not found."

        format.replace "%@", path_module.join(@urlPrefix, path)

  # The *rewriteStaticInStylesheet* handler calls the *rewriteStatic* method with the
  # format url('%@') for url references in stylesheets.
  #
  rewriteStaticInStylesheet:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          response.data = Busser.rewriteStatic "url('%@')", file, response.data
          callback response
      else
        file.content (err, data) ->
          if err
            throw err
          else
            callback data: Busser.rewriteStatic "url('%@')", file, data

  # The *rewriteStaticInScript* handler calls the *rewriteStatic* method with the
  # format '%@' for references in javascript.
  #
  rewriteStaticInScript:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          response.data = Busser.rewriteStatic "'%@'", file, response.data
          callback response
      else
        file.content (err, data) ->
          if err
            throw err
          else
            callback data: Busser.rewriteStatic "'%@'", file, data

  # The *rewriteFile* handler replaces instances of direct file references, which
  # are found via __FILE__, with the file url.
  #
  rewriteFile:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          response.data = response.data.replace(/__FILE__/g, file.url())
          callback response
      else
        file.content (err, data) ->
          if err
            throw err
          else
            callback data: data.replace(/__FILE__/g, file.url())

  # The *wrapTest* handler wraps the downstream reponse in an SC.filename reference,
  # which is found via __FILE__.
  #
  wrapTest:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          response.data = """
                          function() {
                            SC.filename = \"__FILE__\";
                            #{response.data}
                          })();
                          """
          callback response
      else
        file.content (err, data) ->
          if err
            throw err
          else
            data = """
                   function() {
                     SC.filename = \"__FILE__\";
                     #{data}
                   })();
                   """
            callback data: data

  # The *join* handler joins any files coming through, and their children, into 
  # a cumulative data array, which is joined upon callback. The callback is fired
  # when the file count from downstream processing is met.
  #
  # If the file has no children, the file's handlerSet is called to process and
  # return data. 
  #
  # If the file has children (It is a virtual file, not present on
  # disk in the original project), handlerSets for the children, which may in
  # turn also have children, are called, perhaps to return data resulting from
  # a large recursive sequence.
  # 
  join:
    exec: (file, request, callback) ->
      data = []

      if not file.children? or file.children.length is 0
        file.handlerSet.exec file, request, (response) ->
          callback data: response.data
      else
        filesForJoin = file.children

        count = filesForJoin.length

        if count is 0
          callback data: ''
        else
          filesForJoin.forEach (file, i) ->
            next = (if @next then @next else file.handlerSet)
            next.exec file, request, (d) ->
              data[i] = d.data
              count -= 1
              callback data: data.join("\n")  if count is 0
            
  # The *symlink* handler can only be run by itself or at the tail end 
  # of a sequence of handlers.
  #
  symlink:
    exec: (file, request, callback) ->
      file.symlink.handlerSet.exec file.symlink, request, callback

  # *lessify* is a static utility method that applies less to data.
  #
  @lessify: (path, data, callback) ->
    parser = new less.Parser(
      optimization: 0
      paths: [ path ]
    )
    parser.parse data, (err, tree) ->
      if err
        util.puts "ERROR: " + err.message
      else
        try
          data = tree.toCSS()
        catch e
          util.puts "ERROR: " + e.message
      callback data

  # The *less* handler applies the less parser to file data.
  #
  less:
    exec: (file, request, callback) ->
      if less? and extname(file.path) is ".less"
        if @next?
          @next.exec file, request, (response) ->
            Busser.lessify file.framework.path, response.data, (lessifiedData) ->
              callback data: lessifiedData
        else
          file.content (err, data) ->
            if err
              throw err
            else
              Busser.lessify file.framework.path, data, (lessifiedData) ->
                callback data: lessifiedData
      else
        if @next?
          @next.exec file, request, (response) ->
            callback response
        else
          file.content (err, data) ->
            throw err  if err else callback data: data

  # The *handlebars* handler treats handlebar template files by stringifying them
  # to prepare for a call to SC.Handlebars.compile(), by wrapping the stringified
  # data in an SC.TEMPLATES directive.
  #
  handlebars:
    exec: (file, request, callback) ->
      if @next?
        @next.exec file, request, (response) ->
          if extname(file.path) is ".handlebars"
            re = /[^\/]+\/templates\/(.+)\.handlebars/
            filename = re.exec(file.url())[1]
            response.data = "SC.TEMPLATES['#{filename}'] = SC.Handlebars.compile(#{JSON.stringify(response.data.toString("utf8"))});"
            callback response
          else
            callback response
      else
        if extname(file.path) is ".handlebars"
          re = /[^\/]+\/templates\/(.+)\.handlebars/
          filename = re.exec(file.url())[1]
          file.content (err, data) ->
            if err
              throw err
            else
              callback data: "SC.TEMPLATES['#{filename}'] = SC.Handlebars.compile(#{JSON.stringify(data.toString("utf8"))});"
        else
          file.content (err, data) ->
            if err
              throw err
            else
              callback data: data

  # The *file* handler must be the only handler in a **HandlerSet** or it must come 
  # at the end of a handler sequence where a file is read.
  #
  # The *file* handler calls file.content() to read data from a file. Calls to
  # file.content() are coordinated by a queue system to stay within a limit
  # for simultaneously open files. (See the content method of the **File** class
  # and the global readFile() and related functions).
  #
  file:
    exec: (file, request, callback) ->
      file.content (err, data) ->
        if err
          throw err
        else
          callback data: if data.length is 0 then "" else data

# The global **Busser** instance is created.
#
busser = new Busser

# *availableHandlerNames* is a convenience method for use by developers in listing
# handlers defined in the **Busser** class. The global instance of busser is queried
# for its own properties, which will include variables and methods, and the
# list returned is filtered for known non-handler properties and methods.
#
availableHandlerNames  = ->
  (h for own h of busser when h not in [ "constructor", "handlerSet", "mtimeScanner", "minifyStylesheet", "minifyScript", "rewriteStatic", "lessify" ])

# **HandlerSet** singletons are used in the specialized File subclasses defined
# below. The names of the handlerSets match the **File** subclasses, generally,
# and there are several with descriptive names.
#
rootContentHtmlHandlerSet = busser.handlerSet("root content html", "/", [ "cache", "contentType", "file" ])
rootSymlinkHandlerSet = busser.handlerSet("root symlink", "/", [ "symlink" ])

stylesheetHandlerSet = busser.handlerSet("stylesheet", "/", ["ifModifiedSince", "contentType", "less", "rewriteStaticInStylesheet", "file"])
minifiedStylesheetHandlerSet = busser.handlerSet("stylesheet", "/", ["ifModifiedSince", "contentType", "minify", "less", "rewriteStaticInStylesheet", "file"])
virtualStylesheetHandlerSet = busser.handlerSet("virtual stylesheet", "/", [ "join" ])

scriptHandlerSet = busser.handlerSet("script", "/", ["ifModifiedSince", "contentType", "rewriteSuper", "rewriteStaticInScript", "handlebars", "file"])
minifiedScriptHandlerSet = busser.handlerSet("script", "/", ["ifModifiedSince", "contentType", "minify", "rewriteSuper", "rewriteStaticInScript", "handlebars", "file"])
virtualScriptHandlerSet = busser.handlerSet("virtual script", "/", [ "join" ])

testHandlerSet = busser.handlerSet("test", "/", [ "contentType", "rewriteFile", "wrapTest", "file" ])
resourceHandlerSet = busser.handlerSet("resource", "/", [ "ifModifiedSince", "contentType", "file" ])
uncombinedScriptHandlerSet = busser.handlerSet("uncombined script", "/", [ "contentType", "file" ])
joinHandlerSet = busser.handlerSet("join only", "/", [ "join" ]) # [TODO] urlPrefix needs to be custom for app?

# -----

# Main Classes
# ============
#
# Framework
# ---------
#
# The **Framework** class contains the build() method and related methods for
# processing files in an on-disk project framework, which is a directory with
# javascript, css, and image files. Frameworks constitute different parts of
# SproutCore itself, such as runtime, foundation, and desktop, as well as 
# add-ons, such as themes like Ace. An application can also be divided into
# frameworks, or it can have dependent frameworks, such as sproutcore-flot,
# a graph-plotting library.
#
# Properties of **Framework** specify basic data and build parameters:
#
# *   *name* -- For SproutCore, e.g., runtime, foundation. Otherwise the name
#            should be the name of the on-disk directory for the framework.
#
# *   *path* -- The path of the framework from the project root directory. For
#            example, if the project name is MyApp, we would expect that the
#            MyApp directory contains an apps directory and a frameworks
#            directory, and perhaps others, such as themes or design. For
#            most projects, all frameworks are kept in frameworks. So,
#            the path for the SproutCore runtime framework would be:
#
#   > frameworks/sproutcore/frameworks/
#   > (And, the same for sproutcore-flot, if used in MyApp).
#
# *   *combineStylesheets* -- If true, a virtual file (one not on disk in the
#                          original project) will be created during build to
#                          hold all stylesheets in the framework, concatenated
#                          as a single in-memory file. A save operation can
#                          later write this out to disk for deployment.
#
# *   *combineScripts* -- Same as combineStylesheets, but for javascript files.
#
# *   *minifyStylesheets* -- If true, stylesheets will be minified with the
#                         yuicompressor utility, whether files are kept
#                         as individual files or combined.
#
# *   *minifyScripts* -- Same as *minifyStylesheets*, but for javascript files.
#
# *   *buildLanguage* -- [TODO] When would you want to have a build language
#                     different for frameworks? If not, remove from here
#                     and leave as an App class property.
#
# The **Framework** class contains arrays for basic types of files:
#
#    > stylesheetFiles, scriptFiles, resourceFiles, testFiles
#
# and for the sorted arrays for stylesheets and scripts, where the sorting
# is done during the build process to sort by dependencies:
#
#    > orderedStylesheetFiles, orderedScriptFiles
#
# and for two possible virtual files containing combined stylesheets or
# scripts, if the booleans for these are set:
#
#    > *virtualStylesheetReference* -- These two are instances of Reference,
#    > *virtualScriptReference*        which is a url-to-file couplet.
#
# The **Framework** class has a *pathsToExlude* property, which is
# an array of paths or regular expressions used to exclude directories. For
# example, a "fixtures" path can be allowed for a development build, but
# excluded for a production build.
#
class Framework
  constructor: (options={}) ->
    @name = null
    @path = null

    @combineStylesheets = false
    @combineScripts = false
    @minifyStylesheets = false
    @minifyScripts = false

    @buildLanguage = "english"

    @stylesheetFiles = []
    @scriptFiles = []
    @resourceFiles = []
    @testFiles = []

    @orderedStylesheetFiles = []
    @orderedScriptFiles = []

    @virtualStylesheetReference = null
    @virtualScriptReference = null

    @pathsToExclude = [ /(^\.|\/\.|tmp\/|debug\/|tests\/|test_suites\/|setup_body_class_names)/ ]

    @[key] = options[key] for own key of options

    if options.pathsToExclude?
      if options.pathsToExclude instanceof Array
        @pathsToExclude = @pathsToExclude.concat(options.pathsToExclude)
      else
        @pathsToExclude.push options.pathsToExclude if options.pathsToExclude instanceof RegExp

  addStylesheetFile: (path) ->
    if @minifyStylesheets
      @stylesheetFiles.push(new MinifiedStylesheetFile({ path: path, framework: this }))
    else
      @stylesheetFiles.push(new StylesheetFile({ path: path, framework: this }))

  addScriptFile: (path) ->
    if @minifyScripts
      @scriptFiles.push(new MinifiedScriptFile({ path: path, framework: this }))
    else
      @scriptFiles.push(new ScriptFile({ path: path, framework: this }))

  addTestFile: (path) ->
    @testFiles.push(new TestFile({ path: path, framework: this }))

  addResourceFile: (path) ->
    @resourceFiles.push(new ResourceFile({ path: path, framework: this }))

  # The allFiles method returns virtual (combined) files, if defined, and also
  # the individual stylesheet, script, test, and resource files, as a concatenated
  # list.
  #
  allFiles: ->
    all = []
    all.push @virtualStylesheetReference.file if @virtualStylesheetReference?
    all.push @virtualScriptReference.file if @virtualScriptReference?
    all.push(file) for file in @stylesheetFiles # [TODO] Should this be ordered?
    all.push(file) for file in @scriptFiles
    all.push(file) for file in @testFiles
    all.push(file) for file in @resourceFiles
    all

  # Frameworks are known in a built or deployed project by their names and are
  # referred to with file urls, so the paths in the original project can be
  # simplified by omitting common path elements. For example,
  #
  #     '/frameworks/sproutcore/frameworks/runtime/system/index_set.js'
  #
  #   becomes
  #
  #     '/sproutcore/runtime/system/index_set.js'
  #
  reducedPathFor: (path) ->
    path.replace /(^apps|frameworks|^themes|([a-z]+)\.lproj|resources)\//g, ""
  
  # A url consists of the joined buildVersion and reducedPath.
  #
  urlFor: (path) ->
    path_module.join @buildVersion, @reducedPathFor(path)
  
  # Same as *reducedPathFor*, as a convenience call for reducedPathFor(@path).
  #
  reducedPath: ->
    @reducedPathFor(@path)
  
  # The url for this framework is made by urlFor @path, reduced.
  #
  url: ->
    @urlFor(@reducedPath())
  
  # *shouldExcludeFile* first operates on *pathsToExclude*, checking if the path 
  # matches any exluded path. Then it checks if *buildLanguage* is in allowed
  # lists.
  #
  shouldExcludeFile: (path) ->
    for re in @pathsToExclude
      return true if re.test(path)
    lang = languageInPath(path)
    if not lang?
      return false
    else if lang in [ @buildLanguage, defaultLanguage, buildLanguageAbbreviation(@buildLanguage) ]
      return false
    true
  
  headFile: ->
    null

  tailFile: ->
    new File(
      path: path_module.join(@path, "after.js")
      framework: this
      content: (callback) =>
        callback null, "; if ((typeof SC !== \"undefined\") && SC && SC.bundleDidLoad) SC.bundleDidLoad(\"#{@reducedPath()}\");\n"
      handlerSet: uncombinedScriptHandlerSet
    )

  # *computeDependencies* uses a **DependenciesComputer** class and its compute
  # method to read a list of files, parsing each for require statements,
  # and making a list of urls, built from paths of dependencies, with .js 
  # added, in each file's new deps array.
  #
  # When finished, the callback is fired with the list of files, which then
  # have their .deps arrays added.
  #
  computeDependencies: (files, callback) ->
    class FileDependenciesComputer
      constructor: (@file, @framework) ->

      readFileAndCompute: (callbackAfterFileDependencies) ->
        readFile @file.path, (err, data) =>
          throw err  if err
          @file.deps = []
          re = new RegExp("require\\([\"'](.*?)[\"']\\)", "g")
          while match = re.exec(data)
            path = match[1]
            path += ".js"  unless /\.js$/.test(path)
            @file.deps.push @framework.urlFor(path_module.join(@framework.path, path))
          callbackAfterFileDependencies()

    class DependenciesComputer extends process.EventEmitter
      constructor: (@files=[], @framework) ->
        @count = @files.length

      compute: ->
        if @count > 0
          for file in @files
            fdc = new FileDependenciesComputer(file, @framework)
            fdc.readFileAndCompute =>
              @count -= 1
              @emit 'end' if @count <= 0
        else
          @emit 'end'

    dependencyComputer = new DependenciesComputer(files, this)
    if callback?
      dependencyComputer.addListener 'end', -> callback files
    dependencyComputer.compute()
  
  # *sortDependencies* is a recursive method working on a list of javascript files
  # received from *computeDependencies*, which has added a .deps array for each file.
  # *sortDependencies* searches the dependency urls in deps for the matching
  # file for each, recursively continuing until a file with no dependencies is found
  # and added to the sorted results. In this way, dependent files are added to the
  # orderedFiles array ahead of files requiring them.
  #
  # In the event of a failed find, a console warning is issued for the dependency.
  #
  sortDependencies: (file, orderedFiles, files, recursionHistory) ->
    recursionHistory = []  if not recursionHistory?

    if file in recursionHistory
      return
    else
      recursionHistory.push file

    if file not in orderedFiles
      if file.deps?
        for url in file.deps
          len = files.length
          found = false
          i = 0
          while i < len
            if files[i].url() is url
              found = true
              @sortDependencies files[i], orderedFiles, files, recursionHistory
              break
            ++i
          if not found
            util.puts "WARNING: #{url} is required in #{file.url()} but does not exist."
      orderedFiles.push file
  
  # The *orderScripts* method calls *computeDependencies* on a list of javascript files,
  # receiving the resulting files, which have had a .deps array added for each, in a
  # callback function which first sorts alphabetically on path, then calls
  # *sortDependencies*, layering the sorting calls based on dependencies of strings.js
  # and core.js, before generally adding the rest. This is to prioritize for i18n
  # definitions in strings.js and then focusing on the most important code, as should
  # be specified in each framework's core.js file.
  #
  orderScripts: (scripts, callback) ->
    @computeDependencies scripts, (scripts) =>
      orderedScriptFiles = []
      coreJs = null
      coreJsPath = path_module.join(@path, "core.js")

      # Order scripts alphabetically by path.
      sortedScripts = scripts.sort((a, b) ->
        a.path.localeCompare b.path
      )

      # Do strings.js first. See if a core.js is found while at it.
      for script in sortedScripts
        @sortDependencies(script, orderedScriptFiles, sortedScripts) if /strings\.js$/.test(script.path)
        coreJs = script  if script.path is coreJsPath

      # Then do core.js and its dependencies, if a core.js is found.
      if coreJs?
        @sortDependencies(coreJs, orderedScriptFiles, sortedScripts)
        for script in sortedScripts
          @sortDependencies(script, orderedScriptFiles, sortedScripts) if script.deps? and coreJs.path in script.deps

      # Then do the rest.
      @sortDependencies(script, orderedScriptFiles, sortedScripts) for script in sortedScripts
  
      continue  while scripts.shift()
      scripts.push i  while i = orderedScriptFiles.shift()
      callback()
 
  # The *bundleInfo* method is unused in the martoche version of garcon, but bundle support was
  # support was added in a branch of the mauritslamers version. 
  #
  bundleInfo: ->
    """
    ;SC.BUNDLE_INFO['#{@reducedPath()}'] = {
      requires: [],
      scripts: [#{(script.url() for script in @orderedScriptFiles)}],
      styles: [#{(stylesheet.url() for stylesheet in @orderedStylesheetFiles)}]
    };
    """

  # The *sproutcoreFrameworks* static method returns a default list of Framework instances, 
  # either with or without jquery, testing for jquery in the project. This method is used
  # in testing, or when a build configuration file is not provided to the build process.
  #
  @sproutcoreFrameworks: (options) ->
    if not @_sproutcoreFrameworks?
      opts =
        combineScripts: true
        pathsToExclude: [ /fixtures\// ]
  
      for key of options
        if key is "pathsToExclude"
          options[key] = []  if not options[key]?
          options[key] = [ options[key] ]  if options[key] instanceof RegExp
          opts[key] = opts[key].concat(options[key])
        else
          opts[key] = options[key]
      try
        fs.statSync "frameworks/sproutcore/frameworks/jquery"
        frameworkNames = [ "jquery", "runtime", "core_foundation", "datetime", "foundation", "datastore", "desktop", "template_view" ]
      catch e
        frameworkNames = [ "runtime", "foundation", "datastore", "desktop", "animation" ]

      @_sproutcoreFrameworks = [ new BootstrapFramework() ]
      for frameworkName in frameworkNames
        opts.name = frameworkName
        opts.path = "frameworks/sproutcore/frameworks/#{frameworkName}"
        @_sproutcoreFrameworks.push(new Framework(opts))

    @_sproutcoreFrameworks
  
  # The *build* method for frameworks first scans for files, adding basic File
  # objects into arrays, excluding files based on checks in *shouldExcludeFile*.
  #
  # Separate arrays are created for stylesheets, scripts, tests, and resources.
  #
  # The finalization steps will order stylesheets and scripts, and prepare any
  # combined virtual files needed.
  #
  # When done, *callbackAfterBuild* is called, if defined.
  #
  build: (callbackAfterBuild) =>
    # The *createBasicFiles* method scans the framework directory for all files,
    # filtering by *shouldExcludeFile*, and creates basic File objects: stylesheets, 
    # scripts, tests, and resources.
    #
    createBasicFiles = (callbackAfterBuild) =>
      class Scanner extends process.EventEmitter
        constructor: (@framework) ->
          @count = 0
  
        scan: (path) ->
          @count += 1
          fs.stat path, (err, stats) =>
            @count -= 1
            throw err  if err
            if stats.isDirectory()
              @count += 1
              fs.readdir path, (err, subpaths) =>
                @count -= 1
                throw err  if err
                @scan path_module.join(path, subpath) for subpath in subpaths when subpath[0] isnt "."
              @emit "end" if @count <= 0
            else
              if not @framework.shouldExcludeFile(path)
                switch fileType(path)
                  when "stylesheet" then @framework.addStylesheetFile(path)
                  when "script" then @framework.addScriptFile(path)
                  when "test" then @framework.addTestFile(path)
                  when "resource" then @framework.addResourceFile(path)
            @emit "end" if @count <= 0
    
      scanner = new Scanner(this)
      scanner.on "end", =>
        finalizeBuild callbackAfterBuild
      scanner.scan @path

    # The *finalizeBuild* method performs ordering and combining steps after
    # basic files have been created.
    #
    finalizeBuild = (callbackAfterBuild) =>
      # Create a virtual stylesheets file if combineStylesheets is set, or sort
      # individual stylesheet files alphabetically. 
      #
      # *orderedStylesheets* will hold either the single virtual file or the sorted 
      # individual stylesheets.
      #
      @orderedStylesheetFiles = []

      if @stylesheetFiles.length > 0
        if @combineStylesheets is true
          virtualStylesheetFile = new VirtualStylesheetFile
            path: "#{@path}.css"
            framework: this
            children: @stylesheetFiles
          @virtualStylesheetReference = new Reference(virtualStylesheetFile.url(), virtualStylesheetFile)
          @orderedStylesheetFiles = [ virtualStylesheetFile ]
        else
          @orderedStylesheetFiles = @stylesheetFiles.sort((a, b) -> a.path.localeCompare b.path)

      # Call *orderScripts* to sort scripts alphabetically then by dependencies.
      # Then create a virtual scripts file if *combineScripts* is set.
      #
      # *orderedScriptFiles* will hold either the single virtual file or the ordered
      # individual script files.
      #
      # Ordering scripts is the last build task before firing the after-build
      # callback, if defined.
      #
      @orderedScriptFiles = []

      if @scriptFiles.length > 0
        @orderScripts @scriptFiles, =>
          if @combineScripts is true
            virtualScriptFile = new VirtualScriptFile
              #path: @path + ".js"
              path: if /\.js$/.test(@path) then @path else "#{@path}.js" # added for temporary special theme.js case [TODO] keep or delete.
              framework: this
              children: (child for child in [@headFile(), @scriptFiles..., @tailFile()] when child?)
            @virtualScriptReference = new Reference(virtualScriptFile.url(), virtualScriptFile)
            @orderedScriptFiles = [ virtualScriptFile ]
          else
            @orderedScriptFiles = (child for child in [@headFile(), @scriptFiles..., @tailFile()] when child?)
          
          console.log "  #{@name} ", "built.".red

          callbackAfterBuild() if callbackAfterBuild?
      else
        console.log "  #{@name} ", "built.".red

        callbackAfterBuild() if callbackAfterBuild?

    # Fire the build methods, passing the provided *callbackAfterBuild*.
    #
    createBasicFiles callbackAfterBuild

# Reference
# ---------
#
# The **Reference** class is a url/file couplet. It is used for html and symlink files, 
# and for the virtual stylesheet and script files.
#
class Reference
  constructor: (@url, @file) ->

# File
# ----
#
# The **File** class holds information about an on-disk file or a virtual file, which is
# an abstraction for a framework directory. The children array is used for virtual
# files, either the **VirtualStylesheetFile** or **VirtualScriptFile** derived classes. The
# handlerSet property has one of the **HandlerSet** singletons defined above, which
# controls the build process for a given file type. A file can be a symlink to the
# root html file, which is only used in **SymlinkFile**.
#
class File
  constructor: (options={}) ->
    @path = null
    @framework = null
    @children = null
    @handlerSet = null
    @isHtml = false
    @isVirtual = false
    @symlink = null

    @[key] = options[key] for own key of options

  url: ->
    @framework.urlFor(@path)
  
  # In *pathForSave*, we see the use of url(), which by itself is used in file lookup,
  # but the file that is saved for *RootHtmlFile* needs a ".html" extension to allow
  # http://localhost:8000/myapp instead of http://localhost:8000/myapp/myapp.html.
  # The symlink handler is involved in linking to the root content.
  #
  pathForSave: ->
    "#{@url()}.html" if @isHtml else @url()
  
  # The *content* method is coordinated with the queue system for managing the number
  # of open files, via the call to readFile to read an on-disk file. This method is 
  # overridden in the **RootHtmlFile** subclass to return html content.
  #
  content: (callback) ->
    readFile @path, callback
  
  # Create a directory, checking the prefix of the path for "." and "/".
  #
  @createDirectory: (path) ->
    prefix = path_module.dirname(path)
    File.createDirectory prefix  if prefix isnt "." and prefix isnt "/"
    try
      fs.mkdirSync path, parseInt("0755", 8)
    catch e
      throw e  if e.code isnt "EEXIST"

# SymlinkFile
# -----------
#
# **SymlinkFile** is used for the instance of a symlink to the root html file.
#
class SymlinkFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = rootSymlinkHandlerSet
    @[key] = options[key] for own key of options

# RootHtmlFile
# -------------------
#
# The **RootHtmlFile** contains the html with main links to a project's stylesheets,
# scripts, and resources. Its rootContentHtmlHandlerSet has cache, contentType, and file
# handlers, so that during serving it is read once, then cached. The **RootHtmlFile**
# is created at the end of the build process, when links to files and resources are known.
#
class RootHtmlFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = rootContentHtmlHandlerSet
    @app = null
    @isHtml = true
    @[key] = options[key] for own key of options

  pathForSave: ->
    "#{@app.url()}.html"

  content: (callback) =>
    html = []

    # Load html for document, head, and meta sections. [TODO] Fix the paths in apple-touch links.
    html.push """ <!DOCTYPE html>
                  <html lang=\"#{buildLanguageAbbreviation()}\">
                    <head>
                      <meta charset=\"utf-8\">
                      <meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\">

                      <meta http-equiv=\"Content-type\" content=\"text/html; charset=utf-8\" />
                      <meta http-equiv=\"Content-Script-Type\" content=\"text/javascript\" />
                      <meta http-equiv="content-script-type" content="text/javascript">
                      <meta name=\"apple-mobile-web-app-capable\" content=\"yes\" />
                      <meta name=\"apple-mobile-web-app-status-bar-style\" content=\"default\" />
                      <meta name=\"viewport\" content=\"initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no\" />

                      <link rel=\"apple-touch-icon\" href=\"frameworks/sproutcore/foundation/resources/images/sproutcore-logo.png\" />
                      <link rel=\"apple-touch-startup-image\" media=\"screen and (orientation:portrait)\" href=\"frameworks/sproutcore/foundation/resources/images/sproutcore-startup-portrait.png\" /> 
                      <link rel=\"apple-touch-startup-image\" media=\"screen and (orientation:landscape)\" href=\"frameworks/sproutcore/foundation/resources/images/sproutcore-startup-landscape.png\" />
                      <link rel=\"shortcut icon\" href=\"frameworks/sproutcore/foundation/resources/images/favicon.ico\" type=\"image/x-icon\" />
              """

    html.push "<title>#{@title}</title>" if @title?

    # Load references to the virtual stylesheet for each framework.
    for framework in @app.frameworks
      for stylesheet in framework.orderedStylesheetFiles
        if stylesheet.framework is framework
          html.push "    <link href=\"#{@app.urlPrefix + stylesheet.url()}\" rel=\"stylesheet\" type=\"text/css\">"

    # Close the head and begin the body.
    html.push "  </head>"
    html.push "  <body class=\"#{@app.theme} focus\">"
    html.push "    <script type=\"text/javascript\">String.preferredLanguage = \"#{buildLanguage}\";</script>"
      
    # Load references to the virtual scripts for each framework.
    for framework in @app.frameworks
      for script in framework.orderedScriptFiles
        html.push "    <script type=\"text/javascript\" src=\"#{@app.urlPrefix + script.url()}\"></script>"
      
    # Close the body and page.
    html.push """ 
                </body>
              </html>
              """
    html = html.join("\n")
      
    callback null, html

# StylesheetFile
# --------------
#
# **StylesheetFile** is a class for .css and related file types.
#
class StylesheetFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = stylesheetHandlerSet
    @[key] = options[key] for own key of options

# MinifiedStylesheetFile 
# ----------------------
#
# **MinifiedStylesheetFile** is a class for .css and related file types, minified.
#
class MinifiedStylesheetFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = minifiedStylesheetHandlerSet
    @[key] = options[key] for own key of options

# ScriptFile
# ----------
#
# **ScriptFile** is a class for .js files.
#
class ScriptFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = scriptHandlerSet
    @[key] = options[key] for own key of options

# MinifiedScriptFile
# ------------------
#
# **MinifiedScriptFile** is a class for .js files, minified.
#
class MinifiedScriptFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = minifiedScriptHandlerSet
    @[key] = options[key] for own key of options

# TestFile
# --------
#
# **TestFile** is a class for .js files used in testing, and are idendified
# as such by matching against a set of known directory names in paths.
#
class TestFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = testHandlerSet
    @[key] = options[key] for own key of options

# ResourceFile
# ------------
#
# **ResourceFile** is a class for a variety of image types used in a project,
# defined in the static property resourceExtensions.
#
class ResourceFile extends File
  constructor: (options={}) ->
    super options
    @handlerSet = resourceHandlerSet
    @[key] = options[key] for own key of options

  @resourceExtensions = ['.png', '.jpg', '.gif', '.svg']

# VirtualStylesheetFile
# ---------------------
#
# The **VirtualStylesheetFile** class is an extension of StylesheetFile, for use in
# handling framework directories that contain individual stylesheet files. So,
# by virtual here, we refer to the fact that the file is not actually found on
# disk in the original project, and exists either only in memory or also as a
# saved combined file, if save operations are directed to make one.
#
class VirtualStylesheetFile extends StylesheetFile
  constructor: (options={}) ->
    super options
    @isVirtual = true
    @children = []
    @handlerSet = virtualStylesheetHandlerSet
    @[key] = options[key] for own key of options

# VirtualScriptFile
# -----------------
#
# The **VirtualScriptFile** extends **ScriptFile**, for use in handling script files in
# a framework. It is identical in structure to **VirtualStylesheetFile**, with the
# addition of two methods, headFile and tailFile, which contain javascript to be
# inserted at the head or tail of the children list of contained scripts. This
# head and tail javascript covers such needs as defining variables and namespaces
# before contained child scripts load and reporting after scripts have loaded.
#
# **VirtualScriptFile** only has tailFile defined, for inclusion of a did-load check.
#
class VirtualScriptFile extends ScriptFile
  constructor: (options={}) ->
    super options
    @isVirtual = true
    @children = []
    @handlerSet = virtualScriptHandlerSet
    @[key] = options[key] for own key of options

# BootstrapFramework
# ------------------
#
# The **BootstrapFramework** class has headFile and tailFile methods that return
# needed script fragments before and after child files in the bootstrap
# framework, the files of which are read from disk in the build procedure.
# headFile and tailFile override methods of the Framework superclass. The
# head file contains main declarations of SC and require. Tail file code
# calls SC.setupBodyClassNames(), once bootrap code has loaded. This function
# is in bootstrap/system/loader.js, where browser-specific tweaks are made for
# setting up the body of the main app html page.
#
class BootstrapFramework extends Framework
  constructor: (options={}) ->
    options.name = "bootstrap"
    options.path = "frameworks/sproutcore/frameworks/bootstrap"
    options.combineScripts = true
    super(options)

  headFile: =>
    new File
      path: path_module.join(@path, "before.js")
      framework: this
      content: (callback) ->
        callback null, """
                       var SC = SC || { BUNDLE_INFO: {}, LAZY_INSTANTIATION: {} };
                       var require = require || function require() {};
                       """
      handlerSet: uncombinedScriptHandlerSet
  
  tailFile: =>
    new File
      path: path_module.join(@path, "after.js")
      framework: this
      content: (callback) ->
        callback null, "; if (SC.setupBodyClassNames) SC.setupBodyClassNames();"
      handlerSet: uncombinedScriptHandlerSet

# App
# ---
#
# The **App** class contains metadata properties for a single SproutCore application, along
# with build-specific properties and their default values. An **App** is **Framework**-like, in
# the similarity of properties. It contains a list of frameworks and a files associative
# array of urls to files, which is set up by a call to registerFiles after the build
# processes complete. This files array is exposed to a server.
#
# *htmlFileReference* and *htmlSymlinkReference* hold links to the root html file.
#
# Principal methods are *build* and *save*.
#
class App
  constructor: (options={}) ->
    @name = null
    @title = null
    @path = null
    @buildLanguage = "english"
    @combineStylesheets = true
    @combineScripts = true
    @minifyScripts = false
    @minifyStylesheets = false

    @urlPrefix = ""
    @theme = "sc-theme"
    @pathForSave = "./build"

    @frameworks = []

    @files = []

    @htmlFileReference = null
    @htmlSymlinkReference = null

    @[key] = options[key] for own key of options

  @buildVersion: 0

  # The *reducedPathFor*, *urlFor*, and *url* methods are the same as those for
  # the **Framework** class, tied here to the prototype definitions.
  #
  reducedPathFor: Framework::reducedPathFor
  reducedPath: Framework::reducedPath
  urlFor: Framework::urlFor
  url: -> Framework::urlFor(@name)
  
  # The *addSproutCore* convenience method adds frameworks returned by the static function
  # *sproutcoreFrameworks* defined in the **Framework** class.
  #
  addSproutCore: (options={}) ->
    @frameworks.push framework for framework in Framework.sproutcoreFrameworks(options)
  
  # *buildRoot* creates the root html file and a symlink to it.
  #
  buildRoot: ->
    # Set a file for the root html content.
    file = new RootHtmlFile
      path: @name
      app: this
      framework: this
    @htmlFileReference = new Reference(file.url(), file)

    # Set a file for a symlink to the root html file.
    symlink = new SymlinkFile
      path: @name
      app: this
      symlink: file
      framework: this
    @htmlSymlinkReference = new Reference(@name, symlink)

  # The *build* method uses the contained **FrameworksBuilder** class to build an app, first
  # calling the app's buildRoot method, then building frameworks in the app.
  # When finished, the callback is called if it is defined.
  #
  # The **FrameworksBuilder** class for the app execs the build methods for the
  # root html content and for the content of each framework.
  # 
  build: (callbackAfterBuild) ->
    class FrameworksBuilder extends process.EventEmitter
      constructor: (@frameworks) ->
        @count = @frameworks.length

      build: ->
        for framework in @frameworks
          framework.build =>
            @count -= 1
            @emit 'end'  if @count <= 0

    @buildRoot()
    builder = new FrameworksBuilder(@frameworks)
    builder.on 'end', =>
      console.log "Build for #{@path} is complete."
      if callbackAfterBuild?
        console.log "Registering files."
        @registerFiles()
        callbackAfterBuild()
    console.log "Build for #{@path} has started."
    builder.build()
    
  # *registerFile* sets the url of the file as the key in the files associative
  # array, which is exposed to the server for file requests.
  #
  registerFile: (url, file) ->
    @files[url] = file

  # *registerFiles* is called after the build process has completed. It resets the 
  # files array, then calls *registerFile* to add back references for the root file
  # and symlink and for the files in child frameworks.
  #
  registerFiles: ->
    @files = []
    @registerFile @htmlFileReference.file.url(), @htmlFileReference.file
    @registerFile @name, @htmlSymlinkReference.file
    for framework in @frameworks
      @registerFile(file.url(), file) for file in framework.allFiles()

  # The *save* method first creates a fresh unique *buildVersion* as a long **Date** instance
  # for the current time, then the contained **Saver** class is used to save child
  # frameworks and usually some combination of combined virtual files. The logic for
  # combining and bundling frameworks and application code flows in a series of if
  # else blocks until the main root html file is writen.
  #
  save: =>
    @buildVersion = new Date().getTime()

    class Saver
      constructor: (@buildVersion, @app, @file) ->
        
      save: ->
        @file.handlerSet.exec @file, null, (response) =>
          if response.data? and response.data.length > 0
            path = path_module.join(@app.pathForSave, @buildVersion.toString(), @file.pathForSave())
            File.createDirectory path_module.dirname(path)
            fs.writeFile path, response.data, (err) ->
              throw err  if err

    for framework in @frameworks
      for file in framework.resourceFiles
        new Saver(@buildVersion, this, file).save()
      if framework.combineStylesheets
        new Saver(@buildVersion, this, framework.virtualStylesheetReference.file) if framework.virtualStyleSheetReference?
      else
        new Saver(@buildVersion, this, file) for file in framework.orderedStylesheetFiles
      if framework.combineScripts
        new Saver(@buildVersion, this, framework.virtualScriptReference.file) if framework.virtualScriptReference?
      else
        new Saver(@buildVersion, this, file) for file in framework.orderedScriptFiles

    if @combineStylesheets
      virtualStylesheetFile = new VirtualStylesheetFile
        path: "#{@name}.css"
        framework: this
        handlerSet: joinHandlerSet
        children: (fw.virtualStylesheetReference.file for fw in @frameworks when fw.virtualStylesheetReference?)
      new Saver(@buildVersion, this, virtualStylesheetFile).save()
    else
      for framework in @frameworks
        for file in framework.orderedStylesheetFiles
          new Saver(@buildVersion, this, file).save()

    if @combineScripts
      virtualScriptFile = new VirtualScriptFile
        path: "{@name}.js"
        framework: this
        handlerSet: joinHandlerSet
        children: (fw.virtualScriptReference.file for fw in @frameworks when fw.virtualScriptReference?)
      new Saver(@buildVersion, this, virtualScriptFile).save()
    else
      for framework in @frameworks
        for file in framework.orderedScriptFiles
          new Saver(@buildVersion, this, file).save()

    if virtualStylesheetFile?
      htmlStylesheetLinks = "<link href=\"#{@urlPrefix + virtualStylesheetFile.url()}\" rel=\"stylesheet\" type=\"text/css\">"
    else
      htmlStylesheetLinks = []
      for fw in @frameworks
        for file in fw.orderedStylesheetFiles
          htmlStylesheetLinks.push "<link href=\"#{@urlPrefix + file.url()}\" rel=\"stylesheet\" type=\"text/css\">"
      htmlStylesheetLinks.join('\n')

    if virtualScriptFile?
      htmlScriptLinks = "<script type=\"text/javascript\" src=\"#{@urlPrefix + virtualScriptFile.url()}\"></script>"
    else
      htmlScriptLinks = []
      for fw in @frameworks
        if fw.virtualScriptFile?
          htmlScriptLinks.push "<link href=\"#{@urlPrefix + fw.virtualScriptFile.url()}\" rel=\"stylesheet\" type=\"text/css\">"
      htmlScriptLinks.join('\n')

    htmlFile = new RootHtmlFile
      path: @name
      app: this
      framework: this

    path = path_module.join(@pathForSave, @buildVersion.toString(), htmlFile.pathForSave())
    File.createDirectory path_module.dirname(path)
    htmlFile.content (data) ->
      fs.writeFile path, data, (err) ->
        throw err  if err


# Proxy
# =====
#
# Proxy properties are configured per app in the json configuration file, so that, for
# example, you could have one dev setup for HelloWorld-dev, which might have one proxy for
# your local backend dev REST server, and a different setup for HelloWorld-dev-images, which
# might also have a second proxy to a local nginx server for testing image uploading.
#
class Proxy
  constructor: (options={}) ->
    @hostname = null
    @port = null
    @prefix = null
    @proxyPrefix = null
    @server = null
    @body = null

    this[key] = options[key] for key of options

    @onData = (chunk) =>
      @body = ""  if @body is null
      @body += chunk

  onEnd: (request, response) =>
    proxyClient = undefined
    proxyRequest = undefined
    body = @["body"] or ""
    bodyLength = body.length
    url = request.url

    errorCallback = (err) =>
      console.log "ERROR: \"#{err.message}\" for proxy request on #{@hostname}:#{@port}"
      response.writeHead 404
      response.end()
      @data = ""

    url = "#{@proxyPrefix}#{url}"  if @proxyPrefix.length > 0 and url.indexOf(@proxyPrefix) < 0

    proxyClient = http.createClient(@port, @hostname)
    proxyClient.addListener "error", errorCallback

    request.headers.host = @hostname

    request.headers["content-length"] = bodyLength
    request.headers["X-Forwarded-Host"] = request.headers.host + ":#{@server.port}"
    request.headers.host += ":#{@port}"  unless @port is 80

    proxyRequest = proxyClient.request(request.method, url, request.headers)

    proxyRequest.write body  if bodyLength > 0

    proxyRequest.addListener "response", (proxyResponse) ->
      response.writeHead proxyResponse.statusCode, proxyResponse.headers
      proxyResponse.addListener "data", (chunk) ->
        response.write chunk
      proxyResponse.addListener "end", ->
        response.end()

    proxyRequest.end()

  proxy: (request, response) ->
    prefix = @prefix
    path = url.parse(request.url).pathname
    if path.substr(0, prefix.length) is prefix
      console.log "Proxying #{request.url}"
      request.addListener "data", (chunk) =>
        @onData.call @, chunk
      request.addListener "end", =>
        @onEnd.call @, request, response
      true
    else
      false

# Server
# ======
#
# You can only have one development server at a time for the client app, so there is a
# short server configuration section at the top of the json configuration file for port
# and hostname, and also allowCrossSiteRequests.
#
class Server
  constructor: (options={}) ->
    @hostname = "localhost"
    @port = 8000
    @allowCrossSiteRequests = false

    @proxyHashes = null
    @proxies = null

    @apps = []

    this[key] = options[key] for key of options

    if @proxyHashes?
      proxyHash["server"] = this for proxyHash in @proxyHashes
      @proxies = (new Proxy(proxyHash) for proxyHash in @proxyHashes)

  shouldProxy: ->
    ((proxy.host? and proxy.port?) for proxy in @proxies).some (bool) -> bool

  addApp: (app) ->
    app = new App(app) unless app instanceof App
    app.server = this
    @apps.push app
    app

  setDirectory: (path) ->
    process.chdir path

  serve: (file, request, response) ->
    file.handlerSet.exec file, request, (r) ->
      headers = {}
      status = 200
      headers["Content-Type"] = r.contentType  if r.contentType?
      headers["Last-Modified"] = r.lastModified.format("httpDateTime")  if r.lastModified?
      status = r.status  if r.status?
      if @allowCrossSiteRequests
        headers["Access-Control-Allow-Origin"] = "*"
        if request.headers["access-control-request-headers"]
          headers["Access-Control-Allow-Headers"] = request.headers["access-control-request-headers"]
      response.writeHead status, headers
      response.write r.data, "utf8"  if r.data?
      response.end()
  
  file: (path) ->
    file = null
    for app in @apps
      file = app.files[path]
      return file if file?
    file

  run: ->
    http.createServer(
      (request, response) =>
        path = url.parse(request.url).pathname.slice(1)
        file = @file(path)
        if not file?
          if @shouldProxy()
            proxyResponded = false
            for p in @proxies
              proxyResponded = p.proxy(request, response)
              break if proxyResponded
          else
            response.writeHead 404
            response.end()
        else
          @serve file, request, response
    ).listen @port, @hostname, =>
      app_url = url.format
        protocol: "http"
        hostname: @hostname
        port: @port
      console.log "Server started on #{app_url}/APPLICATION_NAME"
      console.log '  HOSTNAME:', @hostname
      console.log '  PORT:', @port

# -----
 
# Instantiation and Execution
# ===========================
#
exec = (appTargets, actionItems) ->
  defaultAppDevConf = nconf.get("default-app-dev")
  defaultAppProdConf = nconf.get("default-app-prod")
  defaultFrameworksDevConf = nconf.get("default-sc-frameworks-dev")
  defaultFrameworksProdConf = nconf.get("default-sc-frameworks-prod")
  
  apps = []
  appConfigurations = nconf.get("apps")
  for own key of appConfigurations
    appKey = key
    if appKey in appTargets
      appConf = appConfigurations[appKey]
      myApp = new App
        name: appConf["name"]
        title: appConf["title"]
        path: appConf["path"]
        theme: appConf["theme"]
        buildLanguage: appConf["buildLanguage"]
        combineScripts: appConf["combineScripts"]
        combineStylesheets: appConf["combineStylesheets"]
        minifyScripts: appConf["minifyScripts"]
        minifyStylesheets: appConf["minifyStylesheets"]
  
      myApp.frameworks = []
      myApp.frameworks.push new BootstrapFramework()
  
      for fwConf in appConf["sc-frameworks"]
        switch fwConf.conf
          when "dev" then myApp.frameworks.push new Framework(defaultFrameworksDevConf[fwConf.name])
          when "prod" then myApp.frameworks.push new Framework(defaultFrameworksProdConf[fwConf.name])
          when fwConf.conf instanceof String # The default for unknown is dev.
            myApp.frameworks.push new Framework(defaultFrameworksDevConf[fwConf.name])
          when fwConf.conf instanceof Object
            myApp.frameworks.push new Framework(fwConf.conf)
  
      for fwConf in appConf["custom-frameworks"]
        if fwConf.conf instanceof Object
          myApp.frameworks.push new Framework(fwConf.conf)
    
      myApp.frameworks.push new Framework
        name: myApp.name
        path: "apps/#{myApp.name}"
        combineScripts: true
        combineStylesheets: true
        minifyScripts: false
        minifyStylesheets: false
        
      switch actionItems
        when "build" then myApp.build()
        when "buildsave" then myApp.build(myApp.save)
        when "buildrun" then myApp.build ->
          serverHash = nconf.get('server')
          server = new Server
            hostname: serverHash['hostname']
            port: serverHash['port']
            allowCrossSiteRequests: serverHash['allowCrossSiteRequests']
            proxyHashes: appConf.proxies
          server.addApp(myApp)
          server.run()
        when "buildsaverun" then myApp.build ->
          myApp.save()
          serverHash = nconf.get('server')
          server = new Server
            hostname: serverHash['hostname']
            port: serverHash['port']
            allowCrossSiteRequests: serverHash['allowCrossSiteRequests']
            proxyHashes: appConf.proxies
          server.addApp(myApp)
          server.run()

# Initialize nconf for command line arguments and for environmental settings
#
nconf.argv().env()

# If the operating mode is to use prompt, which we determine by checking for 
# an arg length of 2 (node bin/busser.js), we use the prompt system. Otherwise,
# in the else below, startup will initialize from command line arguments and/or
# environment settings.
#
if process.argv.length is 2
  prompt.message = "Question!".blue
  prompt.delimiter = ">|".green

  prompt.start()
  
  prompts = []

  prompts.push
    name: "configPath"
    message: "Config path?".magenta
  prompts.push
    name: "appTargets"
    validator: appTargetsValidator
    warning: 'Target names have letters, numbers, or dashes, and are comma-delimited. No quotes are needed.'
    message: "Target(s)?".magenta
  prompts.push
    name: "actions"
    validator: actionsValidator
    warning: 'Actions are one or more of: build, save, and run, in any order, and comma-delimited. No quotes are needed.'
    message: "Action(s)?".magenta

  prompt.get prompts, (err, result) ->
    if result.configPath?
      console.log "You said your config path is: ".cyan + result.configPath.cyan
      try
        config_file = fs.readFileSync(result.configPath, "utf-8")
        nconf.argv().env().file file: result.configPath
      catch err
        console.log "Problem reading custom config file"
    
    if result.appTargets? and result.actions?
      appTargets = parseAppTargetsArgument result.appTargets
      actionItems = parseActionsArgument result.actions

      console.log "Performing: #{actionItems}".cyan
      
      exec appTargets, actionItems
    else
      console.log "Valid target(s) and action are needed... Please try again... Aborting."
else
  # All info is provided as command line arguments, or from environment settings. nconf
  # will be initialized with these, and will also be given the config file specified in
  # the config command line argument.
  # 
  # First, parse the config path, which for the command line argument '--config' is used,
  # and not the configPath internal name used in the prompt menu. The default config path
  # is conf/busser.json.
  #
  if nconf.get('config')?
    try
      config_file = fs.readFileSync(nconf.get('config'), "utf-8")
      nconf.argv().env().file file: nconf.get('config')
    catch err
      console.log "Problem reading custom config file"
  else
    nconf.argv().env().file file: "./conf/busser.json"

  # Prepare to catch command line argument parsing errors, for appTargets and actions.
  #
  errors = []

  # Parse appTargets.
  #
  if nconf.get('appTargets')?
    if appTargetsValidator.exec(nconf.get('appTargets'))
      appTargets = parseAppTargetsArgument nconf.get("appTargets")
    else
      errors.push "appTargets did not parse."
  else
    errors.push "appTargets argument is missing."
      
  # Parse actions.
  #
  if nconf.get('actions')?
    if actionsValidator.exec(nconf.get('actions'))
      actionItems = parseActionsArgument nconf.get('actions')
    else
      errors.push "actions did not parse."
  else
    errors.push "actions argument is missing."

  # Report errors or execute.
  #
  if errors.length > 0
    console.log errors
  else
    exec appTargets, actionItems

