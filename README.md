Prominent Note at the Top
=========================

This program does not work yet. If you get it running, you'll get a blank
web page with errors. 2012-01-22.

Description
===========

**Waiter** is a node.js development system for SproutCore written in Coffeescript.

This project is based on garçon, which was written by Martin Ottenwaelter 
(martoche) and updated substantially by Maurits Lamers (mauritslamers). 

Please see these github repos for the basis of work here:
  
  https://github.com/martoche/garçon

  https://github.com/mauritslamers/garçon

During development of this Coffeescript version, discussion with Maurits
Lamers for background and for explanation has been very important. The
martoche version of garçon was used as a starting point for the current
development, followed by comparison to the later mauritslamers versions.

General similarities to garçon remain in the first version of Waiter, but 
reorganization and renaming of variables has happened in course, to adapt 
to the Coffeescript ways of doing things, and to add understanding where
needed. Several node.js libraries have been added to the mix, and to 
attempt to find and follow best practices for their use.

Roadmap and ToDo List
=====================

In the short-term, certainly within the timeframe for 0.1.x incremental 
releases, focus will be on getting Waiter to work with SproutCore master, 
the development target, for running and building the "test controls"
SproutCore app in the SproutCore 1.7 release, using an Ace theme. 

A longer-term goal is to match the feature set of the Abbot/Chance build 
tools in Ruby for the next release of SproutCore (1.8?), if not to be 
incorporated as an official build tools option, to begin a life as a 
separately maintained project as an unofficial build tools option. The 
progression of development of official SproutCore build tools may be 
followed at https://github.com/sproutcore/sproutcore/issues/639.

Waiter will be developed with a fresh look at new tools available, such 
as browserify, stylus, stitch, and the like, to see where use of these 
tools can replace code or enhance the program.

Async programming style in Waiter will be reviewed by comparison to
examples found on the web and to the build tools called ember-runner, 
developed by Juan Pablo Goldfinger (Juan77). In particular, the use of 
the async module in ember-runner will be reviewed. ember-runner may be
found at https://github.com/envone/ember-runner.

Also, the design and operation of ember-runner will be reviewed. One aspect
to be considered is the way the system of handlers works, compared to the
modifications done in Waiter.

Another build tools treatment to be considered is that in Blossom, released 
by Erich Ocean (erichocean), https://github.com/fohr/blossom.  Blossom's 
build tools take a fresh approach to the way SproutCore frameworks are 
incorporated, attendant with a refactoring of framework configuration 
specific to Blossom. An abstraction like this might be a good fit for 
implementation in Coffeescript, but must be compared to the merits of the 
fine-grained simple json configuration files, via nconf, now in Waiter.

The design and operation of Abbot, the very capable Ruby-based development
tools for SproutCore will be studied and evaluated for bringing Waiter
features up to par, including code in Abbot and in the theme-building
helper program called Chance. Graphics production and handling may be
enhanced, by using node.js modules such as node-canvas, to add screen
capturing capturing for SproutCore testing and software release tasks.

The latest mauritslamers version of garçon includes a start for handling
of bundles and also includes use of special components from SproutCore 
itself. The development of Waiter will include coverage of bundle support,
and may also incorporate these SproutCore components, especially if they
are packaged in dedicated npm modules, per discussion with mauritslamers.

The node.js modules prompt and color were successfully used in linelizer,
so it will be easy to add their use to Waiter. prompt will be useful for
making a version for new users that prompts them for their project file
name, app name or version, build action, etc. And the colors module can
be used for custom reporting from the server and in analysis printouts.

Format the docco presentation by customizing docco css for the project.

Make Waiter into an installable npm module.

Add tests, using vows perhaps. Some of the new modules can be used in
concert to make fixtures and testing harnesses.

Support for Coffeescript programming of SproutCore will be explored and
developed as a primary focus after the dust settles on other roadmap items.
Waiter was written in Coffeescript as an exploration to learn the language
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
programming in Waiter may be attractive, as for Python developers. All of
that said with the caveat that the underlying async capabilities of node.js
are celebrated in Waiter, so effort to learn or appreciate it may be required.

Eventual Installation
---------------------

Install with:

    npm install waiter

This would install the dependencies and waiter, but that doesn't work yet.

Development Installation
------------------------

git clone http://www.github.com/geojeff/waiter

cd waiter

npm install coffee-script (use -g for global -- you know you want to)

npm install nconf

npm install less

npm install uglify-js

These npm install steps will populate a node_modules directory in the waiter
directory. If you installed coffee-script globally, with -g, you can run
coffee to get a REPL for learning, if you want. The coffee command is used
to compile src/waiter.coffee to bin/coffee.js, with the command:

    coffee --output bin ./src/waiter.coffee

With a successful step to get a bin/coffee.js, you are ready to run waiter.

Preparing Config File
---------------------

**Waiter** uses the node.js nconf module for configurations. See the default
conf/waiter.json file for usage.

See https://github.com/flatiron/nconf for nconf details.

Running
-------

The simple invocation is:

    node bin/waiter.js --appTargets=myapp-dev --action=buildrun

where appTargets lists the SproutCore apps to be built, and action specifies
one of: build, buildrun, buildsave, and buildsaverun. Waiter and app-specific
configuration is assumed to be in conf/waiter.json, read by nconf.

Visit localhost:8000/OnePointSeven to get the broken app.

Contributors
============

Jeff Pittman (geojeff)

License
=======

MIT

Tests
=====
Tests are made in **Waiter** with the Vows testing framework. If you wish to 
install Vows for running tests, you may do so with:

	npm install vows

Then, you should be able to run all tests with:

    vows test/*

or, to see a more complete report, run:

    vows test/* --spec

and individual tests, for example, with:

    node test/config.js

