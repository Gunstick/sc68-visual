#!/bin/bash
# YM register visualizer via sc68 
# GPLv3 gunstick@syn2cat.lu 2016
# ULM rulez!
# thanks Ben for the awesome player

STYLE="scroll"         # classing dump with everything
STYLE="splitfix"       # top part: vbl, bottom: timers
#STYLE="splitscroll"    # future (scroll region for vbl)
#                    
# 0006E1 00010D2320 ..-..-7C-..-7C-..-..-..-..-..-..-..-..-.. #    639,   .0,17C.A,17C.7,--,
# patternNR (50/200Hz etc)
# |      time in hex
# |      |          R0+R1 freq channel A
# |      |          |     R2+R3 freq channel B
# |      |          |     |     R4+R5 freq channel C
# |      |          |     |     |     R6 freq nouse
# |      |          |     |     |     |  R7 mixer
# |      |          |     |     |     |  |  R8 volA
# |      |          |     |     |     |  |  |  R9 volB
# |      |          |     |     |     |  |  |  |  R10 volC
# |      |          |     |     |     |  |  |  |  |  R11+R12 env freq
# |      |          |     |     |     |  |  |  |  |  |     R13 env shape 
# |      |          |     |     |     |  |  |  |  |  |     |     time delta in dez
# |      |          |     |     |     |  |  |  |  |  |     |     |     channelA
# |      |          |     |     |     |  |  |  |  |  |     |     |     |     channelB
# |      |          |     |     |     |  |  |  |  |  |     |     |     |     |    channelC
# |      |          |     |     |     |  |  |  |  |  |     |     |     |     |    |      noise
# |      |          |     |     |     |  |  |  |  |  |     |     |     |     |    |      |  envelope
# 002B94 0006A904F2 ..-..-..-..-..-..-..-..-..-..-..-..-..-08 #   1650,1C3.C,152 V,   .0,--,002A~\|\|\

if [ "$DUMPFAST" = "" ]
then
  #exec sc68 --ym-engine=pulse -qqq "$@" &  
  exec sc68 -qqq "$@" &  
  bgjob=$!
  trap "kill $bgjob" 1 2 3
else
  f="-o/dev/null"
fi
tput clear
TimerLocation=28
TimerSize=25
#tput csr 1 25    # scroll region
stdbuf -oL -eL sc68 "$@" --ym-engine=dump --ym-clean-dump  -qqq $f  |
awk \
    -v TputEd="$(tput ed)"       \
    -v TputEl="$(tput el)"       \
    -v TputSc="$(tput sc)"       \
    -v TputRc="$(tput rc)"       \
    -v TputHome="$(tput home)"   \
    -v TputClear="$(tput clear)" \
    -v TputCuu1="$(tput cuu1)" \
    -v TputLower="$(tput cup $TimerLocation 0)" \
    -v maxtimerlines=$TimerSize \
    -v style="$STYLE" \
    '
     BEGIN{   
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
        new[14]=old[14]="0A"   # STNICCC2015 by 505 does not init shape, but seems to be this one
        VBLlines=25
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
      if(style!="scroll") {
      if (oldvbl" " != $1" ") {    # duh, one point where awk is bad.
        printf TputHome
        for(l=0;l<=VBLlines;l++) {
          printf "%02d\n",l
        }
        printf TputCuu1 TputEl
        #printf "%s\n%s",TputSc TputLower TputCuu1 TputCuu1, output TputEd TputRc
printf TputSc TputLower TputCuu1 TputCuu1 TputCuu1 "   VBL    YMtime     FreqA FreqB FreqC N  Mx VA VB VC FreqE Sh   delta  Channel A        Channel B        Channel C         N  Envelope   Upd" TputRc
        if(VBLlines++>=24) { 
           VBLlines=0;
           #printf TputEd  
           #printf TputHome 
        }
        printedlines=0
        vbl=1
      }
      if(vbl--==0) {printf TputLower ; printf TputEd}
      }
      output=""
      oldvbl=$1
      if(style!="scroll") {
        output=output sprintf("%02d %6s %s ",VBLlines,oldvbl,$2)
      } else {
        output=output sprintf("%6s %s ",oldvbl,$2)
      }
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
      if (gotdata==1 && printedlines<maxtimerlines ) {
        curtime=strtonum("0x"$2)
        mixer=strtonum("0x"old[8])
        c0=noisetone(and(mixer,8),and(mixer,1))
        c1=noisetone(and(mixer,16),and(mixer,2))
        c2=noisetone(and(mixer,32),and(mixer,4))
        if(strtonum("0x"old[9])>15){v0=shapewritten shape["0x"old[14]] old[13]old[12]    }else{v0=substr(old[9],2,1)}
        if(strtonum("0x"old[10])>15){v1=shapewritten shape["0x"old[14]] old[13]old[12]   }else{v1=substr(old[10],2,1)}
        if(strtonum("0x"old[11])>15){v2=shapewritten shape["0x"old[14]] old[13]old[12]   }else{v2=substr(old[11],2,1)}
        if((c0==" ")||(c0=="'\''")||(v0==0)) {f0="  "} else {f0=substr(old[2],2,1)old[1]}
        if((c1==" ")||(c1=="'\''")||(v1==0)) {f1="  "} else {f1=substr(old[4],2,1)old[3]}
        if((c2==" ")||(c2=="'\''")||(v2==0)) {f2="  "} else {f2=substr(old[6],2,1)old[5]}
        output=output sprintf (" # %6d|",curtime-oldtime)
        output=output sprintf ("%3s%s%-12s|",f0,c0,v0)
        output=output sprintf ("%3s%s%-12s|",f1,c1,v1)
        output=output sprintf ("%3s%s%-12s| ",f2,c2,v2)
        if(and(compl(mixer),0x38)!=0) {   # only wite noise freq when actually used
          output=output sprintf ("%2s ",old[7])
        } else {
          output=output sprintf ("%2s ","--")
        }
        output=output sprintf ("%4s%c%s ",old[13]old[12],shapewritten,shape["0x"old[14]])
        output=output sprintf ("%2d ",bytes-obytes)
        printf output 
        if (printedlines==0) {
          printf "%s\n%s",TputSc TputLower TputCuu1 TputCuu1 TputCuu1, output TputEd TputRc
        }
obytes=bytes
#        if(curtime > vbl) {
#          vbl=curtime+40048
          #printf "\n" curtime " " vbl "\n"
          printf "\n" TputEl
#        } else {
#          printf "\r"
#        }
        oldtime=curtime
        outlines++
        printedlines++
      } 
      if(style!="scroll") {
        if(printedlines>=maxtimerlines) {
          printf "." 
        }
      }else {
        maxtimerlines=printedlines+1
      }
      #output=""
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
