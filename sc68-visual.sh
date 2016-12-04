#!/bin/bash
# YM register visualizer via sc68 
# GPLv3 gunstick@syn2cat.lu 2016
# ULM rulez!
# thanks Ben for the awesome player
exec sc68 --ym-engine=pulse -qqq "$@" &  
bgjob=$!
trap "kill $bgjob" 1 2 3
stdbuf -oL -eL sc68 --ym-engine=dump --ym-clean-dump  -qqq "$@" |
awk 'BEGIN{   
        shape["0x00"]="\\____"  
        shape["0x01"]=shape["0x02"]=shape["0x03"]=shape["0x00"]
        shape["0x04"]="/|___"   
        shape["0x05"]=shape["0x06"]=shape["0x07"]=shape["0x04"]
        shape["0x08"]="\\|\\|\\" 
        shape["0x09"]="\\____"  
        shape["0x0A"]="\\/\\/\\"
        shape["0x0B"]="\\|---"   
        shape["0x0C"]="/|/|/"  
        shape["0x0D"]="/----"  
        shape["0x0E"]="/\\/\\/"  
        shape["0x0F"]="/|___"   
      }
function noisetone(n,t) {   # 0 means output is ON, else output is OFF
  if(n==0) {
    if(t==0) {
      return("!")
    } else {
      return("'\''")
    }
  } else {
    if(t==0) {
      return(".")
    } else {
      return(" ")
    }
  }
}
      {
      dash=""
      gotdata=0
      output=output sprintf("%s %s ",$1,$2)
      split($3,new,"-")
      for(i=1;i<=13;i++)
        {
          if((old[i]==new[i])||(new[i]==".."))
          {
            output=output sprintf("%c..",dash)
          }else{
            output=output sprintf("%c%s",dash,new[i])
            gotdata=1
            bytes++
          }
          if(new[i]!="..")
          {
            old[i]=new[i]
          }
          dash="-"
        }
      if(new[14]=="..") # no shape register written
      {
        output=output sprintf("%c..",dash)
        shapewritten=" "
      } else {
        output=output sprintf("%c%s",dash,new[14])
        shapewritten="~"
        old[14]=new[14]
        gotdata=1
        bytes++
      }
      env=0
      if (gotdata==1) {
        curtime=strtonum("0x"$2)
        mixer=strtonum("0x"old[8])
        c0=noisetone(and(mixer,8),and(mixer,1))
        c1=noisetone(and(mixer,16),and(mixer,2))
        c2=noisetone(and(mixer,32),and(mixer,4))
        if(strtonum("0x"old[9])>15){v0="V";env=1}else{v0=substr(old[9],2,1)}
        if(strtonum("0x"old[10])>15){v1="V";env=1}else{v1=substr(old[10],2,1)}
        if(strtonum("0x"old[11])>15){v2="V";env=1}else{v2=substr(old[11],2,1)}
        printf "%s # %6d,",output,curtime-oldtime
        if((v0=="0")) {
          printf "   %s%1s,",c0,v0
        } else {
          printf "%3s%s%1s,",substr(old[2],2,1)old[1],c0,v0
        }
        if((v1=="0")) {
          printf "   %s%1s,",c1,v1
        } else {
          printf "%3s%s%1s,",substr(old[4],2,1)old[3],c1,v1
        }
        if((v2=="0")) {
          printf "   %s%1s,",c2,v2
        } else {
          printf "%3s%s%1s,",substr(old[6],2,1)old[5],c2,v2
        }
        if(and(compl(mixer),0x38)!=0) {   # only wite noise freq when actually used
          printf "%2s,",old[7]   
        } else {
          printf "%2s,","--"
        }
        if(env==1) { # only write envelope info if actually used
          printf "%s",old[13]old[12]
          printf "%c",shapewritten
          printf "%s",shape["0x"old[14]]
        }
        printf "\n"
        oldtime=curtime
        outlines++
      } 
      output=""
     }
    END {
      print outlines " lines, with " bytes " bytes. Total: " lines+2*bytes
    }'
#kill $bgjob
# First colums is the play pass number(when the music sequencer is call), you can ignore that. 
# Second is the timestamp. It's a YM clock cycle number (64bit). 
# For the Atari ST the clock frequency is 2Mhz. Everything period registers rely on that. 
# If your clock is different you'll have to convert all periods (0-1/2-3/4-5/6/11-12).
# `..' means the register is not updated. All write access are logged even if it's the same value.
# Just as the player does. Generally it does not matter and it can be optimized...
