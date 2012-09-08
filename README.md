BhGesturePad for Gideros 
========================

This software is a multi-stroke gesture recognition library for Gideros Mobile SDK.
It is an extension of the Lua implementation of Protractor unistroke gesture 
recognition by [Arturs Sosins](http://appcodingeasy.com). His original <em>Gesture.lua</em> has been
included untouched but the stroke capture and drawing component of this is not used and replaced by my <em>BhWritingSurface</em> class. The version here also extends the algorithm to include multistroke gestures with my interpretation of [n-Protractor](http://depts.washington.edu/aimgroup/proj/dollar/ndollar-protractor.pdf).

You can read more about this module in [my blog entry](http://bowerhaus.eu/blog/files/multistroke_gestures.html).

Folder Structure
----------------

This module is part of the general Bowerhaus library for Gideros mobile. There are a number of cooperating modules in this library, each with it's own Git repository. In order that the example project files will run correctly "out of the box" you should create an appropriate directory structure and clone/copy the files within it.

###/MyDocs
Place your own projects in folder below here

###/MyDocs/Library
Folder for library modules

###/MyDocs/Library/Bowerhaus
Folder containing sub-folders for all Bowerhaus libraries

###/MyDocs/Library/Bowerhaus/BhGesturePad
Folder for THIS FILE

