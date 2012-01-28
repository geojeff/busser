B U S S E R
===========

Prominent Note at the Top
=========================

This program does not well work yet...

UPDATE 2012-01-26b: Added use of prompt and color node.js modules.

UPDATE 2012-01-26a: Thanks to Tyler Keating for fixing the index_set.js
bug in SproutCore master, discussed below, in 2012-01-23 entry.

UPDATE 2012-01-24b: busboy, for handling the graphics side of things and 
other "helper" tasks, has been moved from a source file within busser to
a separate repository, for a program, graphics-heavy, that will be made
as a separately intallable npm module. So, a developer will be able to
install busser for general building and serving tasks, while electing to
install busboy also, when theme-building and graphics needs arise.

UPDATE 2012-01-24a: Had to rename project from waiter to busser/busboy,
because of a name conflict in npm registry.

UPDATE 2012-01-23: Jasko reported in irc a problem trying an older SC app
against master, and it turns out to be the same thing plaguing busser. If
lines 86-89 of sproutcore/frameworks/runtime/system/index_set.js are
commented out, the hello world app now comes up. Woohoo!

Description
===========

**Busser** is a node.js development system for SproutCore written in CoffeeScript.

This project is based on garçon, which was written by Martin Ottenwaelter 
(martoche) and updated substantially by Maurits Lamers (mauritslamers). 

Please see these github repos for the basis of work here:
  
  https://github.com/martoche/garçon

  https://github.com/mauritslamers/garçon

During development of this CoffeeScript version, discussion with Maurits
Lamers for background and for explanation has been very important. The
martoche version of garçon was used as a starting point for the current
development, followed by comparison to the later mauritslamers versions.

General similarities to garçon remain in the first version of Busser, but 
reorganization and renaming of variables has happened in course, to adapt 
to the CoffeeScript ways of doing things, and to add understanding where
needed. Several node.js libraries have been added to the mix, and to 
attempt to find and follow best practices for their use.

Roadmap and ToDo List
=====================

In the short-term, certainly within the timeframe for 0.1.x incremental 
releases, focus will be on getting Busser to work with SproutCore master, 
the development target, for running and building the "test controls"
SproutCore app in the SproutCore 1.8 release, using an Ace theme. 

A longer-term goal is to match the feature set of the Abbot/Chance build 
tools in Ruby for the next release of SproutCore (1.9?), if not to be 
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
implementation in CoffeeScript, but must be compared to the merits of the 
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

[ **DONE 2012-01-26** The node.js modules prompt and color were successfully 
used in linelizer, so it will be easy to add their use to Busser. prompt 
will be useful for making a version for new users that prompts them for 
their project file name, app name or version, build action, etc. And the 
colors module can be used for custom reporting from the server and in 
analysis printouts.]

[ **DONE 2012-01-28** Format the docco presentation by customizing docco css for the project.]

Make Busser into an installable npm module.

Review the url, urlFor, and similar functions in Busser, which were not
substantially changed from garçon, to see if all of that can be simpler.

Add tests, using vows perhaps, but take a fresh look at mocha and any other
testing frameworks available. Some of the node.js modules already employed
in busser/busboy can be used in concert to make fixtures and testing harnesses.

Support for CoffeeScript programming of SproutCore will be explored and
developed as a primary focus after the dust settles on other roadmap items.
Busser was written in CoffeeScript as an exploration to learn the language
and to test its viability. This experience has been so favorable that an 
expansion for support of CoffeeScript programming for SproutCore development
is a goal.

Another original goal of the project has been reevaluated after saturation in
CoffeeScript programming: to offer a Python version of the build tools or to 
wrap/incorporate the build tools in an effective Python development environment. 
Instead of writing a version in Python, using a common API, the similarity of
CoffeeScript to Python is now deemed enough to serve as a draw to Python
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
Significant note: CoffeeScript, nor the testing framework, will not be required
in a normal user installation. This will simply be a node.js tool installable
via npm.

Development Installation
------------------------

git clone http://www.github.com/geojeff/busser

cd busser

npm install coffee-script (use -g for global -- you know you want to)

npm install nconf

