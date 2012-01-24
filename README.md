B U S S E R
===========

Prominent Note at the Top
=========================

This program does not well work yet...

UPDATE 2012-01-24a: busboy, for handling the graphics side of things and 
other "helper" tasks, has been moved from a source file within busser to
a separate repository, for a program, graphics-heavy, that will be made
as a separately intallable npm module. So, a developer will be able to
install busser for general building and serving tasks, while electing to
install busboy also, when theme-building and graphics needs arise.

UPDATE 2012-01-23: Jasko reported in irc a problem trying an older SC app
against master, and it turns out to be the same thing plaguing busser. If
lines 86-89 of sproutcore/frameworks/runtime/system/index_set.js are
commented out, the hello world app now comes up. Woohoo!

Description
===========

**Busser** is a node.js development system for SproutCore written in Coffeescript.

This project is based on garçon, which was written by Martin Ottenwaelter 
(martoche) and updated substantially by Maurits Lamers (mauritslamers). 

Please see these github repos for the basis of work here:
  
  https://github.com/martoche/garçon

  https://github.com/mauritslamers/garçon

During development of this Coffeescript version, discussion with Maurits
Lamers for background and for explanation has been very important. The
martoche version of garçon was used as a starting point for the current
development, followed by comparison to the later mauritslamers versions.

General similarities to garçon remain in the first version of Busser, but 
reorganization and renaming of variables has happened in course, to adapt 
to the Coffeescript ways of doing things, and to add understanding where
needed. Several node.js libraries have been added to the mix, and to 
attempt to find and follow best practices for their use.

Roadmap and ToDo List
=====================

In the short-term, certainly within the timeframe for 0.1.x incremental 
releases, focus will be on getting Busser to work with SproutCore master, 
the development target, for running and building the "test controls"
SproutCore app in the SproutCore 1.7 release, using an Ace theme. 

A longer-term goal is to match the feature set of the Abbot/Chance build 
tools in Ruby for the next release of SproutCore (1.8?), if not to be 
incorporated as an official build tools option, to begin a life as a 
separately maintained project as an unofficial build tools option. The 
progression of development of official SproutCore build tools may be 
followed at https://github.com/sproutcore/sproutcore/issues/639.

Busser will be developed with a fresh look at new tools available, such 
as browserify, stylus, stitch, and the like, to see where use of these 
tools can replace code or enhance the program.

Async programming style in Busser will be reviewed by comparison to
examples found on the web and to the build tools called ember-runner, 
developed by Juan Pablo Goldfinger (Juan77). In particular, the use of 
the async module in ember-runner will be reviewed. ember-runner may be
found at https://github.com/envone/ember-runner.

Also, the design and operation of ember-runner will be reviewed. One aspect
to be considered is the way the system of handlers works, compared to the
modifications done in Busser.

Another build tools treatment to be considered is that in Blossom, released 
by Erich Ocean (erichocean), https://github.com/fohr/blossom.  Blossom's 
build tools take a fresh approach to the way SproutCore frameworks are 
incorporated, attendant with a refactoring of framework configuration 
specific to Blossom. An abstraction like this might be a good fit for 
implementation in Coffeescript, but must be compared to the merits of the 
fine-grained simple json configuration files, via nconf, now in Busser.

The design and operation of Abbot, the very capable Ruby-based development
tools for SproutCore will be studied and evaluated for bringing Busser
features up to par, including code in Abbot and in the theme-building
helper program called Chance. Graphics production and handling may be
enhanced, by using node.js modules such as node-canvas, to add screen
capturing for SproutCore testing and software release tasks.

The latest mauritslamers version of garçon includes a start for handling
of bundles and also includes use of special components from SproutCore 
itself. The development of Busser will include coverage of bundle support,
and may also incorporate these SproutCore components, especially if they
are packaged in dedicated npm modules, per discussion with mauritslamers.

The node.js modules prompt and color were successfully used in linelizer,
so it will be easy to add their use to Busser. prompt will be useful for
making a version for new users that prompts them for their project file
name, app name or version, build action, etc. And the colors module can
be used for custom reporting from the server and in analysis printouts.

Format the docco presentation by customizing docco css for the project.

Make Busser into an installable npm module.

