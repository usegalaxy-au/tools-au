

## Setting variables

**basic**

setting
`#set myvar = 1` (cheetah)
`export MYVAR=1`  (env)

referencing
`echo $myvar`
`echo \$MYVAR` (note the dollar is escaped)

**shell command within var**

setting 
`#set date='\`date +"%Y-%m-%d"\`'`  (cheetah) (note the command string around the backticks has to be quoted)
`export DATE=\`date +"%Y-%m-%d"\``  (env)

referencing
`echo $date`
`echo $DATE`



