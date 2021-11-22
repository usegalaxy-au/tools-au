
## introduction

Tool wrapping is quite challenging. 
Most tools will require the use of a trick or established pattern to solve problems related to running programs on galaxy. 
We need a place to store tricky situations alongside the patterns which solve those situations.

This file is intended to be the reference which stores tool xml patterns and workarounds for tricky situations.

<br>

## contents
* [Variables](#variables)
* [Filetypes](#filetypes)

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


