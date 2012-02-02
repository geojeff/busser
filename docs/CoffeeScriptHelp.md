CoffeeScript Help
-----------------

Here are features that may make CoffeeScript *worth it* for the learning and adjustment
required for its use, whether in the context of busser/busboy or in general:

* **less code**. After all the conventions offered by CoffeeScript are used, there are 
fewer lines of code, not just by the omission of {} and () but by the language features
and idioms that reduce code lines, while actually *helping* comprehension usually. This
is more important for some things than others, but for usages such as forming objects
or argument hashes with indentation, instead of with (), {}, and commas between items,
the simplification is clear. And for other language features, such as the list
comprehension, the "bang for the buck" is great, as shown in a section below.

* **@**, the "this" operator:

        @next

    > is the same as

        this.next

    > You really get the hang of this after a while, but it does take getting used to.
    > These little conveniences add up.

* simple **existential operator**:

        if next?
          next.exec file

    > The ? operator tacked on to the end of a property checks for null or undefined. It can
    > also be written with the if in postfix position, as in:

        next.exec file if next?

    > Or can be be "embedded," so to speak, in method or property references, with the **?.**
    > variant, as in: 

        next?.exec file

    > In learning CoffeeScript, the explicit use of if next? is more traditional, but you get
    > the hang of taking advantage of **?.**. Still, you often need to use if next? in the
    > traditional fashion, because you need an accompanying else clause, which is indeed the 
    > case in the handlers code, from which this example comes.

* **existential assignment operator**.

    > After the existential assignment operator was discovered during coding of busser, 

        urlPrefix = urlPrefix if urlPrefix? else "/"
 
    > became

        urlPrefix ?= "/"

    > See also, the or= operator, which is useful for setting defaults.

* **string interpolation** and **heredocs**.

    > CoffeeScript has a simple, but powerful method for string interpolation:

        util.puts "WARNING: #{path} referenced in #{file.path} but was not found."

    > All you have to do is embed the property name or function call or expression within #{} tags.
    > NOTE: string interpolation works only in double-quoted or heredoc (triple-quoted, block style)
    > strings. Use single quotes for plain strings, or double quotes. For blocks of code in a string,
    > or for other similar uses, the heredoc is very convenient:

        response.data = """
                        function() {
                          SC.filename = \"__FILE__\";
                          #{response.data}
                        })();
                        """

    > This is a boon for readability of such emitted code blocks. As you might guess from the way 
    > the heredoc is formatted, indentation is honored, relative to the left margin of the triple
    > quotes. Also, string interpolation works in heredocs. As you might imagine, heredoc strings
    > are very handy for large html blocks, because you not only have interpolation available, but
    > the visual ease afforded by indentation and no requirement for per line quoting or commas.

* **list comprehension**. The list comprehension is important -- in the normal course 
of programming, you need loops over data all the time. In busser code, you will find simple 
list comprehensions, such as:

        resourceUrls = (file.url() for file in file.framework.resourceFiles)

    > In this case, we iterate, as we would normally write with a simple for loop, over
    > file.framework.resourceFiles, stuffing file.url() into a new array. But you don't have
    > to worry with declaring a new array, and you, of course, don't have to type {}s.

    > In the Server class, several list comprehensions are used. First, in the constructor instances
    > of Proxy need to be created from hashes read from the json config file:

        if @proxyHashes?
          (proxyHash["server"] = this for proxyHash in @proxyHashes)
          @proxies = (new Proxy(proxyHash) for proxyHash in @proxyHashes)

    > There are two list comprehensions within this if block. The first adds a server property
    > to each proxyHash input object. The second sets the array of instantiated Proxy objects.

    > Also within the Server class is a function called shouldProxy() that has a one-liner body:

        shouldProxy: ->
          ((proxy.host? and proxy.port?) for proxy in proxies).some (bool) -> bool

    > You've probably seen the tagline sometimes used for CoffeeScript, "It's just javascript."
    > Well, it ends up as javascript, but more importantly, you have the advantage of combining
    > the intrinsic qualities added with CoffeeScript, with the API and the "good parts" of
    > javascript. Here this is manifested in the use of the some function in javascript for Array,
    > combined with the list comprehension. In this one, there is a compound boolean check for both
    > a host and port property existing on each proxy. The list comprehension computes an array
    > of boolean values from this. The some function is passed the function (bool) -> bool, which
    > returns the value for each bool (It could be written (bool) -> return bool). The function
    > will evaluate to true if any one of the proxies has both host and port defined.

    > There are more advanced examples, such as:

        children = (child for child in [@headFile(), @scriptFiles..., @tailFile()] when child?)

    > In this line, several nice features of CoffeeScript are combined in a list comprehension.
    > We are still iterating over an array, but we are constructing the array by using the
    > splat (...) operator to concatenate @headFile() with all of the @scriptFiles with
    > @tailFile(). Recall that the @ signs mean *this*. You also see use of the handy *when*, in 
    > this case for testing child with the existential operator to see if child is null or 
    > undefined. List comprehensions can get even more complicated than this, but your ability
    > to use them depends on your experience and style preference, and also where you see the
    > limit for ease of comprehension, pardon the pun. The same goes for list comprehensions
    > in Ruby and Python, where there is also the need for adopting a personal style and for 
    > being wise about when to break it up with a traditional *for* or *while* statement.

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
    > of scope and closures and such. You would use the "fat arrow" variant when you want to
    > have the **this** reference set to the specific context of the calling line. Search the busser
    > code for => and for each line where you find it, think "this (and the handy @ reference) in the
    > function will have the value of this on the calling line". (Or, think, "the function is bound to
    > the context of the calling line").

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

    > This one reads well as a succinct one-liner, rather than putting the if on one line
    > line, followed by the response.write statement on a line. Use of this option largely
    > depends on the complexity of associated code, in the statement and in the if itself,
    > and also on the resultant length of the line.

