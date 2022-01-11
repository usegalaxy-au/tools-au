

# Tool wrapping: barebones documentation

## Preface

This file is a stripped back, minimal version of the full training material. 
It provides the essentials needed to get started with tool wrapping and nothing more. 


## Contents
* [Introduction](#introduction)
* [Setup Your Development Environment](#setup-your-development-environment)
* [The Galaxy System](#the-galaxy-system)
* [Galaxy Tool UI]()
* [Tool Wrapping Process]()
* [Getting Help]()

<br>

## Introduction

Galaxy's mandate is to bring bioinformatics into the GUI era. Galaxy has become a major platform where people can do bioinformatics (even complex analysis pipelines and workflows) without using the command line or writing scripts. By providing a GUI, galaxy will open the door for countless researchers and hopefully the general public to get involved with bioinformatics and to run their analysis. 

Tool Wrapping is the process of making a tool runnable on galaxy. This includes understanding the tool's dependencies, command line format (options), writing a galaxy UI tool form, and writing tests to prove it all works. 

<br>

## Setup Your Development Environment

To develop tool wrappers, you need a good IDE to write xml and search, and a system to test the wrappers you have built. <br>
***Visual studio code*** is recommended for wrapper development, and ***planemo*** is recommended to test your work. 

### IDE

VSC is highly recommended
- Has galaxy extension (ext: 'Galaxy Tools')
    - Provides code snippets (to make boilerplate tool, write gx-tool and select)
    - Tag and attribute auto-completion 
    - Documentation on hover
- Allows searching for use-cases or examples in tool xml
    - Clone the tools-iuc github (https://github.com/galaxyproject/tools-iuc)
    - Open the cloned repo with vsc
    - Use the search tool (left side nav button) for something you want to see an example of
    - Example: searching 'type="data_collection"' will show you examples of data_collections in use

### Planemo

https://planemo.readthedocs.io/en/latest/

Planemo allows you to check and test your wrapper. <br>
There are 3 main functions to discuss: lint, test, serve. 

**Installation**

```
# create env for planemo
python3 -m venv planemo

# load that env
$ source planemo/bin/activate

# install planemo into env
pip install planemo
```

DO NOT INSTALL PLANEMO USING CONDA IT DOESN'T WORK. ONLY PIP.

**planemo serve**

https://planemo.readthedocs.io/en/latest/commands/serve.html?highlight=serve

The first command to use is 'serve'. This command runs a containerised galaxy instance and serves it on localhost:9090. planemo serve is useful because it loads tool xml files and presents them as on a real server, so we can look at the wrapper UI we are currently working on. 

To use, navigate to a folder containing a tool xml file.
Execute the following:

```
planemo serve
```

It will take some time, but eventually will build galaxy and serve on localhost:9090. Look in the galaxy tools panel on the left side of your screen - you should see the tool you are working on. 

If the tool UI doesn't look right, make your change in the tool xml file, then refresh localhost:9090. The change should have been reflected in the running galaxy instance.  

**planemo lint**

https://planemo.readthedocs.io/en/latest/commands/lint.html?highlight=lint

The 'lint' command tests whether the tool xml violates any rules.
For example, each tool xml needs tests. If no tests are found in the xml, planemo will report it and fail the linting process.

To test, navigate to a folder containing a tool xml file.
Execute the following:  

```
planemo lint [tool_xml_file]
```

This will report any errors with the xml. These errors need to be addressed before submission. 

**planemo test**

https://planemo.readthedocs.io/en/latest/commands/test.html?highlight=test

Planemo test allows you to run tool xml tests and verify they pass. 
This is probably the most important command. 

To run tool tests, navigate to a folder containing a tool xml file.
Execute the following:  

```
planemo test [tool_xml_file]
```

This will read, then execute the tests you have specified within the `<tests>` tag in `tool_xml_file`. 

Note: <br>
Tool requirements need to already be installed when running planemo test. <br>
For example if you are wrapping the 'quast' tool, create and activate a conda environment for your development, and install 'quast' into that env. Then when you run `planemo test quast.xml`, the quast software will be available. This is actually similar to what happens when a job is run on galaxy. 

<br>


## The Galaxy System

### Overview

https://training.galaxyproject.org/training-material/topics/admin/

Galaxy is a complex system. For tool wrapping, we can mostly ignore how a galaxy instance is configured, but there are a few things which need to be touched on. These are: 
- Job destinations
- Job execution, and 
- Datasets in galaxy

### Job Destinations

https://training.galaxyproject.org/training-material/topics/admin/tutorials/job-destinations/tutorial.html
https://docs.galaxyproject.org/en/latest/admin/jobs.html

Job destinations specify 'where' a job is run. It mostly concerns the configuration of a environment where the tool is actually executed. 

As an example, we may specify that one of our destinations has the following: 
- 4 cores
- 16 Gb RAM
- Uses conda to load packages

Any tools which are set to use this 'job destination' will be executed on a node which has those specifications.

Job destinations are mainly the realm of Galaxy Admins, so we usually don't have to worry about it. There are a few instances where it matters though:
- large computational resource requirement
- tool uses a container


**Resources**

If we have wrapped a tool which is for large genome assembly, we should communicate with the Galaxy Aus Admin that they should set up a job destination with many cores and heaps of RAM. They will install the tool we wrapped, create a destination with those resources, then will map the tool to use this destination.  
There is nothing to write in terms of the wrapper, and doesn't affect the dev process, but for actual implementation its important.

**Containers**

By default, Galaxy uses conda to resolve dependencies. If the tool you are wrapping is quast, you need to specify quast as a requirement in the xml. At runtime, Galaxy will then use conda to get the quast conda package you specified and install it, then it will execute the code in the xml `<command>` section.

For containers this is not the case. To actually use a container as a dependency (ie you're running the tool using an image), a job destination has to be set up to use containers. Again, this is the realm of Galaxy Admins, but it applies when developing the wrapper. For example, to run planemo test to check your wrapper, it wont pull the container you specified unless you provide the `--mulled_containers` flag to `planemo test`. 


### Job Execution

Galaxy creates a folder when running a job. Every job submission gets its own sandbox environment to run in.  Inside is a set structure containing everything needed to execute the tool. It is very useful to check this folder when things aren't working. See below for details on the sandbox's structure. 

**Job sandbox**

![sandbox](images/sandbox.png)

This is the folder Galaxy sees when it is running a job. It contains everything needed to run that job. We will go through the important ones. 

**Workdir**

![workdir](images/workdir.png)

This is where the tool actually runs. Anything in the `<command>` section of the tool xml is templated into a string, then that string is run using this `working` folder as the home directory. 

If you write `echo "hi" > hello.txt` in the `<command>` section of the tool xml, a file called `hello.txt` will appear in the `working` directory. This is where the commands are run. 

From the above (first command), we see that the tool which was run produces a single folder called `expdata` when running. Inside `expdata` (second command) we have some outputs like a fasta database and some mass spec data.

**Scripts**

![tool_script](images/tool_script.png)

`tool_script.sh` contains the command line string you specified in the `<command>` section of the tool xml. It has now been templated by cheetah, and so has be condensed down to what will actually be run by the OS. Something to note here is that there are a lot of `.dat` files -> this relates to how Galaxy stores datasets. More on this below.   

There is another script file called `galaxy_[job_id].sh`. This script does everything else needed to run the job. This mainly includes setting up the dependencies (ie conda requirements or setting up a container to run), and configuring environment variables. We don't often need to check this file, but sometimes its handy - eg using singularity to run a tool - have all the singularity options and bind mounts been set up correctly? This is based on the job destination, and that info is all plain to see in `galaxy_[job_id].sh`.

**Output**

![sandbox](images/sandbox.png)

**Configfiles**

![sandbox](images/sandbox.png)


**environment variables**


### Datasets
- how does galaxy manage user data
- .dat files
- filetypes


## Galaxy Tool UI
https://training.galaxyproject.org/training-material/topics/dev/tutorials/tool-integration/slides.html#1
### Params and Outputs
### Tokens
### Macros
### Command section
**Overview**
**Cheetah basics**
https://cheetahtemplate.org/users_guide/intro.html
https://pythonhosted.org/Cheetah/
https://docs.galaxyproject.org/en/latest/dev/schema.html
**Preprocessing**
**Tool execution**
**Postprocessing**
**Tricky Cases**
**Best-practises**
### Configfiles
### Metadata
**Tool Name and Version**
**Citations**
**Help**


## Tool Wrapping Process
### Before You Wrap
**Searching for Wrappers**
**Identifying time-consuming tools**
### Process
### Submission
**toolshed**
**tools-iuc**
### Post-wrapping tasks


## Getting Help

