

# Tool Wrapping Training

## Preface

Wrapping bioinformatics programs for the Galaxy platform is challenging. 
It requires good linux skills, and deep understanding of how Galaxy executes jobs. 

This document is designed to provide a structure for learning tool wrapping. Much about this topic has already been written, so this document contains many links to relevant material. It also serves as an index for you to get help when stuck with a problem. 

<br>

## Contents
* Introduction
* Setup Your Development Environment
    * IDE
    * Planemo
    * Virtual Machine
* The Galaxy System
    * Overview
    * Job Destinations
    * Job Execution
    * Datasets
* Galaxy Tool UI
    * Introduction
    * Params and Outputs
    * Tokens
    * Macros
    * Command section
        * Overview 
        * Cheetah basics 
        * Preprocessing
        * Tool execution
        * Postprocessing
        * Tricky Cases
    * Configfiles
    * Metadata
        * Tool Name and Version 
        * Citations
        * Help
* Tool Wrapping Process
    * Before You Wrap
        * Searching for Wrappers
        * Identifying time-consuming tools
    * Process
    * Submission
        * toolshed
        * tools-iuc
    * Post-wrapping tasks
* Getting Help


<br>

## Introduction
<br>

### Section Overview

This section given an overview of the motivations behind The Galaxy Project. <br>It also provides context as to the importance of tool wrapping. 

<br>

### Galaxy

**History of command-lines and user interfaces**

Think back to the first business computers. At this time, humans interacted with computers using a command-line interface (CLI) running on a terminal. There was no graphical-user-interface, or 'GUI' which allowed anyone to walk up and use the system. Simply using a computer required formal training and expertise. 

Graphical user interfaces (GUIs) really changed the game as they allowed more people to jump in. People could use the system and have a go, without first getting bogged down in learning how to use the operating system or program from the command line. Sure, people still needed to learn how to use programs (eg word processing) by clicking around, but this proved much more accessible than the command line. 

Fast-forward to today, and everything is a GUI. Very few people who use computers actually ever touch the command line anymore. Could you imagine facebook being only accessible from the command line (this is possible btw)? No one would use it. Its just not accessible enough for the average person to use. 

**CLI and Bioinformatics**

One field where the CLI still dominates is bioinformatics. While there are some web-servers like BLAST which make life easier, the majority of bioinformatics is still performed on the command-line. Some software tools even require knowledge of a specific programming language (usually R) in order to run them. 

The are many reasons why bioinformatics tools mainly exist on the command line. 
Firstly, they usually only do 1 thing. No point in creating a GUI if all the program does is press a big 'run' button after providing some settings. Secondly, the code is often written by PhD candidates and research groups researching a specific area of biology. Not many people in these situations are industry-grade software engineers with a computer science background. Thirdly, GUIs are expensive and funding could pose an issue. 

This situation is somewhat unfortunate. As computational analysis is now present in most published research projects, the above presents a large barrier. Without an embedded bioinformatician, wet-lab scientists wishing to analyse their data would first need to spend months learning programming and linux skills in order to execute the tools require for their analysis. 

**Galaxy: bringing bioinformatics into the GUI era**

Cue Galaxy. Galaxy's mandate is to bring bioinformatics into the GUI era. Galaxy has become a major platform where people can do bioinformatics (even complex analysis pipelines and workflows) without using the command line or writing scripts. By providing a GUI, galaxy will open the door for countless researchers and hopefully the general public to get involved with bioinformatics and to run their analysis. 

<br>

### Tool Wrapping

**What is tool wrapping?**

At its core, Galaxy allows users to run (theoretically) any bioinformatics analysis on the web using a GUI. It has many great features like creating workflows and providing a data sharing platform, but the core functionality is to run programs without the command line. 

Tool wrapping is the process of writing a definition for a program (currently using XML) which allows the software to be run via GUI on galaxy. This incorporates how the galaxy UI will look when users go to run the tool (customising the tool form), and some CLI related code & logic which allows the tool to actually be run under the hood.

**Why wrap tools?**

Wrapping a tool for the galaxy platform is like unlocking a new character in a video game. It enriches the ecosystem, and provides users with new abilities. To reiterate the previous sections, the aim of The Galaxy Project is to provide a GUI. If a galaxy user needs to run a certain bioinformatics tool in their analysis but its not available on galaxy, it needs to be wrapped! This is a continual process as new, or more powerful tools are regularly created within the field. 

Currently, the pace of new tool development outmatches the rate they can be wrapped for the Galaxy system. This means we must prioritise tools which are likely to have high impact. More on this later in the __TOOLS__ section.

**How do users benefit from new tool wrappers?**

Galaxy has 3 main types of users: Large research initiatives, research groups, and students. 

The first group is multi-researcher projects. These large projects / initiatives will sometimes partner with a galaxy server to process many samples in a pipeline. In these cases, all tools in the pipeline need to be available on that server. Often most of the tools will be available, but a few may need to be wrapped. These tools become high-priority in terms of wrapping as they enable an entire pipeline, and because the project is held up until they are available.

The second group is individual researchers or research groups. This group often wants to run a few relatively straightforward analyses on data they have generated in the lab. While the analysis might be seen as routine, there are few situations where a single cover-all 'best practise' workflow is available. Analysis pipelines are often tailored per analysis, and as such the group will often wish to include a number of shiny new tools from their field which are not yet available on Galaxy. This is a similar situation to the above, where wrapping these tools enables an analysis pipeline, and brings greater functionality to Galaxy in that field. 

The final group is students / learners. Teaching students about Galaxy brings a huge number of new people to the table, and is incredibly important for its continual growth. Students usually learn routine workflows where all tools are available, but wrapping is still implicated for this group! Making sure new wrappers are high quality and well documented serves makes them easier to use and understand. This serves a core tenet of Galaxy - accessibility - as tool wrappers are supposed to make bioinformatics easy. A wrapper which has poor documentation and bad UI doesn't do a good job of making the tool accessible, and may be less usable than the command line in some extreme cases! 


## Setup Your Development Environment
### IDE
- VSC 
### Planemo
- lint, test, serve
### Dev server
- check on real server? is this actually necessary

## The Galaxy System
### Overview
- 
### Job Destinations
- what are they
- what are common desintations
- how are they set up
- dependency resolution
    - conda 
    - container
### Job Execution
- What is a galaxy job
- working directory
    - config/
    - working/
    - output/
    - script files
    - stderr / stdout
- input & output data
- environment variables 
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