Review the url, urlFor, and similar functions in Busser, which were not
substantially changed from garçon, to see if all of that can be simpler.

Add tests, using vows perhaps, but take a fresh look at mocha and any other
testing frameworks available. Some of the node.js modules can be used in
concert to make fixtures and testing harnesses.

Support for Coffeescript programming of SproutCore will be explored and
developed as a primary focus after the dust settles on other roadmap items.
Busser was written in Coffeescript as an exploration to learn the language
and to test its viability. This experience has been so favorable that an 
expansion for support of Coffeescript programming for SproutCore development
is a goal.

Another original goal of the project has been reevaluated after saturation in
Coffeescript programming: to offer a Python version of the build tools or to 
wrap/incorporate the build tools in an effective Python development environment. 
Instead of writing a version in Python, using a common API, the similarity of
Coffeescript to Python is now deemed enough to serve as a draw to Python
programmers who wish to understand or modify the build tools. This goal exists 
primarily for addressing a perceived missed opportunity to empower and draw in
new users of SproutCore from the Python community, which many of us already 
know from experience or from use of Python on the backend. Although the Ruby
community already may look to Abbot, which is written in Ruby, the style of
programming in Busser may be attractive, as for Python developers. All of
that is said with the caveat that the underlying async capabilities of node.js
are celebrated in Busser, so effort to learn or appreciate it may be required.

Eventual Tool Installation [TODO] Not yet implemented
-----------------------------------------------------

Install with:

    npm install busser

This would install the dependencies and busser, but that doesn't work yet.

Development Installation
------------------------

git clone http://www.github.com/geojeff/busser

cd busser

npm install coffee-script (use -g for global -- you know you want to)

npm install nconf

npm install less

npm install uglify-js

These npm install steps will populate a node_modules directory in the busser
directory. If you installed coffee-script globally, with -g, you can run
coffee to get a REPL for learning, if you want. The coffee command is used
to compile src/busser.coffee to bin/coffee.js, with the command:

    coffee --output bin ./src/busser.coffee

If you installed coffeescript locally, you will need to use the path:

    ./node_modules/coffee-script/bin/coffee

After a successful step to get a bin/busser.js, you are ready to run busser,
after adding a frameworks directory inside busser, then cloning SproutCore
master in there (https://github.com/sproutcore/sproutcore/).

Preparing Config File
---------------------

**Busser** uses the node.js nconf module for configurations. See the default
conf/busser.json file for usage.

See https://github.com/flatiron/nconf for nconf details.

Running
-------

The simple invocation is:

    node bin/busser.js --appTargets=myapp-dev --action=buildrun

where appTargets lists the SproutCore apps to be built, and action specifies
one of: build, buildrun, buildsave, and buildsaverun. Busser and app-specific
configuration is assumed to be in conf/busser.json, read by nconf.

Visit localhost:8000/OnePointSeven to show the app, which, as of 2012-01-23,
will come up with the first window and pane skewed far left, unusable (Ace
problems, probably...).

Contributors
============

Jeff Pittman (geojeff)

License
=======

MIT

Development
===========

Tests [TODO] Not yet implemented
--------------------------------

Tests are made in **Busser** with the Vows testing framework. If you wish to 
install Vows for running tests, you may do so with:

	npm install vows

Then, you should be able to run all tests with:

    vows test/*

or, to see a more complete report, run:

    vows test/* --spec

and individual tests, for example, with:

    node test/config.js

Notes
-----

For learning coffeescript, the [coffeescript.org](http://www.coffeescript.org) website is succinct and very
good. 

Other websites:

[Smooth Coffeescript](http://autotelicum.github.com/Smooth-CoffeeScript/)

[Coffeescript Cookbook](http://coffeescriptcookbook.com/)

[Coffeescript One-liners](http://ricardo.cc/2011/06/02/10-CoffeeScript-One-Liners-to-Impress-Your-Friends.html)

When first starting, use [js2coffee.org](http://js2coffee.org/) to experiment. It is still handy after you
have learned coffeescript pretty well.

A very nice video for background and "top ten" favorites is by Sam Stephenson:

    http://vimeo.com/35258313

Color-coding for coffeescript code is really nice to use.  There are many [editor plugins](https://github.com/jashkenas/coffee-script/wiki/Text-editor-plugins).


