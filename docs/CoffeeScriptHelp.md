CoffeeScript Help
-----------------

This document describes attractive features of CoffeeScript, with examples from busser.coffee
and chance.coffee:

* **less code**. As conventions offered by CoffeeScript are used, there are 
fewer lines of code, not just by the omission of {, }, (, and ), but by language features
and idioms that reduce code lines while actually *helping* comprehension. This
is more important for some things than others, but for usages such as forming objects
or argument hashes with indentation, instead of with (), {}, and commas between items, the
simplification is clear. For other language features, there is high "bang for the buck."

* **@**, the "this" operator:

        @next

    > is the same as

        this.next

    > You quickly get the hang of using @. These little conveniences add up.

* simple **existential operator**:

        if next?
          next.exec file

    > The ? operator tacked onto a property name checks for null or undefined. It can
    > also be written with the if in postfix position, as:

        next.exec file if next?

    > Or can be be "embedded," so to speak, in method or property references, with the **?.**
    > variant, as: 

        next?.exec file

* **existential assignment operator**.

    > After the existential assignment operator was appreciated during coding of busser, 

        urlPrefix = urlPrefix if urlPrefix? else "/"
 
    > became

        urlPrefix ?= "/"

    > See also, the or= operator, which is useful for setting defaults.

* **string interpolation** and **heredocs**.

    > CoffeeScript has a simple method for string interpolation:

        util.puts "WARNING: #{path} referenced in #{file.path} but was not found."

    > where the property name or function call or expression is embedded within #{} tags.

    > NOTE: string interpolation works only in double-quoted or heredoc (triple-quoted, block style)
    > strings. Use single quotes for plain strings, or double quotes. 

    > For blocks of code in a string, and for other similar uses, the heredoc is very convenient:

        response.data = """
                        function() {
                          SC.filename = \"__FILE__\";
                          #{response.data}
                        })();
                        """

    > This is a boon for readability of such emitted code blocks. As you might guess from the way 
    > the heredoc is formatted for layout, indentation is honored, relative to the left margin of the
    > triple quotes. Also, string interpolation works in heredocs. As you might imagine, heredoc strings
    > are very useful for large html blocks, because of interpolation, and because of the visual
    > advantage afforded by indentation. It is inherently simpler, compared to the typical use of
    > an array of strings followed by an Array.join() call.

* **list comprehension**. The list comprehension is important. In the normal course 
of programming, you need loops over data all the time. In busser code, you will find simple 
list comprehensions, such as:

        resourceUrls = (file.url() for file in file.framework.resourceFiles)

    > In this case, we iterate, as we would normally write with a simple for loop, over
    > file.framework.resourceFiles, stuffing file.url() into a new array. But you don't have
    > to worry with declaring a new array, and you, of course, don't have to type {}s.

    > In the Server class, several list comprehensions are used. First, in the constructor instances
    > of Proxy need to be created from hashes read from the json config file:

        if @proxyHashes?
          proxyHash["server"] = this for proxyHash in @proxyHashes
          @proxies = (new Proxy(proxyHash) for proxyHash in @proxyHashes)

    > There are two list comprehensions within this if block. The first adds a server property
    > to each proxyHash input object. The second sets the array of instantiated Proxy objects.

    > Also within the Server class is a function called shouldProxy() that has a one-liner body:

        shouldProxy: ->
          ((proxy.host? and proxy.port?) for proxy in @proxies).some (bool) -> bool

    > You've probably seen the tagline sometimes used for CoffeeScript, "It's just javascript."
    > Well, it ends up as javascript, but more importantly, you have the advantage of combining
    > the intrinsic qualities added with CoffeeScript with the API and the "good parts" of
    > javascript. In this one-liner, this advantage is manifested in the use of the *some* function
    > in javascript for Array, combined with the list comprehension of CoffeeScript. There is a 
    > compound boolean check, (proxy.host? and proxy.port?), with which the list comprehension
    > computes an array of boolean values. The *some* function is passed the function (bool) -> bool,
    > which returns the value for each bool (It could be written (bool) -> return bool). The function
    > will evaluate to true if any one of the proxies has both host and port defined.

    > There are more advanced examples, such as this one from the build() method:

        children = (child for child in [@headFile(), @scriptFiles..., @tailFile()] when child?)

    > In this line, several nice features of CoffeeScript are combined in a list comprehension.
    > We are still iterating over an array, but we are constructing the array by concatenating
    > @headFile() with a splat (...) of all of the @scriptFiles with @tailFile(). The splat is
    > used for this kind of concatenation, but also for variable length argument lists to functions.
    > You also see use of the *when* statement, in this case for testing child with the 
    > existential operator to see if child is null or undefined. List comprehensions can get even
    > more complicated than this, but your ability to use them depends on your experience and 
    > style preference, and also where you see the limit for ease of comprehension, pardon the
    > pun. The same goes for list comprehensions in Ruby and Python, where there is also the need
    > for adopting a personal style and for being wise to break a list comprehension up with a 
    > traditional *for* or *while* statement, if it becomes too complicated or long.

