util          = require "util"
fs            = require "fs"
path_module   = require "path"
microtime     = require "microtime"
sys           = require "sys"
gm            = require "../node_modules/gm"
stylus        = require "stylus"
mkdirp        = require "mkdirp"
SC            = require "sc-runtime"
StringScanner = require("strscan").StringScanner

# Tidbit: nice trick Maurits uses to count blanks at start of line
# /\s+/.exec(line)[0].length
#

# PORTED FROM: SproutCore's Abbot build tool system, from the Chance css processing
#              tool primarily written by Alex Iskander (all in Ruby).
#
# PORTING NOTE: Porting the Ruby code in the original Chance proceeded by first
# concatenating all code into this source file, followed by arrangment in several
# CoffeeScript classes matching main Ruby modules, with some combining as noted:
#
# * **ChanceParser**, from *abbot/vendor/chance/lib/chance/parser.rb*
# * **ChanceProcessor**, from *abbot/vendor/chance/lib/chance/instance*, combining here:
#     * *abbot/vendor/lib/chance/instance/data_url.rb*
#     * *abbot/vendor/lib/chance/instance/javascript.rb*
#     * *abbot/vendor/lib/chance/instance/slicing.rb*
#     * *abbot/vendor/lib/chance/instance/spriting.rb*
# * **ChanceProcessorFactory**, from *abbot/vendor/chance/lib/chance/factory.rb*
# * **Chance**, from the *abbot/vendor/chance/lib/chance* main module, and chance.rb
#
# Comments and function names were kept largely intact. Ruby and CoffeeScript are
# similar in many respects, so the port was fairly direct, leaving only a few
# challenging conversions.
#
# Javascript code examples and projects were found to match those used in Ruby Chance:
#
# * LeastCommonMultiple, a class here, to match Ruby's lcm
# * String::gsub, a String prototype extension
# * String::beginsWith, a String prototype extension
# * String::endsWith, a String prototype extension
# * strscan.StringScanner, a port of Ruby's StringScanner
# * extname, a function which uses the node.js path module
# * microtime.nowDouble(), replacing Time.now.to_f in Ruby
# * underscore sortBy, a convenience array sorting function, replacing the Ruby sortBy
# * sc-runtime, SproutCore runtime utility methods
#
# The graphics handling parts of Ruby Chance were more challenging to write in
# CoffeeScript Chance, not just for the style of programming, but for finding a
# suitable easy-to-install replacement system. At the time of this writing, the node.js
# graphicsmagick wrapper, gm, is being tried as the main workhorse.
#

# mkdir_p, as used in Ruby Chance, ported to CoffeeScript from:
#
# https://gist.github.com/742162
#
mkdir_p = (path, mode, callback, position) ->
  mode = mode or 0o777
  position = position or 0
  parts = path_module.normalize(path).split("/")
  if position >= parts.length
    if callback?
      return callback()
    else
      return true
  directory = parts.slice(0, position + 1).join("/")
  fs.stat directory, (err) ->
    if not err?
      mkdir_p path, mode, callback, position + 1
    else
      fs.mkdir directory, mode, (err) ->
        if err
          if callback
            callback err
          else
            throw err
        else
          mkdir_p path, mode, callback, position + 1

# Least Common Multiple
#
# Converted from http://en.wikipedia.org/wiki/JavaScript
#
class LCMCalculator
  constructor: (x, y) ->
    checkInt = (x) ->
      throw new TypeError(x + " is not an integer")  if x % 1 isnt 0
      x
    @a = checkInt(x)
    @b = checkInt(y)

  gcd: ->
    a = Math.abs(@a)
    b = Math.abs(@b)
    t = 0
    if a < b
      t = b
      b = a
      a = t
    while b isnt 0
      t = b
      b = a % b
      a = t
    this["gcd"] = ->
      a
    a

  lcm: ->
    lcm = @a / @gcd() * @b
    @lcm = ->
      lcm
    lcm

# String Substitution
# -------------------
#
# *gsub*, from Ruby, is added to the prototyp of String here. See:
# http://flochip.com/2011/09/06/rubys-string-gsub-in-javascript/
#
String::gsub = (re, callback) ->
  result = ""
  source = this
  while source.length > 0
    if match = re.exec source
      result += source.slice(0, match.index)
      result += callback match
      source = source.slice(match.index + match[0].length)
    else
      result += source
      source = ""
  result

# An async gsub from Maurits Lamers
#
#   https://gist.github.com/981bae47adaf3f8ae7d2
#
String::async_gsub = (source,regex,matcher,matchertarget,callback,callbacktarget) ->
  result = []
  matchercalls = []
  count = 0
    
  report_creator = (match,index) ->
    reporter = (newdata) ->
      result[index] = newdata
      if count is matchercalls.length
        callback.call callbacktarget,result.join("")
      
    return () ->
      matcher.call(matchertarget,SC.copy(match),reporter)
        
  while source.length > 0
    match = regex.exec source
    if match?
      result.push source.slice(0, match.index)
      result_index = result.push "" # placeholder
      matchercalls.push report_creator
      source = source.slice match.index + match[0].length # strip the match from source
    else
      result.push source
      source = ""
    
  callback.call(callbacktarget, result.join("")) if matchercalls.length is 0 else m() for m in matchercalls
  

String::beginsWith = (str) -> if @match(new RegExp "^#{str}") then true else false
String::endsWith = (str) -> if @match(new RegExp "#{str}$") then true else false

# Use the node.js path module to pull the file extension from the path.
#
extname = (path) ->
  path_module.extname path

