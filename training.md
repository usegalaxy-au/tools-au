

# Tool Wrapping Training

## Introduction

Wrapping bioinformatics programs for the Galaxy platform is challenging. 
It requires good linux skills, and deep understanding of how Galaxy executes jobs. 

This document is designed to provide a structure for learning tool wrapping. Much about this topic has already been written, so this document contains many links to relevant material. It also serves as an index for you to get help when stuck with a problem. 

<br>

## Contents
* Introduction
    * What is Galaxy?
    * Who are the Galaxy Users? 
    * Why Wrap Tools? 
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
* Setup Your Development Environment
    * IDE
    * Planemo
    * Virtual Machine
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




## Introduction

**What is galaxy?**

Think back to the first business computers. At this time, humans interacted with computers using a command-line interface (CLI) running on a terminal. There was no graphical-user-interface, or 'GUI' which allowed anyone to walk up and use the system. Simply using a computer required formal training and expertise. 

Graphical user interfaces (GUIs) really changed the game as they allowed more people to jump in. People could use the system and have a go, without first getting bogged down in learning how to use the operating system or program from the command line. Sure, people still needed to learn how to use programs (eg word processing) by clicking around, but this proved much more accessible than the command line. 

Fast-forward to today, and everything is a GUI. Very few people who use computers actually ever touch the command line anymore. Could you imagine facebook being only accessible from the command line (this is possible btw)? No one would use it. Its just not accessible enough for the average person to use. 

That said, one field where the CLI still dominates is bioinformatics. While there are some web-servers like BLAST which make life easier, the majority of bioinformatics is still performed on the command-line. Some software tools even require knowledge of a specific programming language (usually R) in order to run them. 

The are many reasons why bioinformatics tools mainly exist on the command line. 
Firstly, they usually only do 1 thing. No point in creating a GUI if all the program does is press a big 'run' button after providing some settings. Secondly, the code is often written by PhD candidates and research groups researching a specific area of biology. Not many people in these situations are industry-grade software engineers with a computer science background. Thirdly, GUIs are expensive and funding could pose an issue. 

This situation is somewhat unfortunate. As computational analysis is now present in most published research projects, the above presents a large barrier. Without an embedded bioinformatician, wet-lab scientists wishing to analyse their data would first need to spend months learning programming and linux skills in order to execute the tools require for their analysis. 

Cue Galaxy. Galaxy's mandate is to bring bioinformatics into the GUI era. By doing this, it will open the door for countless researchers and hopefully the general public to get involved with bioinformatics and run analysis. Galaxy has become a major platform where people can do bioinformatics (even complex analysis pipelines and workflows) without using the command line or writing scripts. 

**Who are the galaxy users?**
- non computer science ppl
    - Bioinformatic analysis is incresingly present in research.
    - rare for no computational analysis be performed as part of a research project
    - some groups have embedded bioinformaticians, but some dont
    - galaxy can allow research groups to do their bioinformatics themselves using the GUI
- students
- Brings a huge number of people to the table

**Why wrap tools?**
- How does tool wrapping achieve for this system?
    - Wrapping a tool for the galaxy platform is like unlocking a new character in a video game.
    - It enriches the ecosystem, and provides users with a new software tool they can use in their analysis
    - highly important as new, more powerful tools are constantly being created for the field. 
    - 



## Setup Your Development Environment

### IDE
### Planemo
### Virtual Machine


## Galaxy Job Execution


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