* **function signature** syntax. Instead of writing a function with the familiar:

        scan: function() {
          ...
        }

    > you write

        scan: ->
          ...

    > That's it, nothing to it. But what is the following?:

        scan: =>
          ...

    > This is the "fat arrow" variant of ->. Appreciating it requires digging deeper into the realm 
    > of scope and closures. You would use the "fat arrow" variant when you want to
    > have the **this** reference set to the specific context of the calling line. Search the busser
    > code for => and for each line where you find it, think "this (and the @ reference) in the
    > function will have the value of this on the calling line". (Or, think, "the function is bound to
    > the context of the calling line"). To appreciate =>, it is best to see it in context.

    > If a function takes arguments, use the familiar parentheses to mark them off in a function
    > definition:

        exec: (file, request, callback) ->
          ...

    > If your code involves callbacks, you have to pay attention to the use of commas, as in:

        @next.exec file, request, (response) ->
          ...

    > Here, @next.exec is called with three arguments: file, request, and an anonymous callback that
    > takes a response argument. 

* available **postfix position** of an if, when it reads well, as in:

        response.write r.data, "utf8"  if r.data?

    > This one reads well as a succinct one-liner, compared to putting the if on one line,
    > followed by the response.write statement on the next line. Use of this option largely
    > depends on the complexity of associated code in the statement and in the if itself,
    > and also on the resultant length of the line.

* **optional parentheses**. You've already seen it, in the examples above. Consider the following clause:

        else
          file.content((err, data) ->
            throw err  if err  else callback()
          )

    > The parentheses in many cases may be omitted, after you get comfortable seeing when 
    > to use them, to some degree for style choice and preference for visual appeal.
    > Earlier versions of busser had use of parentheses as above, but later such code was
    > changed to:

        else
          file.content (err, data) ->
            throw err  if err  else callback()

    > After starting to omit parentheses in code blocks, you have to watch out for forgetting 
    > them when you want to call a function as a bare call at the end of a line, as with the
    > callback() call above, or on a single line, as with:

        exec() 

    > Don't leave off the () on exec here, otherwise you would be referring to the exec
    > function, instead of invoking it. You can also trip up by omitting parentheses within
    > statements, as in:

        callbackAfterBuild() if callbackAfterBuild?

    > If you leave off () here, you'll refer to the function, and will not make the call.

* **clean hash syntax**, for object creation and function argument passing. Compare:

        app_url = url.format({
          protocol: "http",
          hostname: @hostname,
          port: @port
        });

    > to the CoffeeScript equivalent:

        app_url = url.format
          protocol: "http"
          hostname: @hostname
          port: @port

    > Not only do you get to leave off () and {}, but you don't have to worry about commas. The
    > indenting -- the use of *significant whitespace* -- takes care of it. Here is another
    > example, with the CoffeeScript first:

        prompts = []
        prompts.push
          name: "configPath"
          message: "Config path?".magenta
        prompts.push
          name: "appTargets"
          validator: appTargetsValidator
          warning: 'Target names have letters, numbers, or dashes, and are comma-delimited. No quotes are needed.'
          message: "Target(s)?".magenta

    > Compare that with the javascript equivalent:

        prompts = []
        prompts.push({
          name: "configPath",
          message: "Config path?".magenta
        });
        prompts.push({
          name: "appTargets",
          validator: appTargetsValidator,
          warning: 'Target names have letters, numbers, or dashes, and are comma-delimited. No quotes are needed.',
          message: "Target(s)?".magenta
        });

    > No big deal? Well, again, little things like this add up to make a difference, not just for visual
    > simplicity, but for ease of typing and elimination of "nuisance" syntax. Of course, in some cases,
    > we want to use {} for creating hashes, as in short statements like:

        @stylesheetFiles.push(new MinifiedStylesheetFile({ path: path, framework: this }))

* **switch statement**. For example:

        switch fileType(path)
            when "stylesheet" then @framework.addStylesheetFile(path)
            when "script" then @framework.addScriptFile(path)
            when "test" then @framework.addTestFile(path)
            when "resource" then @framework.addResourceFile(path)

    > The uncluttered, "no squigglies" appearance helps comprehension, aided by the
    > the combination of *when* and *then*. Color-coding in a good editor helps too,
    > because your eyes naturally key on *when* and *then*.