#
# THE CHANCE PARSER
#
# The parser will not bother splitting into tokens. We are _a_
# step up from Regular Expressions, not a thousand steps.
#
# In short, we keep track of two things: { } and strings.
#
# Other than that, we look for @theme, slices(), and slice(),
# in their various forms.
#
# Our method is to scan until we hit a delimiter followed by any
# of the following:
#
# - @theme
# - @include slices(
# - slices(
# - slice(
#
# Options
# --------------------------------
# You may pass a few configuration options to a Chance instance:
#
# - :theme: a selector that will make up the initial value of the $theme
#   variable. For example: :theme => "ace.test-controls"
#
# How Slice & Slices work
# -------------------------------
# @include slice() and @include slices() are not actually responsible
# for slicing the image. They do not know the image's width or height.
#
# All that they do is determine the slice's configuration, including
# its file name, the rectangle to slice, etc.
#
class ChanceParser
  constructor: (@input, @opts={theme:""}) ->
    @path = ""
    @css = ""
    @scanner = null
    @image_names = {}

    @opts[key] = @opts[key] for own key of @opts

    @slices = @opts["slices"]  # we update the slices given to us
    @theme = @opts["theme"]
    @frameworkName = @opts["frameworkName"]

    #console.log 'ChanceParser...', @frameworkName

  @UNTIL_SINGLE_QUOTE: /(?!\\)'/
  @UNTIL_DOUBLE_QUOTE: /(?!\\)"/
  @BEGIN_SCOPE: /\{/
  @END_SCOPE: /\}/
  @THEME_DIRECTIVE: /@theme\s*/
  @SELECTOR_THEME_VARIABLE: /\$theme(?=[^\w:-])/
  @INCLUDE_SLICES_DIRECTIVE: /@include\s+slices\s*/
  @INCLUDE_SLICE_DIRECTIVE: /@include\s+slice\s*/
  @CHANCE_FILE_DIRECTIVE: /@_chance_file /
  @NORMAL_SCAN_UNTIL: /[^{}@$]+/

  # SLICE MANAGEMENT
  # -----------------------
  create_slice: (opts) ->
    filename = opts["filename"]

    #console.log 'CREATE_SLICE', filename

    # get current relative path
    relative = path_module.dirname(@path)

    # Create a path
    path = path_module.join(relative, filename)
    path = path[2...path.length] if path[0..1] is "./"

    opts[path] = path
    opts = @normalize_rectangle(opts)

    slice_path = path[0...(path.length - extname(filename).length)]

    # we add a bit to the path: the slice info
    rect_params = [ "left", "top", "width", "height", "bottom", "right", "offset_x", "offset_y" ]

    # Generate string-compatible params
    slice_name_params = []
    for param in rect_params
      slice_name_params.push opts[param] ? ""
    slice_name_params.unshift slice_path

    # validate and convert to integers
    for param in rect_params
      value = opts[param]
      opts[param] = parseInt(value) if value?

    # it is too expensive to open the images and get their sizes at this point, though
    # I rather would like to.transform the rectangle into absolute coordinates
    # (left top width height) and use that instead of showing all six digits.
    slice_path = ("#{param}" for param in slice_name_params).join("_")

    if slice_path of @slices
      slice = @slices[slice_path]
      slice["min_offset_x"] = Math.min [slice["min_offset_x"], opts["offset_x"]]...
      slice["min_offset_y"] = Math.min [slice["min_offset_y"], opts["offset_y"]]...

      slice["max_offset_x"] = Math.max [slice["max_offset_x"], opts["offset_x"]]...
      slice["max_offset_y"] = Math.max [slice["max_offset_y"], opts["offset_y"]]...
    else
      modified_path = "#{@opts["instance_id"]}".replace(/[^a-zA-Z0-9]/, '_', 'g') + "_" + slice_path.replace(/[^a-zA-Z0-9]/, '_', 'g')
      css_name = "__chance_slice_#{modified_path}"

      newOpts =
        name: slice_path
        path: path
        css_name: css_name
        min_offset_x: opts["offset_x"] # these will be taken into account when spriting.
        min_offset_y: opts["offset_y"]
        max_offset_x: opts["offset_x"]
        max_offset_y: opts["offset_y"]
        imaged_offset_x: 0 # the imaging process will re-define these.
        imaged_offset_y: 0
        used_by: []

      opts[key] = value for own key,value of newOpts

      slice = opts

      @slices[slice_path] = slice

    # Register target path with this slice.
    slice["used_by"].push { path: @path }
    slice

  normalize_rectangle: (rect) ->
    # try to make the rectangle somewhat standard: that is, make it have
    # all units which make sense

    # it must have either a left or a right, no matter what
    rect.left = 0 if not rect.left? and not rect.right?

    # if there is no width, it must have a both left and right
    if not rect.width?
      rect.left = 0 ? rect.left
      rect.right ?= 0

    # it must have either a top or a bottom, no matter what
    rect.top = 0 if not rect.top? and not rect.bottom?

    # if there is no height, it must have _both_ top and bottom
    if not rect.height?
      rect.top ?= 0
      rect.bottom ?= 0

    rect

  # PARSING
  # -----------------------
  parse: ->
    #console.log 'parse'
    @scanner = new StringScanner(@input)
    @image_names = {}
    @css = @_parse()

    if not @scanner.hasTerminated()
      # how do we do an error?
      console.log "Found end of block; expecting end of file."

  # _parse will parse until it finds either the end or until it finds
  # an unmatched ending brace. An unmatched ending brace is assumed
  # to mean that this is a recursive call.
  _parse: ->
    #console.log '_parse'
    scanner = @scanner

    output = []

    while not scanner.hasTerminated()
      output.push @handle_empty()
      break if scanner.hasTerminated()

      #console.log 'rem', scanner.getPosition(), output

      if scanner.check ChanceParser.BEGIN_SCOPE
        output.push @handle_scope()
      else if scanner.check ChanceParser.THEME_DIRECTIVE
        output.push @handle_theme()
      else if scanner.check ChanceParser.SELECTOR_THEME_VARIABLE
        output.push @handle_theme_variable()
      else if scanner.check ChanceParser.INCLUDE_SLICES_DIRECTIVE
        output.push @handle_slices()
      else if scanner.check ChanceParser.INCLUDE_SLICE_DIRECTIVE
        output.push @handle_slice_include()
      else if scanner.check ChanceParser.CHANCE_FILE_DIRECTIVE
        @handle_file_change()

      break if scanner.check ChanceParser.END_SCOPE

      # skip over anything that our tokens do not start with
      res = scanner.scan ChanceParser.NORMAL_SCAN_UNTIL
      if not res?
        output.push scanner.scanChar()
      else
        output.push res

    output.join("")
    #console.log 'final parsed output', output.length

  handle_comment: ->
      #console.log 'handle_comment'
    scanner = @scanner
    scanner.scanChar() # /
    scanner.scanChar() # *
    scanner.scanUntil /\*\//

  replace_unescaped_quotes: (target) ->
    result = ''
    cursor = 0
    while cursor < target.length-2
      pair = target[cursor...cursor+2]
      if cursor is 0 and pair[0] is '"'
        result += "\\\""
        cursor += 1
      else if pair[1] is '"' and pair[0] isnt '\\'
        result += "#{target[cursor]}\\\""
        cursor += 2
      else
        result += target[cursor]
        cursor += 1
    if target[target.length-1] is '"' and target[target.length-2] isnt '\\'
      result += "\\#{target[target.length-1]}"
    else
      result += target[target.length-2..target.length-1]
    result

  parse_string: (cssString) ->
    console.log 'parse_string', cssString
    # I cheat: to parse strings, I use JSON.
    if cssString[0..0] is "'" #[TODO] indices?
      # We should still be able to use json to parse single-quoted strings
      # if we replace the quotes with double-quotes. The methodology should
      # be identical so long as we replace any unescaped quotes...
      #cssString = "\"#{cssString[1...cssString.length-1].replace(/^"|([^\\]")/, '\\"', 'g')}\"" # [TODO] BROKEN: Added temporary \ in front of the 1 (bug in CS).
      cssString = "\"#{@replace_unescaped_quotes cssString[1...cssString.length-1]}\""
      #console.log 'REPLACED DOUBLE QUOTES:', cssString
    else if cssString[0..0] isnt '"'
      #console.log 'ERROR string is not delimited by quotes!', cssString # This is not an error -- if not in quotes, just return cssString.
      return cssString

    #console.log 'JSON parsed string', JSON.parse("[#{cssString}]")[0]
    JSON.parse("[#{cssString}]")[0]

  handle_string: ->
      #console.log 'handle_string'
    scanner = @scanner

    str = scanner.scanChar()
    str += scanner.scanUntil(if str is "'" then ChanceParser.UNTIL_SINGLE_QUOTE else ChanceParser.UNTIL_DOUBLE_QUOTE)
    str

  handle_empty: ->
      #console.log 'handle_empty'
    scanner = @scanner
    output = ""

    while true # [TODO] do? break? next statements were removed, and else if statements added
      if scanner.check /\s+/
        output += scanner.scan /\s+/
        continue
      if scanner.check /\/\//
        scanner.scanUntil /\n/
        continue
      if scanner.check /\/\*/
        @handle_comment()
        continue
      break

    #console.log 'handle_empty', output
    output

  handle_scope: ->
    #console.log 'handle_scope'
    scanner = @scanner

    scanner.scan /\{/

    output = '{'
    output += @_parse()
    output += '}'

    console.log "Expected end of block." unless scanner.scan /\}/

    output

  handle_theme: ->
    console.log 'handle_theme'
    scanner = @scanner
    scanner.scan ChanceParser.THEME_DIRECTIVE

    theme_name = scanner.scan /\((.+?)\)\s*/
    if not theme_name?
      console.log "Expected (theme-name) after @theme"

    console.log "Expected { after @theme." unless scanner.scan /\{/

    # calculate new theme name
    old_theme = @theme
    @theme = old_theme + "." + theme_name

    output = ""
    output += "\n$theme: '#{@theme}';\n"
    output += @_parse()

    @theme = old_theme
    output += "$theme: '#{@theme}';\n"

    console.log "Expected end of block." unless scanner.scan /\}/
    output

  handle_theme_variable: ->
    #console.log 'handle_theme_variable'
    scanner = @scanner
    scanner.scan ChanceParser.SELECTOR_THEME_VARIABLE

    output = "\#{$theme}" # [TODO] Careful, this is literal.
    output

  # when we receive a @_chance_file directive, it means that our current file
  # scope has changed. We need to know this because we parse the combined file
  # rather than the individual pieces, yet we have paths relative to the original
  # files.
  handle_file_change: ->
    #console.log 'handle_file_change'
    scanner = @scanner
    scanner.scan ChanceParser.CHANCE_FILE_DIRECTIVE

    path = scanner.scanUntil /;/
    path = path[0...path.length-1] # -1 to trim semicolon from end

    #console.log 'HANDLE_FILE_CHANGE path', path

    @path = path

  parse_argument: ->
    #console.log 'parse_argument'
    scanner = @scanner

    # We do not care for whitespace or comments
    @handle_empty()

    # this is the final value; we won't actually set it until
    # the very end.
    value = null

    # this holds the value as we are parsing it
    parsing_value = ""

    # The key MAY be present if we are starting with a $.
    # But remember: it could be $abc: $abc + $def
    key = "no_key"
    if scanner.check(/\$/)
      scanner.scan /\$/

      @handle_empty()
      parsing_value = scanner.scan(/[a-zA-Z_-][a-zA-Z0-9+_-]*/)

      console.log "Expected a valid key." if not parsing_value? # [TODO] Why if not key? in Ruby code? Look at Ruby Chance.

      @handle_empty()

      if scanner.scan(/:/)
        # ok, it was a key
        key = parsing_value # [TODO] In ruby, was key = parsing_value.intern; that just converts key to string, apparently.
        parsing_value = ""

        @handle_empty()

    value = null

    # we stop when we either a) reach the end of the arglist, or
    # b) reach the end of the argument. Argument ends at ',', list ends
    # at ')'
    parsing_value += @handle_empty()

    #console.log 'parsing_value_1', parsing_value

    until scanner.check(/[,)]/) or scanner.hasTerminated()
      if scanner.check(/["']/)
        parsing_value += @handle_string()
        #console.log 'parsing_value_2', parsing_value
        parsing_value += @handle_empty()
        #console.log 'parsing_value_3', parsing_value
        continue

      parsing_value += scanner.scanChar()
      #console.log 'parsing_value_4', parsing_value
      parsing_value += @handle_empty()
      #console.log 'parsing_value_5', parsing_value

    value = parsing_value unless parsing_value.length is 0

    #console.log "key: #{key}, value: #{value}"

    { key: key, value: value }

  # Parses a list of arguments, INCLUDING beginning AND ending parentheses.
  #
  parse_argument_list: ->
    #console.log 'parse_argument_list'
    scanner = @scanner

    console.log "Expected ( to begin argument list." unless scanner.scan /\(/

    idx = 0
    args = {}
    until scanner.check(/\)/) or scanner.hasTerminated()
      arg = @parse_argument()
      if arg["key"] is "no_key"
        arg["key"] = idx
        idx += 1

      #console.log "key: #{arg['key']}, value: #{arg['value']}"
      args[arg["key"]] = arg["value"].trim()

      scanner.scan /,/

    scanner.scan /\)/

    args

  generate_slice_include: (slice) ->
    # The argument list is rather raw. We need to combine it with default values,
    # and preprocess any arguments, before we can call create_slice to get the real
    # slice definition.
    #
    slice["offset"] = "0 0" if not slice["offset"]?
    slice["repeat"] = "no-repeat" if not slice["repeat"]?

    # The offset will be given to us as one string; however, it has two parts.
    # splitting by whitespace doesn't handle everything, so we may want to refine
    # this at some point unless we could just pass the whole offset to the offset
    # function somehow.
    #
    offset = slice["offset"].trim().split(/\s+/) # [TODO] does javascript split take re?
    slice["offset_x"] = offset[0]
    slice["offset_y"] = offset[1]

    slice = @create_slice slice

    output = ""
    output += "@extend .#{slice["css_name"].replace(/\//g, '_')};\n" # [TODO] hack to replace / with _, because stylus errors on /

    # We prefix with -chance; this should let everything be passed through more
    # or less as-is. Postprocessing will turn it into -background-position.
    #
    output += "-chance-offset: \"#{slice["name"]}\" #{offset[0]} #{offset[1]};\n" # [TODO] Fix missing indent and also \n in Ruby Chance.
    output += "background-repeat: #{slice["repeat"]}"
    output
    
  handle_slice_include: ->
    #console.log 'handle_slice_include'
    scanner = @scanner
    scanner.scan /@include slice\s*/

    slice = @parse_argument_list()

    # the image could be quoted or not; in any case, use parse_string to
    # parse it. Sure, at the moment, we don't parse quoted strings properly,
    # but it should work for most cases. single-quoted strings are out, though...
    #console.log 'ADDING FRAMEWORK NAME', @frameworkName, @parse_string slice[0]
    slice["filename"] = "#{@frameworkName}/#{@parse_string slice[0]}"

    # now that we have all of the info, we can get the actual slice information.
    # This process will create a slice entry if needed.
    @generate_slice_include(slice)

  should_include_slice: (slice) ->
    return true if not slice["width"]?
    return true if not slice["height"]?
    return false if slice["width"] is 0
    return false if slice["height"] is 0
    true

  slice_layout: (slice)->
    output = ""

    layout_properties = [ "left", "top", "right", "bottom" ]

    if not slice["right"]? or not slice["left"]?
      layout_properties.push("width")

    if not slice["bottom"]? or not slice["top"]?
      layout_properties.push("height")

    for prop in layout_properties
      if slice[prop]?
        output += "  #{prop}: #{slice[prop]}px; \n" # [TODO] Added two leading spaces

    output

  handle_slices: ->
    scanner = @scanner
    scanner.scan /@include slices\s*/

    slice_arguments = @parse_argument_list()

    # slices() only supports four-param, left top right bottom rectangles.
    for key in [ "top", "left", "bottom", "right" ]
      slice_arguments[key] = if slice_arguments[key]? then parseInt(slice_arguments[key]) else 0

    values = slice_arguments.values

    left = slice_arguments["left"]
    top = slice_arguments["top"]
    right = slice_arguments["right"]
    bottom = slice_arguments["bottom"]

    # determine fill method
    fill = slice_arguments["fill"] ? "1 0"
    fill = fill.trim().split(/\s+/)
    fill_width = parseInt(fill[0])
    fill_height = parseInt(fill[1])

    # skip control
    skip = slice_arguments["skip"]
    if not skip?
      skip = []
    else
      skip = skip.split /\s+/

    skip_top_left = 'top-left' in skip
    skip_top = 'top' in skip
    skip_top_right = 'top-right' in skip

    skip_left = 'left' in skip
    skip_middle = 'middle' in skip
    skip_right = 'right' in skip

    skip_bottom_left = 'bottom-left' in skip
    skip_bottom = 'bottom' in skip
    skip_bottom_right = 'bottom-right' in skip

    #console.log 'ADDING FRAMEWORK NAME - plural slices', @frameworkName, @parse_string slice[0]
    filename = "#{@frameworkName}/#{@parse_string slice_arguments[0]}"

    # we are going to form 9 slices. If any are empty we'll skip them

    # top-left
    top_left_slice =
      left: 0
      top: 0
      width: left
      height: top
      sprite_anchor: slice_arguments["top-left-anchor"]
      sprite_padding: slice_arguments["top-left-padding"]
      offset: slice_arguments["top-left-offset"]
      filename: filename

    left_slice =
      left: 0
      top: top
      width: left
      sprite_anchor: slice_arguments["left-anchor"]
      sprite_padding: slice_arguments["left-padding"]
      offset: slice_arguments["left-offset"]
      filename: filename
      repeat: if fill_height is 0 then null else "repeat-y" # [TODO] using null where nil was in ruby
      # we fill in either height or bottom, depending on fill

    bottom_left_slice =
      left: 0
      bottom: 0
      width: left
      height: bottom
      sprite_anchor: slice_arguments["bottom-left-anchor"]
      sprite_padding: slice_arguments["bottom-left-padding"]
      offset: slice_arguments["bottom-left-offset"]
      filename: filename

    top_slice =
      left: left
      top: 0
      height: top
      sprite_anchor: slice_arguments["top-anchor"]
      sprite_padding: slice_arguments["top-padding"]
      offset: slice_arguments["top-offset"]
      filename: filename
      repeat: if fill_width is 0 then null else "repeat-x"
      # we fill in either width or right, depending on fill

    middle_slice =
      left: left
      top: top
      sprite_anchor: slice_arguments["middle-anchor"]
      sprite_padding: slice_arguments["middle-padding"]
      offset: slice_arguments["middle-offset"]
      filename: filename
      repeat: if fill_height isnt 0 then (if fill_width isnt 0 then "repeat" else "repeat-y") else (if fill_width isnt 0 then "repeat-x" else null)
      # fill in width, height or right, bottom depending on fill settings

    bottom_slice =
      left: left
      bottom: 0
      height: bottom
      sprite_anchor: slice_arguments["bottom-anchor"]
      sprite_padding: slice_arguments["bottom-padding"]
      offset: slice_arguments["bottom-offset"]
      filename: filename
      repeat: if fill_width is 0 then null else "repeat-x"
      # we fill in width or right depending on fill settings

    top_right_slice =
      right: 0
      top: 0
      width: right
      height: top
      sprite_anchor: slice_arguments["top-right-anchor"]
      sprite_padding: slice_arguments["top-right-padding"]
      offset: slice_arguments["top-right-offset"]
      filename: filename

    right_slice =
      right: 0
      top: top
      width: right
      sprite_anchor: slice_arguments["right-anchor"]
      sprite_padding: slice_arguments["right-padding"]
      offset: slice_arguments["right-offset"]
      filename: filename
      repeat: if fill_height is 0 then null else "repeat-y"
      # we fill in either height or top depending on fill settings

    bottom_right_slice =
      right: 0
      bottom: 0
      width: right
      height: bottom
      sprite_anchor: slice_arguments["bottom-right-anchor"]
      sprite_padding: slice_arguments["bottom-right-padding"]
      offset: slice_arguments["bottom-right-offset"]
      filename: filename

    if fill_width is 0
      top_slice["right"] = right
      middle_slice["right"] = right
      bottom_slice["right"] = right
    else
      top_slice["width"] = fill_width
      middle_slice["width"] = fill_width
      bottom_slice["width"] = fill_width

    if fill_height is 0
      left_slice["bottom"] = bottom
      middle_slice["bottom"] = bottom
      right_slice["bottom"] = bottom
    else
      left_slice["height"] = fill_height
      middle_slice["height"] = fill_height
      right_slice["height"] = fill_height

    output = ""

    # LEFT
    # NOTE: we write it even if we are supposed to skip; we only wrap the slice include portion in
    if @should_include_slice top_left_slice  # [TODO] in ruby was, should_include_slice?(top_left_slice), but it is just a boolean call?
      output += "& > .top-left {\n"
      # IF we are skipping the top left slice, we don't want the actual slice include-- but the layout
      # information we still want. So, only bracket the generate_slice_include.
      #
      # Potential issue: slice_layout doesn't handle repeat settings. In theory, this should rarely be
      # an issue (because you aren't setting a background for the skipped slice.
      if not skip_top_left
        output += "#{@generate_slice_include top_left_slice};"
      output += "\n  position: absolute;\n"
      output += @slice_layout top_left_slice
      output += "}\n"

    if @should_include_slice left_slice
      output += "& > .left {\n"
      if not skip_left
        output += "#{@generate_slice_include left_slice};"
      output += "\n  position: absolute;\n"
      left_slice["bottom"] = bottom
      output += @slice_layout left_slice
      output += "}\n"

    if @should_include_slice bottom_left_slice
      output += "& > .bottom-left {\n"
      if not skip_bottom_left
        output += "#{@generate_slice_include bottom_left_slice};"
      output += "\n  position: absolute;\n"
      output += @slice_layout bottom_left_slice
      output += "}\n"

    # MIDDLE
    if @should_include_slice top_slice
      output += "& > .top {\n"
      if not skip_top
        output += "#{@generate_slice_include top_slice};"
      output += "\n  position: absolute;\n"
      top_slice["right"] = right
      output += @slice_layout top_slice
      output += "}\n"

    if @should_include_slice middle_slice
      output += "& > .middle {\n"
      if not skip_middle
        output += "#{@generate_slice_include middle_slice};"
      output += "\n  position: absolute;\n"
      middle_slice["bottom"] = bottom
      middle_slice["right"] = right
      output += @slice_layout middle_slice
      output += "}\n"

    if @should_include_slice bottom_slice
      output += "& > .bottom {\n"
      if not skip_bottom
        output += "#{@generate_slice_include bottom_slice};"
      output += "\n  position: absolute;\n"
      bottom_slice["right"] = right
      output += @slice_layout bottom_slice
      output += "}\n"

    # RIGHT
    if @should_include_slice top_right_slice
      output += "& > .top-right {\n"
      if not skip_top_right
        output += "#{@generate_slice_include top_right_slice};"
      output += "\n  position: absolute;\n"
      output += @slice_layout top_right_slice
      output += "}\n"

    if @should_include_slice right_slice
      output += "& > .right {\n"
      if not skip_right
        output += "#{@generate_slice_include right_slice};"
      output += "\n  position: absolute;\n"
      right_slice["bottom"] = bottom
      output += @slice_layout right_slice
      output += "}\n"

    if @should_include_slice bottom_right_slice
      output += "& > .bottom-right {\n"
      if not skip_bottom_right
        output += "#{@generate_slice_include bottom_right_slice};"
      output += "\n  position: absolute;\n"
      output += @slice_layout bottom_right_slice
      output += "}\n"

    output

# In a SproutCore package, a ChanceProcessor "instance" would likely be a language folder.
#
# An instance has a list of files (instance-relative paths mapped
# to paths already registered). This collection of files
# should include CSS files, image files, and any other kind of file
# needed to generate the output.
#
# When you call update(), ChanceProcessor will process everything (or
# re-process it) and put the result in its "css" property.
#
# NOTE: The x2 machinery is for retina displays.
#
class ChanceProcessor
  @CHANCE_FILES =
    "chance.css":
      method: "css"
    "chance@2x.css":
      method: "css"
      x2: true
    "chance-sprited.css":
      method: "css"
      sprited: true
    "chance-sprited@2x.css":
      method: "css"
      sprited: true
      x2: true
    "chance-test.css":       # For Testing Purposes...
      method: "chance_test"

  @uid: 0
  @generation: 0

  constructor: (@chance, @options={}) ->
    #console.log 'ChanceProcessor...', @options
    @options[key] = options[key] for own key of options
    @options["theme"] ?= ""
    @options["optimizeSprites"] ?= true
    @options["padSpritesForDebugging"] ?= true
    if options["theme"]? and options["theme"].length > 0 and options["theme"][0] isnt "."
      @options["theme"] = ".#{options["theme"]}"

    @frameworkName = @options["frameworkName"]

    #console.log 'ChanceProcessor...', @frameworkName
    #console.log 'cssTheme', @options["theme"]

    ChanceProcessor.uid += 1
    @uid = ChanceProcessor.uid
    @options["instance_id"] ?= @uid

    #console.log 'options[instance_id] is', @options["instance_id"]
      
    # The mapped files are a map from file names in the ChanceProcessor instance to
    # their identifiers in the system.
    @mapped_files = {}
      
    # The file mtimes are a collection of mtimes for all the files we have. Each time we
    # read a file we record the mtime, and then we compare on check_all_files
    @file_mtimes = {}

    # The @files set is a set cached generated output files, used by the output_for
    # method.
    @files = {}

    # The @slices hash maps slice names to hashes defining the slices. As the
    # processing occurs, the slice hashes may contain actual sliced image canvases,
    # may be 2x or 1x versions, etc.
    @slices = {}

    # Tracks whether _render has been called.
    @has_rendered = false
      
    # A generation number for the current render. This allows the slicing and spriting
    # to be invalidated smartly.
    @render_cycle = 0

    # The parsed css.
    @cssParsed = ""

  # maps a path relative to the instance to a file identifier
  # registered with chance via ChanceProcessor.addFile.
  #
  # If a ChanceProcessor instance represents a SproutCore language folder,
  # the relative path would be the path inside of that folder.
  # The identifier would be a name of a file that you added to
  # to the system using add_file.
  #
  map_file: (path, identifier) ->
    if @mapped_files[path] is identifier
      # Don't do anything if there is nothing to do.
      return
      
    path = "#{path}" # [TODO] doesn't this accomplish a conversion to string?
    file = @chance.has_file(identifier)

    new FileNotFoundError(path).message() unless file?

    @mapped_files[path] = identifier

    # Invalidate our render because things have changed.
    @clean()

  # unmaps a path from its identifier. In short, removes a file
  # from this ChanceProcessor instance. The file will remain in the system's "virtual filesystem".
  unmap_file: (path) ->
    if path not of @mapped_files
      # Don't do anything if there is nothing to do
      return
    
    path = "#{path}"
    @mapped_files.delete path

    # Invalidate our render because things have changed.
    @clean()
    
  # unmaps all files
  unmap_all: ->
    @mapped_files = {}

  # checks all files to see if they have changed
  check_all_files: ->
    needs_clean = false
    for own p,f of @mapped_files
      mtime = @chance.update_file_if_needed(f)
      if not @file_mtimes[p]? or mtime > @file_mtimes[p]
        needs_clean = true
    
    @clean() if needs_clean

  # Using a path relative to this instance, gets an actual system file
  # hash, with any necessary preprocessing already performed. For instance,
  # content will have been read, and if it is an image file, will have been
  # loaded as an actual image.
  #
  get_file: (path) ->
    new FileNotFoundError(path).message() unless path of @mapped_files
    @chance.get_file(@mapped_files[path])

  output_for: (file) ->
    #console.log 'output_for', @chance.files[file]?, file
    return @chance.files[file] if @chance.files[file]?

    # small hack: we are going to determine whether it is x2 by whether it has
    # @2x in the name.
    x2 = if file.indexOf "@2x" isnt -1 then true else false

    opts = ChanceProcessor.CHANCE_FILES[file]

    if opts?
      @[opts["method"]] opts
    else if file in @sprite_names({ x2: x2 })
      return @sprite_data({ name: file, x2: x2 })
    else
      console.log "ChanceProcessor does not generate a file named '#{file}'" if not opts?

  # Generates CSS output according to the options provided.
  #
  # Possible options:
  #
  #   :x2         If true, will generate the @2x version.
  #   :sprited    If true, will use sprites rather than data uris.
  #
  css: (opts) ->
    #console.log 'chance css called'
    @_render()
    #console.log 'after _render()'
    @slice_images opts
    #console.log 'after slice_images'
    ret = @_postprocess_css opts
    #console.log 'after _postprocess_css', ret
    ret

  # Looks up a slice that has been found by parsing the CSS. This is used by
  # the Sass extensions that handle writing things like slice offset, etc.
  get_slice: (name) ->
    @slices[name]

  # Cleans the current render, getting rid of all generated output.
  clean: ->
    @has_rendered = false
    @files = {}

  # Generates output for tests.
  chance_test: (opts) ->
    ".hello { background: static_url('test.png'); }"

  # Processes the input CSS, producing CSS ready for post-processing.
  # This is the first step in the ChanceProcessor build process, and is usually
  # called by the output_for() method. It produces a raw, unfinished CSS file.
  _render: ->
    #console.log '_render, has_rendered is', @has_rendered
    return if @has_rendered

    # Update the render cycle to invalidate sprites, slices, etc.
    @render_cycle += 1
    
    @files = {}

    try
      #console.log 'in the try'
      # SCSS code executing needs to know what the current instance of ChanceProcessor is,
      # so that lookups for slices, etc. work.
      #
      Chance._current_instance = @

      # Step 1: preprocess CSS, determining order and parsing the slices out.
      # The output of this process is a "virtual" file that imports all of the
      # SCSS files used by this ChanceProcessor instance. This also sets up the @slices hash.
      #
      import_css = @_preprocess()

      #console.log 'import_css', import_css
      
      # Because we encapsulate with instance_id, we should not have collisions even IF another chance
      # instance were running at the same time (which it couldn't; if it were, there'd be MANY other issues)
      #
      image_css_path = path_module.join('./tmp/chance/image_css', "#{@options["instance_id"]}", '_image_css.styl')

      try
        mkdirp.sync(path_module.dirname(image_css_path))
      catch e
        throw e  if e.code isnt "EEXIST"
      
      file = fs.writeFileSync(image_css_path, @_css_for_slices(), "utf-8")
      
      #image_css_path = path_module.join('./tmp/chance/image_css', "#{@options["instance_id"]}", 'image_css') # [TODO] Is there some trick with the missing _ on image_css in Ruby Chance?

      # STEP 2: Preparing input CSS
      # The main CSS file we pass to the Sass Engine will have placeholder CSS for the
      # slices (the details will be postprocessed out).
      # After that, all of the individual files (using the import CSS generated in Step 1)
      #
      cssWithImports = "@import \"#{image_css_path}\";\n" + import_css

      # [TODO] Replace #3 with ... something... stylus?
      #
      # Step 3: Apply Sass Engine
      #
      #console.log 'about to stylus', cssWithImports

      stylus.render cssWithImports, (err, stylusResult) =>
        if err?
          util.puts "ERROR: stylus render " + err.message
        else
          @cssParsed = stylusResult
          #console.log "stylus.render cssParsed result: ", @cssParsed
          @has_rendered = true

      #engine = Sass::Engine.new(css, Compass.sass_engine_options.merge
      #  syntax: scss
      #  filename: "chance_main.css"
      #  cache_location: "./tmp/sass-cache"
      #  style: if @options["minify"] then compressed else expanded # [TODO] What are compressed, expanded? Ah, parameters to Compass.
      #)
      #css = engine.render()

      #@css = css
      #@has_rendered = true
    catch err
      console.log 'ERROR in stylus', err.message
    finally
      Chance._current_instance = null

  # Creates CSS for the slices to be provided to SCSS.
  # This CSS is incomplete; it will need postprocessing. This CSS
  # is generated with the set of slice definitions in @slices; the actual
  # slicing operation has not yet taken place. The postprocessing portion
  # receives sliced versions.
  #
  # Round-trip fixed from mauritslamers garcon.
  #
  _css_for_slices: ->
    #console.log '_css_for_slices', @slices.length
    output = []
    
    for name,slice of @slices
      # Write out comments specifying all the files the slice is used from
      output.push "/* Slice #{name}, used in: \n"
      output.push("\t%@\n".fmt(used_by.path)) for used_by in slice.used_by
      output.push "*/\n"
      output.push ".#{slice.css_name.replace(/\//g, '_')} {\n" # [TODO] This has already been done on the front-end, no?
      output.push "  _sc_chance: \"#{name}\";"
      output.push "\n} \n"

    output.join("")

  # Postprocesses the CSS using either the spriting postprocessor or the
  # data url postprocessor, as specified by opts.
  #
  # Opts:
  #
  # :x2 => whether to generate @2x version.
  # :sprited => whether to use spriting instead of data uris.
  #
  _postprocess_css: (opts) ->
    #console.log '_postprocess_css'
    if opts["sprited"]
      ret = @postprocess_css_sprited(opts)
    else
      ret = @postprocess_css_dataurl(opts)
    
    ret = @_strip_slice_class_names(ret)
  
  #
  # Strips dummy slice class names that were added to the system so that SCSS could do its magic,
  # but which are no longer needed.
  #
  _strip_slice_class_names: (css) ->
    #console.log '_strip_slice_class_names'
    re = /\.__chance_slice[^{]*?,/
    css = css.gsub re, ""
    css

  #
  # COMBINING CSS
  #
  
  # Determines the "Chance Header" to add at the beginning of the file. The
  # Chance Header can set, for instance, the $theme variable.
  #
  # The Chance Header is loaded from the nearest _theme.css file in this folder
  # or a containing folder (the file list specifically ignores such files; they are
  # only used for this purpose)
  #
  # For backwards-compatibility, the fallback if no _theme.css file is present
  # is to return code setting $theme to the now-deprecated @options["theme"].
  #
  chance_header_for_file: (file) ->
    # 'file' is the name of a file, so we actually need to start at dirname(file)
    dir = path_module.dirname(file)
    console.log 'chance_header_for_file', dir
    
    # This should not be slow, as this is just a hash lookup
    while dir.length > 0 and dir isnt "."
      header_file = @mapped_files[path_module.join(dir, "_theme.css")]
      if header_file?
        return @get_file(header_file)
      
      dir = path_module.dirname(dir)
    
    # Make sure to look globally
    header_file = @mapped_files["_theme.css"]
    return @get_file(header_file) if header_file?
    
    console.log 'chance_header_for_file _theme.css not found in mapped_files, so falling back.'

    # mtime never changes (without a restart, at least)
    return { mtime: 0, content: "$theme: '" + @options["theme"] + "';\n" }
  
  #
  # _include_file is the recursive method in the depth-first-search
  # that creates the ordered list of files.
  #
  # To determine if a file is already included, we use the class variable
  # "generation", which we increment each pass.
  #
  # The list is created in the variable @file_list.
  #
  _include_file: (file) ->
    #console.log '_include_file -- does it end in .css', /\.css$/.test(file)
    return if not /\.css$/.test(file)
    
    #console.log 'this is a .css file alright -- is it a _theme.css file?', /_theme\.css$/.test(file)

    # skip _theme.css files
    return if /_theme\.css$/.test(file)

    #console.log 'no, it is not a _theme.css file'

    file = @get_file(file)

    #console.log 'get_file returned a file?', file?
    return if not file?

    #console.log 'file[included] is @generation?', file["included"] is @generation
    return if file["included"] is ChanceProcessor.generation

    #console.log 'setting requires'
    requires = file["requires"]

    file["included"] = ChanceProcessor.generation

    #console.log 'do we have any requries?', requires?

    if requires?
      for r in requires
        # Add the .css extension if needed. it is optional for sc_require
        r = "#{r}.css" if not /\.css$/.test(r)
        #console.log 'including the require', r
        @_include_file(@mapped_files[r])

    #console.log 'including the file in the file_list'
    @file_list.push(file)

  _convert_to_styl_old: (css) ->
    convertedLines = []
    for line in css.split('\n')
      trimmed = line.trim()
      continue if trimmed is '{'
      continue if trimmed is '}'
      line = line.replace('\t', '  ', 'g')
      line = line.replace(':0', ': 0', 'g')
      line = line.replace('{', '', 'g')
      line = line.replace('}', '', 'g')
      line = line.replace(/;\s*?$/g, '') # From garcon: only replace the last semicolon in a line (also if spaces after ;)
      # hacks: if the following string is unquoted, quote it.
      if line.indexOf(" progid:DXImageTransform.Microsoft.Alpha(Opacity=30)") isnt -1
        line = line.replace(' progid', ' \"progid', 'g')
        line = line.replace('=30)', '=30)\"', 'g')
      if line.indexOf(" progid:DXImageTransform.Microsoft.Alpha(Opacity=40)") isnt -1
        line = line.replace(' progid', ' \"progid', 'g')
        line = line.replace('=40)', '=40)\"', 'g')
      if line.indexOf(" progid:DXImageTransform.Microsoft.Alpha(Opacity=50)") isnt -1
        line = line.replace(' progid', ' \"progid', 'g')
        line = line.replace('=50)', '=50)\"', 'g')
      convertedLines.push line if line?
    # hack to check for an empty file, with only the $theme line
    nonBlankLines = (line if line.trim().length > 0 for line in convertedLines)
    if nonBlankLines.length > 1
      convertedLines.join('\n')
    else
      ''

  _convert_to_styl_garcon: (css) ->
    console.log 'converting to styl'
    spacescheck = /^\s*/
    convertedLines = []
    nonBlankLines = []
    
    searchOpeningBrace = (from_i) ->
      for convertedLine,index in convertedLines
        return index if convertedLine.indexOf '{' isnt -1
      return -1 # should not happen normally...
    
    for line,index in css.split("\n")
      trimmed = line.trim()

      continue if trimmed is '' # skip empty lines
      
      if trimmed in ["{", "}"]
        if trimmed is "}"
          openl = searchOpeningBrace index
          if openl >= 0
            indent = spacescheck.exec convertedLines[openl]
            line = indent[0] + "}" if indent
        convertedLines.push line
        continue
      
      line = line.replace(/\t/g, '  ')
      line = line.replace(/:0/g, ': 0')
      #line = line.replace('{', '', 'g')
      #line = line.replace('}', '', 'g')
      line = line.replace(/;\s*?$/g, '') # only replace the last semicolon in a line (also if spaces after ;)
      # data uris without quotes
      if line.search(/url\(data/) >= 0
        line = line.replace(/url\(data/, "url('data").replace(/\)/, "')")

      #line = line.replace(/;/g,"")
      if line.indexOf(" progid:") isnt -1
        line = line.replace(/\sprogid/g, "\"progid").replace(/30\)/g, "30)\"").replace(/40\)/g, "40)\"").replace(/50\)/g, "50)\"")

      indent = spacescheck.exec line

      if indent?
        numspaces = indent[0].length

        if index > 1
          prevline = convertedLines[convertedLines.length-1]
          previndent = spacescheck.exec prevline

          if (numspaces % 2) > 0
            if previndent?
              #tools.log('previndent: ' + tools.inspect(previndent));
              if prevline.indexOf("{") >= 0
                line = line.replace spacescheck, "#{previndent[0]}  "
              else
                line = line.replace spacescheck, previndent[0]
            else
              line = line.replace spacescheck, indent[0].substr(0, indent[0].length-2)

          if numspaces is 0 # if 0, check how much the previous line had
            if previndent? and previndent[0].length isnt 0
              line = previndent[0] + line

          if (numspaces % 2) is 0 # if indent is rest 0, the indent should be the same, unless an { is detected
            if previndent? and previndent[0].length isnt numspaces and prevline? and prevline.indexOf "{" is -1
              line = line.replace spacescheck, previndent[0]

      if line?
        convertedLines.push line
        nonBlankLines.push line.trim().length > 0

    if nonBlankLines.length > 1
      convertedLines.join '\n'
    else
      ''

  # Reference: beautify-css.js in
  #
  #   https://github.com/einars/js-beautify
  #
  _convert_to_styl: (css_input) ->
    class Converter
      constructor: (@css_input, @indentSize=4, @indentCharacter=' ') ->
        @pos = -1
        @ch = ''
        @indentString = @css_input.match(/^[\r\n]*[\t ]*/)[0]
        @singleIndent = Array(@indentSize+1).join(@indentCharacter)
        @indentLevel = 0
        @output = []
    
        @whitespaceRE = /^\s+$/
        @wordRe = /[\w$\-_]/
    
        @output.push @indentString if @indentString
 
      doReplacements: (css_to_fix) ->
        replacedLines = []
        for line in css_to_fix.split('\n')
          line = line.replace(/\t/g, '  ')
          line = line.replace(/:0/g, ': 0')
          line = line.replace(/{\s*?$/g, '') # only replace the last { in a line (handles spaces after {)
          line = line.replace(/}\s*?$/g, '') # only replace the last } in a line (handles spaces after })
          line = line.replace(/;\s*?$/g, '') # only replace the last semicolon in a line (handles spaces after ;)
          # data uris without quotes
          if line.search(/url\(data/) >= 0
            line = line.replace(/url\(data/, "url('data").replace(/\)/, "')")
    
          #line = line.replace(/;/g,"")
          if line.indexOf(" progid:") isnt -1
            line = line.replace(/\sprogid/g, "\"progid").replace(/30\)/g, "30)\"").replace(/40\)/g, "40)\"").replace(/50\)/g, "50)\"")
    
          replacedLines.push line if line.trim().length > 0
        result = replacedLines.join('\n')
        result

      next: ->
        @pos += 1
        #console.log @pos, @ch
        @ch = @css_input.charAt(@pos)
  
      peek: ->
        @css_input.charAt @pos+1
  
      consumeString: (stopChar) ->
        start = @pos
        while @next()
          if @ch is "\\"
            @next()
            @next()
          else if @ch is stopChar
            break
          else break if @ch is "\n"
  
        @css_input.substring start, @pos+1
  
      # Look ahead with @peek(), checking for whitespace.
      # If whitespace, advance.
      # Keep advancing until non-whitespace encountered.
      # If advancement occurred, return true, else false.
      #
      consumeWhitespace: ->
        start = @pos
        @pos++ while @whitespaceRE.test(@peek())
        @pos isnt start
  
      # Call @next() to advance one pos, checking for whitespace.
      # Keep advancing until non-whitespace encountered.
      # If the advancement is not whitespace, return false, else true.
      #
      skipWhitespace: ->
        start = @pos
        loop
          break unless @whitespaceRE.test(@next())
        @pos isnt start+1
  
      # Assume that when called, opening / encountered, so advance one pos.
      # Keep advancing, breaking if */ encountered.
      # Return the substring from the /* through the */.
      #
      consumeComment: ->
        start = @pos
        @next()
        while @next()
          if @ch is "*" and @peek() is "/"
            @pos++
            break
        @css_input.substring start, @pos+1
  
      # Return a slice of the output from index back to str.length.
      # Lowercase str is assumed.
      #
      lookBack: (str, index) ->
        @output.slice(-str.length + (index or 0), index).join("").toLowerCase() is str

      # Increase indentLevel, returning indentString expanded by one indent.
      #
      indent: ->
        @indentLevel++
        @indentString += @singleIndent
    
      # Descrease indentLevel, returning indentString reduced by one indent.
      #
      outdent: ->
        @indentLevel--
        @indentString = @indentString.slice(0, -@indentSize)
  
      handleOpeningBrace: (ch) ->
        @singleSpace()
        @output.push(ch)
        @newLine()
      
      handleClosingBrace: (ch) ->
        @newLine()
        @output.push(ch)
        @newLine()
    
      newLine: (keepWhitespace) ->
        @output.pop() while @whitespaceRE.test(@output[@output.length-1]) unless keepWhitespace
        @output.push "\n" if @output.length
        @output.push @indentString if @indentString
    
      singleSpace: ->
        @output.push " " if @output.length and not @whitespaceRE.test(@output[@output.length-1])
    
      convert: ->
        loop
          isAfterSpace = @skipWhitespace()

          break unless @ch

          if @ch is '{'
            @indent()
            @handleOpeningBrace(@ch)
          else if @ch is '}'
            @outdent()
            @handleClosingBrace(@ch)
          else if @ch is '"' or @ch is '\''
            @output.push @consumeString(@ch)
          else if @ch is ';' # [TODO] But what if the ; is not on the end of the line?
            @output.push(@ch, '\n', @indentString)
          else if @ch is '/' and @peek() is '*'
            @newLine()
            @output.push(@consumeComment(), "\n", @indentString)
          else if @ch is '(' # may be a url
            @output.push @ch
            @consumeWhitespace()
            if @lookBack("url", -1) and @next()
              if @ch isnt ')' and @ch isnt '"' and @ch isnt '\''
                @output.push @consumeString(')')
              else
                @pos -= 1
          else if @ch is ')'
            @output.push @ch
          else if @ch is ','
            @consumeWhitespace()
            @output.push @ch
            @singleSpace()
          else if @ch is ']'
            @output.push @ch
          else if @ch is '[' or @ch is '='
            @consumeWhitespace()
            @output.push @ch # no whitespace before or after
          else
            @singleSpace() if isAfterSpace
            @output.push @ch

        @output = @output.join('').replace(/[\n ]+$/, '')
        @doReplacements(@output)
      
    converter = new Converter(css_input, indentSize=4, indentCharacter=' ')
    output = converter.convert()
    #output = converter.doReplacements(output)
    console.log 'output dammit', output, 'dammit end'
    output
  
  # Determines the order of the files, parses them using ChanceParser,
  # and returns a file with an SCSS @import directive for each file.
  #
  # It also creates and fills in the @slices hash.
  _preprocess: ->
    @slices = {}
    @options["slices"] = @slices

    ChanceProcessor.generation += 1

    #console.log '_preprocess, generation:', ChanceProcessor.generation

    files = (@mapped_files[key] for own key of @mapped_files) # [TODO] files is not used here.
    
    #console.log 'sorting... @mapped_files', @mapped_files

    # We have to sort alphabetically first...
    tmp_file_list = ({path: p, file: f} for own p,f of @mapped_files)
    tmp_file_list = tmp_file_list.sortProperty 'path'

    #console.log 'updating mtimes, and _including_files...', tmp_file_list.length

    # Empty file_list then refresh it with _include_file calls.
    @file_list = []
    for path_and_file in tmp_file_list
      # Save the mtime for caching
      mtime = @chance.update_file_if_needed(path_and_file.file)
      @file_mtimes[path_and_file.path] = mtime
      #console.log path_and_file.path, mtime
      @_include_file(path_and_file.file)

    #console.log 'setting relative_paths'

    relative_paths = {}
    relative_paths[value] = key for own key,value of @mapped_files

    cssImportStatements = []

    #console.log 'after update_file_if_needed, and sorting', @file_list.length

    for file in @file_list
      # NOTE: WE MUST CALL CHANCE PARSER NOW, because it generates our slices.
      # We can't be picky and just call it if something has changed. Thankfully,
      # parser is fast. Unlike SCSS.
      header_file = @chance_header_for_file(relative_paths[file["path"]])
      
      content = "@_chance_file " + relative_paths[file["path"]] + ";\n"
      #console.log 'header_file content', header_file["content"]
      content += header_file["content"]
      #console.log 'file content', file["content"]
      content += file["content"]

      console.log 'new ChanceParser', @options
      parser = new ChanceParser(content, @options)
      parser.parse()
      console.log 'after parser'
      file["parsed_css"] = parser.css

      # We used to use an md5 hash here, but this hides the original file name
      # from SCSS, which makes the file name + line number comments useless.
      #
      # Instead, we sanitize the path.
      #
      re = /[^a-zA-Z0-9\-_\\\/]/
      path_safe = file["path"].replace(re, '-', 'g')

      tmp_path = "./tmp/chance/#{path_safe}.styl"
      tmp2_css_path = "./tmp2/chance/#{path_safe}.css"
      tmp2_styl_path = "./tmp2/chance/#{path_safe}.styl"

      # [TODO] same as for other case of: FileUtils.mkdir_p(path_module.dirname(tmp_path))
      try
        #fs.mkdirSync path_module.dirname(tmp_path), parseInt("0755", 8)
        mkdirp.sync(path_module.dirname(tmp_path))
        mkdirp.sync(path_module.dirname(tmp2_css_path))
        mkdirp.sync(path_module.dirname(tmp2_styl_path))
      catch e
        throw e  if e.code isnt "EEXIST"
      
      console.log 'dirs made'
      console.log 'not?', file["mtime"]
      console.log 'not?', file["wtime"]
      console.log 'or', file["wtime"] < file["mtime"]
      console.log 'or not?', header_file["mtime"]
      console.log 'or', file["wtime"] < header_file["mtime"]
      if (not file["mtime"]? or not file["wtime"]? or file["wtime"] < file["mtime"] or not header_file["mtime"]? or file["wtime"] < header_file["mtime"])
        console.log 'STYL', @_convert_to_styl(parser.css)
        console.log ">>>>>" + parser.css
        f = fs.writeFileSync(tmp2_css_path, parser.css, "utf-8")
        f = fs.writeFileSync(tmp2_styl_path, @_convert_to_styl(parser.css), "utf-8")
        f = fs.writeFileSync(tmp_path, @_convert_to_styl(parser.css), "utf-8")
        file["wtime"] = microtime.nowDouble() # replaces Time.now.to_f in Ruby

      cssImportStatement = "@import \"#{tmp_path}\";"

      cssImportStatements.push cssImportStatement

    cssImportStatements.join("\n")

  # PORTING NOTE: from the original Chance data_url module within the instance module
  #
  postprocess_css_dataurl: (opts) ->
    #console.log 'postprocess_css_dataurl', @cssParsed
    re = /_sc_chance\:\s*["'](.*?)["']\s*/
    css = @cssParsed.gsub re, (match) =>
      slice = @slices[match[1]]

      url = 'data:' + @type_for(slice["path"]) + ";base64,"
      url += @base64_for(slice).replace('\n', '', 'g')

      output = "background-image: url(\"#{url}\");"

      output += "\n"

      # FOR 2X SLICES
      if slice["x2"]?
        width = slice["target_width"]
        height = slice["target_height"]
        output += "\n-webkit-background-size: #{width}px #{height}px;"

      output

    # We do not modify the offset, so we can just pass the original through.
    re = /-chance-offset:\s?"(.*?)" (-?[0-9]+) (-?[0-9]+)/
    css = css.gsub re, (match) =>
      #console.log 'chance-offset matches', match[2], match[3] # [TODO] Does this still work after replacing / with | in the css_name?
      "background-position: #{match[2]}px #{match[3]}px"
    css

  type_for: (path) ->
    if /jpg$/.test(path) then "image/jpeg" else "image/#{extname(path)}"

  base64_for: (slice) ->
    if slice["canvas"]?
      # If the slice has a canvas, we must read from that.
      contents = fs.createReadStream slice["canvas"] # [TODO] was to_blob?
    else
      # Otherwise, this implies the image has not been modified. So, we should
      # be able to write out the original contents from the slice's file.
      contents = slice["file"]["content"]

    # [TODO] should use binary here? Depends on what is used in node.js land, probably.
    new Buffer(contents, 'binary').toString('base64') # replaces Base64.encode64(contents) in ruby

  # PORTING NOTE: from the original Chance javascript module within the instance module
  #
  javascript: (opts) ->
    # Currently, we only include the preload JavaScript
    preload_javascript(opts)

  # Generates the preload JavaScript
  preload_javascript: (opts) ->
    output = "if (typeof CHANCE_SLICES === 'undefined') var CHANCE_SLICES = [];"
    output += "CHANCE_SLICES = CHANCE_SLICES.concat(["
    output += ("'#{slice["css_name"]}'" for name,slice of @slices).join(",\n")
    output += "]);"
    output

  # PORTING NOTE: from the original Chance slicing module within the instance module
  #
  # The Slicing module handles taking a collection of slice definitions to
  # produce sliced images. The sliced image is stored in the slice definition.
  #
  add_canvas_to_cache: (canvas, file, rect) ->
    @canvas_cache = {} if not @canvas_cache?
      
    left = rect["left"]
    top = rect["top"]
    width = rect["width"]
    height = rect["height"]
          
    key = "#{file["path"]}:#{left},#{top},#{width},#{height}"
    @canvas_cache[key] =
      mtime: file["mtime"]
      canvas: canvas
    
  get_canvas_from_cache: (file, rect) ->
    @canvas_cache = {} if not @canvas_cache?
          
    left = rect["left"]
    top = rect["top"]
    width = rect["width"]
    height = rect["height"]
          
    key = "#{file["path"]}:#{left},#{top},#{width},#{height}"
    hash = @canvas_cache[key]
          
    # Check to see if it is new enough
    if hash? and hash["mtime"] is file["mtime"]
      return hash["canvas"]
          
    @canvas_cache[key] = null
    null # [TODO] Why an explicit null return?
      
  # performs the slicing indicated by each slice definition, and puts the resulting
  # image in the slice definition's :image property.
  #
  # if x2 is supplied, this will assume it is a second pass to locate any @2x images
  # and use them to replace the originals.
  #
  slice_images: (opts) ->
    output = ""

    for name,slice of @slices
      # If we modify the canvas, we'll place the modified canvas here.
      # Otherwise, consumers will use slice["file"] ["canvas"] or ["contents"]
      # to get the original data as needed.
      slice["canvas"] = null
          
      # In any case, if there is one, we need to get the original file and canvas;
      # this process also tells us if the slice is 2x, etc.
      #console.log 'slice_images... calling canvas_for slice, opts'
      canvas = @canvas_for slice, opts

      # Check if a canvas is required
      must_slice = [slice["left"], slice["right"], slice["top"], slice["bottom"]].some (bool) -> bool
      if must_slice or slice["x2"]
        if not canvas?
          # [TODO] mention of RMagick, which will be replaced
          throw new TypeError("ChanceProcessor could not load file '#{slice["path"]}'. If it is not a PNG, RMagick is required to slice or use @2x mode.")

        f = slice["proportion"]

        canvas_width = canvas.width
        canvas_height = canvas.height

        if must_slice
          rect = null

          # The math that uses canvas_width and canvas_height needs to return numbers that,
          # when multiplied by f, are valid. So, divide by f first.
          rect = @slice_rect(slice, canvas_width / f, canvas_height / f)

          if rect?
            ## CHECK CACHE ##
            file = @file_for(slice, opts)
            cached_canvas = @get_canvas_from_cache(file, rect)
            if cached_canvas?
              slice["canvas"] = cached_canvas
            else
              slice["canvas"] = gm(canvas).crop(rect["width"] * f, rect["height"] * f, rect["left"] * f, rect["top"] * f)
              @add_canvas_to_cache(slice["canvas"], file, rect)
                
            canvas_width = rect["height"] * f
            canvas_height = rect["width"] * f

        slice["target_width"] = canvas_width / f
        slice["target_height"] = canvas_height / f

  # Opts specify if x2, etc. is allowed.
  #
  canvas_for: (slice, opts) ->
    #console.log 'canvas_for', slice, opts
    file = @file_for(slice, opts)
    #console.log 'canvas_for ... file from file_for call', file
    file["canvas"]

  # Returns the file to use for the specified slice (normal, or @2x)
  #
  # The slice's file property will be set to the system file.
  # If @2x, the x2 flag on the slice is set to true.
  # opts specify if x2, etc. is allowed.
  #
  file_for: (slice, opts) ->
    path = slice["path"]

    # Check for x2 version if we are in x2 mode
    if opts["x2"]
      try
        path_2x = path[0..(-1 - extname(path).length)] + "@2x.png" # [TODO] check end index; in ruby, was: path_2x = path[0..(-1 - File.extname(path).length)] + "@2x.png"

        file = @get_file(path_2x)
        slice["x2"] = true
        slice["proportion"] = 2
      catch err
        console.log "Problem making x2 version for #{path}"
    else
      file = @get_file(path)
      slice["x2"] = false
      slice["proportion"] = 1

    console.log "File does not exist: #{slice["path"]}" unless file?

    slice["file"] = file
    file

  # Creates the final slice rectangle from the image width and height
  # returns null if no rectangle or if the slice is the full image
  slice_rect: (slice, image_width, image_height) ->
    left = slice["left"]
    top = slice["top"]
    bottom = slice["bottom"]
    right = slice["right"]
    width = slice["width"]
    height = slice["height"]

    rect = {}

    if left?
      rect["left"] = left

      # in this case, it must be left+width or left+right, or left-to-end
      if right?
        rect["width"] = image_width - right - left
      else if width?
        rect["width"] = width
      else
        # then this is left-to-end
        rect["width"] = image_width - left
    else if right?
      # in this case it must be right+width or right-to-end
      if width?
        rect["left"] = image_width - width - right
        rect["width"] = width
      else
        rect["left"] = image_width - right
        rect["width"] = right
    else
      rect["left"] = 0
      rect["width"] = image_width

    if top?
      rect["top"] = top

      # in this case, it must be top+height or top+bottom or top-to-bottom
      if bottom?
        rect["height"] = image_height - bottom - top
      else if height?
        rect["height"] = height
      else
        rect["height"] = image_height - top
    else if bottom?
      # in this case it must be bottom+height
      if height?
        rect["top"] = image_height - height - bottom
        rect["height"] = height
      else
        rect["top"] = image_height - bottom
        rect["height"] = bottom
    else
      rect["top"] = 0
      rect["height"] = image_height

    if rect["left"] is 0 and rect["top"] is 0 and rect["width"] is image_width and rect["height"] is image_height
      return null

    return rect

  # PORTING NOTE: from the original Chance spriting module within the instance module

  # Spriting support.
  #
  # The sprite method performs the spriting. It creates collections of
  # images to sprite and then calls layout_sprite and generate_sprite.
  #
  # The layout_sprite method arranges the slices, defining their positions
  # within the sprites.
  #
  # The generate_sprite method combines the slices into an image.
  
  # The Spriting module handles sorting slices into sprites, laying them
  # out within the sprites, and generating the final sprite images.

  # Performs the spriting process on all of the @slices, creating sprite
  # images in the class's @sprites property and updating the individual slices
  # with a :sprite property containing the identifier of the sprite, and offset
  # properties for the offsets within the image.
  generate_sprite_definitions: (opts) ->
    @sprites = {}

    @group_slices_into_sprites opts
    for key,sprite of @sprites
      @layout_slices_in_sprite sprite, opts

  # Determines the appropriate sprite for each slice, creating it if necessary,
  # and puts the slice into that sprite. The appropriate sprite may differ based
  # on the slice's repeat settings, for instance.
  group_slices_into_sprites: (opts) ->
    for key,slice of @slices
      sprite = @sprite_for_slice(slice, opts)
      sprite["slices"].push slice

      @sprites[sprite["name"]] = sprite

  # Returns the sprite to use for the given slice, creating the sprite if needed.
  # The sprite could differ based on repeat settings or file type, for instance.
  sprite_for_slice: (slice, opts) ->
    sprite_name = @sprite_name_for_slice(slice, opts)

    newOpts =
      horizontal_layout: if slice["repeat"] is "repeat-y" then true else false
    opts[key] = value for own key,value of newOpts

    @get_sprite_named sprite_name, opts

    @sprites[sprite_name]

  # Creates a sprite definition with a given name and set of options
  get_sprite_named: (sprite_name, opts) ->
    if not @sprites[sprite_name]?
      @sprites[sprite_name] =
        name: sprite_name
        slices: []
        has_generated: false
        # The sprite will use horizontal layout under repeat-y, where images
        # must stretch all the way from the top to the bottom
        use_horizontal_layout: opts["horizontal_layout"]

  # Determines the name of the sprite for the given slice. The sprite
  # by this name may not exist yet.
  sprite_name_for_slice: (slice, opts) ->
    if slice["repeat"] is "repeat"
      slice["path"] + (if opts["x2"] then "@2x" else "")
    else
      slice["repeat"] + (if opts["x2"] then "@2x" else "") + extname(slice["path"])

  # Performs the layout operation, laying either up-to-down, or "
  # (for repeat-y slices) left-to-right.
  layout_slices_in_sprite: (sprite, opts) ->
    #console.log 'layout_slices_in_sprite', sprite, opts
    # The position is the position in the layout direction. In vertical mode
    # (the usual) it is the Y position.
    pos = 0
    
    # Adds some padding that will be painted with a pattern so that it is apparent that
    # CSS is wrong.
    # NOTE: though this is only in debug mode, we DO need to make sure it is on a 2px boundary.
    # This makes sure 2x works properly.
    padding = if @options["padSpritesForDebugging"] then 2 else 0
    
    # The position within a row. It starts at 0 even if we have padding,
    # because we always just add padding when we set the individual x/y pos.
    inset = 0
    
    # The length of the row. Length, when layout out vertically (the usual), is the height
    row_length = 0

    # The size is the current size of the sprite in the non-layout direction;
    # for example, in the usual, vertical mode, the size is the width.
    #
    # Usually, this is computed as a simple max of itself and the width of any
    # given slice. However, when repeating, the least common multiple is used,
    # and the smallest item is stored as well.
    size = 1
    smallest_size = null

    is_horizontal = sprite["use_horizontal_layout"]
    
    # Figure out slice width/heights. We cannot rely on slicing to do this for us
    # because some images may be being passed through as-is.
    for slice in sprite["slices"]
      # We must find a canvas either on the slice (if it was actually sliced),
      # or on the slice's file. Otherwise, we're in big shit.
      canvas = slice["canvas"] ? slice["file"]["canvas"]
    
      # TODO: MAKE A BETTER ERROR.
      unless canvas
        throw new TypeError("Could not sprite image #{slice["path"]}; if it is not a PNG, make sure you have rmagick installed")
          
      gm(canvas).size (err, data) ->
        if err
          console.log "Error -- sizing canvas image"
        else
          slice_width = canvas.width
          slice_height = canvas.height
      
          slice_length = if is_horizontal then slice_width else slice_height
          slice_size = if is_horizontal then slice_height else slice_width
          
          # When repeating, we must use the least common multiple so that
          # we can ensure the repeat pattern works even with multiple repeat
          # sizes. However, we should take into account how much extra we are
          # adding by tracking the smallest size item as well.
          if slice["repeat"] isnt "no-repeat"
            smallest_size = slice_size if not smallest_size?
            smallest_size = Math.min [slice_size, smallest_size]...
    
            lcmCalculator = new LCMCalculator size, slice_size
            size = lcmCalculator.lcm()
          else
            size = Math.max [size, slice_size + padding * 2]...
          
          slice["slice_width"] = +slice_width
          slice["slice_height"] = +slice_height
        
          # Sort slices from widest/tallest (dependent on is_horizontal) or is_vertical
          # NOTE: This means we are technically sorting reversed
          sprite["slices"].sort (a, b) ->
            # WHY <=> NO WORK?
            if is_horizontal
              -1 if b["slice_height"] < a["slice_height"]
              0 if b["slice_height"] is a["slice_height"]
              1 if b["slice_height"] > a["slice_height"]
            else
              -1 if b["slice_width"] < a["slice_width"]
              0 if b["slice_width"] is a["slice_width"]
              1 if b["slice_width"] > a["slice_width"]
      
          for slice in sprite["slices"]
            # We must find a canvas either on the slice (if it was actually sliced),
            # or on the slice's file. Otherwise, we're in big shit.
            canvas = slice["canvas"] or slice["file"]["canvas"]
                
            slice_width = slice["slice_width"]
            slice_height = slice["slice_height"]
                
            slice_length = if is_horizontal then slice_width else slice_height
            slice_size = if is_horizontal then slice_height else slice_width
                
            if slice["repeat"] isnt "no-repeat" or inset + slice_size + padding * 2 > size or not @options["optimizeSprites"]
              pos += row_length
              inset = 0
              row_length = 0
                  
      
            # We have extras for manual tweaking of offsetx/y. We have to make sure there
            # is padding for this (on either side)
            #
            # We have to add room for the minimum offset by adding to the end, and add
            # room for the max by adding to the front. We only care about it in our
            # layout direction. Otherwise, the slices are flush to the edge, so it won't
            # matter.
            if slice["min_offset_x"] < 0 and is_horizontal
              slice_length -= slice["min_offset_x"]
            else if slice["min_offset_y"] < 0 and not is_horizontal
              slice_length -= slice["min_offset_y"]
      
            if slice["max_offset_x"] > 0 and is_horizontal
              pos += slice["max_offset_x"]
            else if slice["max_offset_y"] > 0 and not is_horizontal
              pos += slice["max_offset_y"]
            
            slice["sprite_slice_x"] = (if is_horizontal then pos else inset)
            slice["sprite_slice_y"] = (if is_horizontal then inset else pos)
            
            # add padding for x, only if it a) doesn't repeat or b) repeats vertically because it has horizontal layout
            if slice["repeat"] is "no-repeat" or slice["repeat"] is "repeat-y"
              slice["sprite_slice_x"] += padding
            
            if slice["repeat"] is "no-repeat" or slice["repeat"] is "repeat-x"
              slice["sprite_slice_y"] += padding
            
            slice["sprite_slice_width"] = slice_width
            slice["sprite_slice_height"] = slice_height
      
            inset += slice_size + padding * 2
            
            # We pad the row length ONLY if it is a repeat-x, repeat-y, or no-repeat image.
            # If it is 'repeat', we do not pad it, because it should be processed raw.
            row_length = Math.max [slice_length + (if slice["repeat"] isnt "repeat" then padding * 2 else 0), row_length]...
            
            # In 2X, make sure we are aligned on a 2px grid.
            # We correct this AFTER positioning because we always position on an even grid anyway;
            # we just may leave that even grid if we have an odd-sized image. We do this after positioning
            # so that the next loop knows if there is space.
            if opts["x2"]
              row_length = Math.ceil(row_length.to_f / 2) * 2
              inset = Math.ceil(inset.to_f / 2) * 2
      
          pos += row_length
      
          # TODO: USE A CONSTANT FOR THIS WARNING
          smallest_size = size if smallest_size is null
          if size - smallest_size > 10
            puts "WARNING: Used more than 10 extra rows or columns to accommodate repeating slices."
            puts "Wasted up to #{(pos * size-smallest_size)} pixels"
      
          sprite["width"] = if is_horizontal then pos else size
          sprite["height"] = if is_horizontal then size else pos
      
  # Generates the image for the specified sprite, putting it in the sprite's
  # canvas property.
  generate_sprite: (sprite) ->
    canvas = @canvas_for_sprite(sprite)
    sprite["canvas"] = canvas
        
    # If we are padding sprites, we should paint the background something really
    # obvious & obnoxious. Say, magenta. That's obnoxious. A nice light purple wouldn't
    # be bad, but magenta... that will stick out like a sore thumb (I hope)
    if @options["padSpritesForDebugging"]
      canvas.region(sprite["width"], sprite["height"], 0, 0).stroke("magenta").fill("magenta")

    for slice in sprite["slices"]
      x = slice["sprite_slice_x"]
      y = slice["sprite_slice_y"]
      width = slice["sprite_slice_width"]
      height = slice["sprite_slice_height"]

      # If it repeats, it needs to go edge-to-edge in one direction
      if slice["repeat"] is 'repeat-y'
        height = sprite["height"]

      if slice["repeat"] is 'repeat-x'
        width = sprite["width"]

      @compose_slice_on_canvas(canvas, slice, x, y, width, height)

  canvas_for_sprite: (sprite) ->
    gm sprite["width"] sprite["height"]

  # Writes a slice to the target canvas, repeating it as necessary to fill the width/height.
  compose_slice_on_canvas: (target, slice, x, y, width, height) ->
    source_canvas = slice["canvas"] or slice["file"]["canvas"]
    source_width = slice["sprite_slice_width"]
    source_height = slice["sprite_slice_height"]

    top = 0
    left = 0

    # Repeat the pattern to fill the width/height.
    while top < height
      left = 0
      while left < width
        gm.draw "-geometry +#{left + x}+#{top + y} #{source_canvas} #{target}"
        left += source_width
        top += source_height

  # Postprocesses the CSS, inserting sprites and defining offsets.
  postprocess_css_sprited: (opts) ->
    # The images should already be sliced appropriately, as we are
    # called by the css method, which calls slice_images.

    # We will need the position of all sprites, so generate the sprite
    # definitions now:
    @generate_sprite_definitions(opts)

    re = /_sc_chance:\s*["'](.*?)["']/
    css = @cssParsed.gsub re, (match) ->
      slice = @slices[match[1]]
      sprite = @sprite_for_slice(slice, opts)

      output = "background-image: chance_file('#{sprite["name"]}')\n"

      if slice["x2"]
        width = sprite["width"] / slice["proportion"]
        height = sprite["height"] / slice["proportion"]
        output += ";  -webkit-background-size: #{width}px #{height}px"

      output

    re = /-chance-offset:\s?"(.*?)" (-?[0-9]+) (-?[0-9]+)/
    css = css.gsub re, (match) ->
      slice = @slices[match[1]]

      slice_x = parseInt(match[2]) - slice["sprite_slice_x"]
      slice_y = parseInt(match[3]) - slice["sprite_slice_y"]

      # If it is 2x, we are scaling the slice down by 2, making all of our
      # positions need to be 1/2 of what they were.
      if slice["x2"]
        slice_x /= slice["proportion"]
        slice_y /= slice["proportion"]

      #console.log 'replacing it'
      "background-position: #{slice_x}px #{slice_y}px"
    css

  sprite_data: (opts) ->
    #console.log 'sprite_data', opts
    @_render()
    @slice_images opts
    @generate_sprite_definitions opts

    sprite = @sprites[opts["name"]]

    # When the sprite is null, it simply means there weren't any images,
    # so this sprite is not needed. But build systems may still
    # expect this file to exist. We'll just make it empty.
    if not sprite?
      return ""

    @generate_sprite(sprite) if not sprite["has_generated"]

    ret = fs.createReadStream slice["canvas"] # [TODO] was to_blob?
        
    if ChanceProcessor.clear_files_immediately
      sprite["canvas"] = null
      sprite["has_generated"] = false

    ret

  sprite_names: (opts={}) ->
    #console.log 'sprite_names', opts
    @_render()
    @slice_images opts
    @generate_sprite_definitions opts

    key for own key,value of @sprites

# PORTING NOTE: from the original Chance ProcessorFactory module.
#
# The ChanceProcessorFactory class is the ChanceProcessor instance factory.
#
# All methods require two parts: a key and a hash of options. The hash will be used in
# the case of a cache missed.
#
class ChanceProcessorFactory
  constructor: (chance) ->
    @chance = chance
    @instances = {}
    @file_hashes = {}

  clear_instances: ->
    @instances = {}
    @file_hashes = {}
    
  instance_for_key: (key, opts) ->
    if key not of @instances
      @instances[key] = new ChanceProcessor(@chance, opts)
      
    return @instances[key]
    
  # Call with a hash that maps instance paths to absolute paths. This will compare with the last.
  #
  update_instance: (key, opts, files) ->
    #console.log 'in update_instance'
    instance = @instance_for_key(key, opts)
    last_hash = @file_hashes[key] ? {}
      
    # If they are not equal, we might as well throw everything. The biggest cost is from
    # ChanceProcessor re-running, and it will have to anyway.
    #
    if last_hash isnt files
      #console.log 'update_instance last_hash isnt files'
      instance.unmap_all
      instance.map_file(path, identifier) for own path,identifier of files
      @file_hashes[key] = files

# PORTING NOTE: simplified from the original Chance version.
#
class FileNotFoundError
  constructor: (@path) ->

  message: ->
    "File not mapped in ChanceProcessor instance: #{@path}"

# PORTING NOTE: from the original Chance module.
#
class Chance
  constructor: ->
    @files = {}
    @_current_instance = null
    @clear_files_immediately = false

  add_file: (path, content=null) ->
    if path of @files
      return @update_file_if_needed(path, content)
      
    mtime = 0
    if not content?
        #      fs.stat path, (err, stats) =>  # [TODO] should use sync version?
        #if err
        #  util.puts "ERROR adding file: " + err.message
        #else
        #  mtime = stats.mtime # [TODO] replaces: mtime = File.mtime(path).to_f
      stats = fs.statSync path

    file =
      mtime: stats.mtime
      path: path
      content: content
      preprocessed: false
      
    @files[path] = file
    #console.log 'chance added', path

  update_file: (@path, @content=null) ->
    #console.log 'update_file'
    if not @files[path]?
      console.log "Could not update #{path} because it is not in system."
      return
      
    mtime = 0
    if not content?
        #      fs.stat path, (err, stats) =>  # [TODO] should use sync version?
        #if err
        #  util.puts "ERROR updating file: " + err.message
        #else
        #  mtime = stats.mtime # [TODO] replaces: mtime = File.mtime(path).to_f

      stats = fs.statSync path

    file =
      mtime: stats.mtime
      path: path
      content: content
      preprocessed: false
      
    @files[path] = file

  # if the path is a valid filesystem path and the mtime has changed, this invalidates
  # the file. Returns the mtime if the file was updated.
  update_file_if_needed: (path, content=null) ->
    #console.log 'update_file_if_needed'
    if @files[path]?
        #      fs.stat path, (err, stats) =>  # [TODO] should use sync version?
        #if err
        #  util.puts "ERROR updating file: " + err.message
        #else
        #  if @files[path]?
        #    if stats.mtime > @files[path]["mtime"]
        #      update_file(path, content)
        #    stats.mtime
        #  else
        #    false

      stats = fs.statSync path

    if @files[path]?
      if stats.mtime > @files[path]["mtime"]
        @update_file(path, content)
      stats.mtime
    else
      false
        
  remove_file: (path) ->
    if not @files[path]?
      console.log "Could not remove #{path} because it is not in system."
      return

    @files.delete(path)
    
  # Removes all files from Chance; used to reset environment for testing.
  remove_all_files: ->
    @files = {}
    
  has_file: (path) ->
    if not @files[path]?
      return false
    true
    
  get_file: (path) ->
    if not @files[path]?
      console.log "Could not find #{path} in Chance."
      return null
    
    file = @files[path]
      
    if not file["content"]?
      # note: CSS files should be opened as UTF-8.
      file["content"] = fs.readFileSync(path, if /css$/.test(path) then 'UTF-8' else 'binary') # [TODO] ruby version had rb for reading binary flag
      
    if not file["preprocessed"]
      @_preprocess file
      
    file

  _preprocess: (file) ->
    @_preprocess_css(file) if /css$/.test(file["path"])
    @_preprocess_image(file) if /png$|gif|jpg$/.test(file["path"])

    file["preprocessed"] = true

  _preprocess_image: (file) ->
    # [TODO] was from_blob?  the Rmagick one needed file["content"][0]
    #console.log 'preprocessing image', file
    #console.log file["content"]
    file["canvas"] = new Buffer(file["content"], 'binary').toString('base64') # replaces Base64.encode64(contents) in ruby

  _preprocess_css: (file) ->
    content = file["content"]

    #console.log 'preprocessing css'

    requires = []
    re = /(sc_)?require\(['"]?(.*?)['"]?\);?/
    content = content.gsub re, (match) ->
      requires.push match[2]
      ""

    # sc_resource will already be handled by the build tool. We just need to ignore it.
    re = /sc_resource\(['"]?(.*?)['"]?\);?/
    content = content.gsub re, ''  # [TODO] is this a replace?

    file["requires"] = requires # [TODO] haven't seen requires get any hits.
    file["content"] = content

exports.ChanceParser = ChanceParser
exports.ChanceProcessor = ChanceProcessor
exports.ChanceProcessorFactory = ChanceProcessorFactory
exports.Chance = Chance
