
## Introduction

Tool wrapping is quite challenging.
Most tools will require the use of a trick or established pattern to solve problems related to running programs on galaxy.
We need a place to store tricky situations alongside the patterns which solve those situations.

This file is intended to be the reference which stores tool xml patterns and workarounds for tricky situations.

<br>

## Contents
* [Variables](#variables)
* [Filetypes](#filetypes)
* [Imports](#imports)
* [Static files](#static-files)

<br>

## Variables

### Setting and accessing variables

**cheetah and environment variables**

cheetah

```
#set myvar = 1
echo $myvar  
```


environment
```
export MYVAR=1 (note there is no whitespace around '=')
echo \$MYVAR   (note the dollar is escaped)
```

<br>

**embedded commands**

cheetah

```
#set date='`date +"%Y-%m-%d"`'  (note the extra pair of quotes around the backticks)
echo $date
```

environment

```
export DATE=`date +"%Y-%m-%d"`
echo \$DATE
```

<br>

## Filetypes

### Getting filetype from object

Simplest approach:
```
$input.is_of_type('fastq')
```

example: sorting list of history inputs by file type
```
#def sort_fastq_fasta(files):
    #set fastqs = [f for f in $files if f.is_of_type('fastq')]
    #set fastas = [f for f in $files if f.is_of_type('fasta')]
    #set out = $fastqs + $fastas
    #return $out
#end def
```

<br>

## Imports

### Import a local Python module

Sometimes it is useful to export complex logic to a Python file.

But you can't do this:
```
import mymodule
```

Or this:
```
from . import mymodule
```

...because who knows where the Python interpreter is at runtime?

Sometimes it may be cleaner to call a Python script with bash in the `<command>` section, but this is not an option if you are writing a `<configfile>`.

**Solution**

This seems to work reliably:
```
## Import render module from ./subdir/render.py to template some app code
## -----------------------------------------------------------------------------
#import os
#import importlib.util
#set modpath = $os.path.join($__tool_directory__, "subdir/render.py")
#set spec = $importlib.util.spec_from_file_location("render", $modpath)
#set render = $importlib.util.module_from_spec(spec)
#$spec.loader.exec_module(render)

## render.app() should return and insert templated code as a string
$render.app($input1, $input2, $input3)

```

## Static files

Sometimes you'll see tools with a `static` folder in the tool root. Static assets in this folder can be accessed in the tool help section.

**Note:** This won't work in development. These static files are collected and served from the Toolshed, so will only work if the tool have been installed from the Toolshed. On Galaxy, static assets will be given a path like this:

Example: [Bandage tool](https://github.com/galaxyproject/tools-iuc/blob/master/tools/bandage/bandage_image.xml)

Image URL rendered:
https://usegalaxy.org.au/shed_tool_static/toolshed.g2.bx.psu.edu/iuc/bandage/bandage_image/0.8.1+galaxy3/bandage_graph.png

Take this tool directory:

```
test-data/
static/
  - images/
    - logo.png
mytool.xml
```

In the `<help>` section of `mytool.xml` you can reference the image `logo.png` like so:

```xml
<help><![CDATA[

Help text blah blah blah

.. image:: $PATH_TO_IMAGES/logo.png
:height: 500
:alt: Tool logo

Blah blah blah

]]></help>
```