npm install prompt

npm install colors

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
master in there. Clone from https://github.com/sproutcore/sproutcore/.

Preparing Config File
---------------------

**Busser** uses the node.js nconf module for configurations. See the default
conf/busser.json file for usage. busser.json contains the following default
sections, which are rather long, offering fine-grained control, per framework:

* default-app-dev

* default-app-prod

* default-sc-frameworks-dev

* default-sc-frameworks-prod

Below these default specifications in the file, there is an apps section, where
a developer adds their own app configurations. In the sample config file, there
are app sections for 'HelloWorld-dev' and 'HelloWorld-prod' and the same
for the test_controls app. Within each app, there are properties for basic
metadata items and for build control settings. There is an sc-frameworks section,
where addition SproutCore frameworks can be added, in addition to the core
frameworks required. This will change, especially after flexibility for bundle
support is added, but it is a start. Likewise, there is a custom-frameworks
section for each app, for specifying configurations for external frameworks
used from github or from in-house customizations and development.

One idea to be pursued is the customization per application "instance," e.g.
HelloWorld-dev vs. HelloWorld-prod, which can be maintained for different
development experiments, the "master" dev and prod versions, and so on. This
flexibility can be matched to horsepower within busser to perform large
build jobs, if needed. 

See https://github.com/flatiron/nconf for nconf details.

Running
-------

busser and busboy use the node.js prompt module, along with the colors module,
to prompt for and validate user input. After validation and parsing, user input
is fed to nconf. So, busser is invoked with no arguments as:

    node bin/busser.js

which will prompt for the following input items:

* configPath -- Use the default 'conf/busser.json' until you have a need to customize.

* appTargets -- Use the test app 'HelloWorld-dev' for which info is in busser.json.
This is designed to take multiple targets in comma-delimited format, but for now
one app at a time works.

* actions -- Use a combination of build, save, and run, comma-delimited, blank-delimited,
or even all jambed up, as buildsaverun.

Power users will want command line-only functionality, something like:

    node bin/busser.js --appTargets=myapp-dev --actions=build,run

Because this is command line input, when providing multiples for either argument, use
comma-delimited style with no blanks, certainly for appTargets, with no blanks, or use
quotes, e.g. --appTargets="myapp-dev, myapp-prod" or --actions=build,save,run. You can
also use compound words for actions, e.g. --actions=buildsaverun. For actions, the
order of input doesn't matter -- build will always be first, then save, if required,
then run.

You should see a colorized report to the console after executing.

For build, save, run, you will see the same output, finishing with a message that 
the server is now running on localhost, port 8000. In that event, visit
localhost:8000/HelloWorld to show the app, which, as of 2012-01-23, will
show the first window and pane skewed far left, unusable (Ace problems, probably...).

It is not necessary to save -- during development, you will commonly use build, run.

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

[The Little Book of CoffeeScript](http://arcturo.github.com/library/coffeescript/index.html)

[Smooth CoffeeScript](http://autotelicum.github.com/Smooth-CoffeeScript/) (This book is interactive).

[CoffeeScript Cookbook](http://coffeescriptcookbook.com/)

[CoffeeScript One-liners](http://ricardo.cc/2011/06/02/10-CoffeeScript-One-Liners-to-Impress-Your-Friends.html)

When first starting, use [js2coffee.org](http://js2coffee.org/) to experiment. It is still handy after you
have learned coffeescript pretty well.

A very nice video for background and "top ten" favorites is by Sam Stephenson:

[Better JS with CoffeeScript](http://vimeo.com/35258313)

and another by Trevor Burnham:

(Introduction to CoffeeScript)[http://screencasts.org/episodes/introduction-to-coffeescript], which is related
to his book on CoffeeScript: [*CoffeeScript: Accelerated JavaScript Development*](http://pragprog.com/book/tbcoffee/coffeescript).

Color-coding for coffeescript code is really nice to use.  There are many [editor plugins](https://github.com/jashkenas/coffee-script/wiki/Text-editor-plugins).

See also the file CoffeeScriptHelp.md in the docs directory for help in learning
CoffeeScript in the context of busser.