* **optional parentheses**. You've already seen it, in the examples above. Consider the following clause:

        ...
        else
          file.content((err, data) ->
            throw err  if err  else callback()
          )

    > The parentheses in many cases may be omitted, after you get comfortable seeing when 
    > to use them, to some degree for style choice and preference for visual appeal.
    > Earlier versions of busser had use of parentheses as above, but later such code was
    > changed to:

        ...
        else
          file.content (err, data) ->
            throw err  if err  else callback()

    > In many situations, after starting to omit parentheses in code blocks, you have
    > to watch out for forgetting them when you want to call a function as a bare call at the
    > end of a line, as with the callback() call above, or on a single line, as with:

        exec() 

    > Don't leave off the () on exec here, otherwise you would be referring to the exec
    > function, instead of invoking it, with exec(). You can also trip up by omitting
    > parentheses on lines like:

        callbackAfterBuild() if callbackAfterBuild?

    > Again, if you leave off () here, you'll refer to the function, and will not make the call.

* **clean hash syntax**, for object creation and function argument passing. Compare:

        app_url = url.format({
          protocol: "http",
          hostname: @hostname,
          port: @port
        });

    > to

        app_url = url.format
          protocol: "http"
          hostname: @hostname
          port: @port

    > Not only do you get to leave off () and {}, but you don't have to worry about commas. The
    > indenting -- the use of "significant whitespace" -- takes care of it. Here is another
    > example:

        prompts = []
        prompts.push
          name: "configPath"
          message: "Config path?".magenta
        prompts.push
          name: "appTargets"
          validator: appTargetsValidator
          warning: 'Target names have letters, numbers, or dashes, and are comma-delimited. No quotes are needed.'
          message: "Target(s)?".magenta

    > Compare that with:

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
    > we want to use {}, instead of indentation, for creating hashes, as in short statements like:

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

* **fluidity / ease of comprehension**. For example, consider the fluidity of typing and ease of 
reading typical conditional lines, such as those in the fileType function:

        fileType = (path) ->
          ext = extname(path)
          return "stylesheet" if /^\.(css|less)$/.test ext
          return "script"     if (ext is ".js") or (ext is ".handlebars") and not /tests\//.test(path)
          return "test"       if ext is ".js" and /tests\//.test(path)
          return "resource"   if ext in ResourceFile.resourceExtensions
          return "unknown"

    > The "script" line stands out, even if it involves a regular expression. Consider the
    > visual appeal of the usage here, over the syntactical alternative, where we would use ||, 
    > &&, ===, !==. We have ||, &&, ===, and !== in our brains as javascript programmers, but we 
    > also have *or*, *and*, *is*, *isnt*, *when*, "unless", etc. in our brains (with an
    > assumption that the typical non-native-to-English programmer has to learn English, a
    > defacto human language standard for most programming). The notion of a "normal word"
    > advantage is supported by the popularity of Ruby and Python. The notion can, of course,
    > be contested, but somehow, it seems, the issue would need to be about familiarity with 
    > English vs. other human languages. Think about the keystrokes required by testing this: 
    > type or, and, is, isnt, when, unless, then type their javascript equivalents.

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

    > Of course, the last line of a function can be an assignment, or some other statement for
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
            @handlerSet = null
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

    > And, don't forget, just by having a dedicated constructor function that is called
    > *constructor*, we have an improved way of setting up classes over even Ruby and Python.

    > One more bit, the options={} assignment in the constructor signature assures that 
    > options coming in is defined. You will also want to learn, for another typical way of
    > constructing a class, the shorthand style:

        class FileDependenciesComputer
          constructor: (@file, @framework) ->

    > instead of:

        class FileDependenciesComputer
          constructor: (file, framework) ->
            @file = file
            @framework = framework

    > Compare to the options idiom above, if we can call it that. There is flexibility for
    > using a style that best fits the situation. 

    > Finally, on classes, just having classes is an important advantage for some (avoiding
    > debate over specific meanings of the term "class"). There continue to be astute debates
    > about human cognition, about identifying "optimal" ways that we write programs, but in the 
    > history of programming, the idea of the class as a prototypical definition of an object 
    > and all that it entails has been important. Important in the fundamental sense that we
    > usually work on problems involving real objects and their interactions. CoffeeScript adds
    > explicit coverage of this important concept.

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

    > Being able to break it up is one thing; being able to add comments within is even better.

* And there will be more items like these to share, as programming for busser and busboy continues...