* **fluidity / ease of comprehension**. Overall, consider the fluidity of typing and ease of 
reading typical conditional lines, such as those in the fileType function:

        fileType = (path) ->
          ext = extname(path)
          return "stylesheet" if /^\.(css|less)$/.test ext
          return "script"     if (ext is ".js") or (ext is ".handlebars") and not /tests\//.test(path)
          return "test"       if ext is ".js" and /tests\//.test(path)
          return "resource"   if ext in ResourceFile.resourceExtensions
          return "unknown"

    > The "script" line is readable, even if it involves a regular expression. Consider the
    > visual appeal of the usage here, over the syntactical alternative, where we would use ||, 
    > &&, ===, !==. We have ||, &&, ===, and !== in our brains as javascript programmers, but we 
    > also have *or*, *and*, *is*, *isnt*, *when*, "unless", etc. in our brains (with an
    > assumption that the typical non-native-to-English programmer has to learn English, a
    > defacto human language standard for most programming). The notion of a "normal word"
    > advantage is supported by the popularity of Ruby and Python. The notion can, of course,
    > be contested, but somehow, it seems, the issue would need to be about familiarity with 
    > English vs. other human languages. Think about the keystrokes required by typing these as 
    > fast as you can: *or*, *and*, *is*, *isnt*, then type their javascript equivalents,
    > concentrating not just on speed, but on the mechanics of shift key usage in javascript.

* **implied return** in functions. Translation: you don't have to use the return statement if
you don't want to. Contrast:

        file: (path) ->
          file = null
          for app in @apps
            file = app.files[path]
            return file if file?
          return file

    > with this, emphasis that the last line of a function matters -- whatever that evaluates
    > to is the return:

        file: (path) ->
          file = null
          for app in @apps
            file = app.files[path]
            return file if file?
          file

    > The last line of a function can be an assignment, or some other statement for
    > which the function doesn't return a value. Or the last line can be another
    > function call, as we see in the build method of the Framework class:

        build: ->
          ...
          code that includes definition of the createBasicFiles function
          ...

          createBasicFiles callbackAfterBuild

    > Here we are calling the createBasicFiles function, passing callbackAfterBuild.

    > Be careful when you have a function that does something on the last line, but you
    > really need for the function to return, say, true or false. In that case, don't 
    > forget to add true or false on the last line, depending on what you are doing.

* **classes** and especially the great choice for the name of the **constructor** function:

        class File
          constructor: (options={}) ->
            @path = null
            @framework = null
            @children = null
            @taskHandlerSet = null
            @isHtml = false
            @isVirtual = false
            @symlink = null
            @[key] = options[key] for own key of options

    > This is the routine adopted in busser for class constructor code: pass in an options
    > object, set defaults for properties for which defaults are needed, then "step on"
    > these properties, and add new ones, with the last line. The @ signs on all the properties
    > designate them as instance properties. Now to that last line. The @[key] target is a
    > nice way of referring to the property on the object (File) that goes by the name key.
    > In the list comprehension part, *options[key] for own key of options*, grabs the value of
    > the property in options going by the name key. We do not to use: for key *in* options here,
    > because that would do the normal reference to the values in the options associative array.
    > We want the keys here, so we use: for *own key of* options. This is useful, and a
    > big win for CoffeeScript, if you come from, say, Python, where dictionaries, and their
    > constant use, form the bread and butter of much programming.

    > A dedicated constructor function that is *called* constructor is simple and good.

    > The options={} assignment in the constructor signature assures a default value. You will
    > also want to learn, for another typical way of constructing a class, the shorthand style:

        class FileDependenciesComputer
          constructor: (@file, @framework) ->

    > which is equivalent to:

        class FileDependenciesComputer
          constructor: (file, framework) ->
            @file = file
            @framework = framework

    > Compare to the options idiom above, if we can call it that. There is flexibility for
    > using a style that best fits the situation. You can also use the splat (...) operator
    > tacked onto a function argument, when you have a variable (unknown) number of arguments.

    > Finally, on classes, just *having* classes is an important advantage (eschewing debate
    > over specific meanings of the term "class"). There continue to be astute discussions
    > about human cognition, about identifying "optimal" ways that we write programs, but in the 
    > history of programming, the idea of the class as a prototypical definition of an object 
    > and all that it entails can be defended as fundamental. We so often work on problems 
    > involving objects and their interactions, real or abstract.

* **heregexes**, which are like heredocs, but for regular expressions.

    > Compare an original all-jammed-together regex:

        actionsValidator = /^([\s*\<build\>*\s*]*[\s*\<save\>*\s*]*[\s*\<run\>*\s*]*)+(,[\s*\<build\>*\s*]*[\s*\<save\>*\s*]*[\s*\<run\>*\s*]*)*$/

    > that was changed to:

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

    > Breaking it up is one thing; interspersing comments is even better.

There will be more items like these to share, as programming for busser.coffee and chance.coffee continues...
