#!/bin/bash
# YM register visualizer via sc68 
# GPLv3 gunstick@syn2cat.lu 2016
# ULM rulez!
# thanks Ben for the awesome player

STYLE="scroll"         # classing dump with everything
STYLE="splitfix"       # top part: vbl, bottom: timers
STYLE="splitscroll"    # future (scroll region for vbl)
SHOW="all"             # show output even if no registers have been updated
#SHOW="updated"         # show only output if at least one register was updated
#                    
#14 001540 000CFDA000 26-02-E0-08-5E-..-04-32-0F-..-..-8E-..-.. #  13310|226!F           |    '\|\|\008E  |   .0           | 04 008E \|\|\ 20 
#vbl count (only in split output)
#|  patternNR (50/200Hz etc)
#|  |      time in hex
#|  |      |          R0+R1 freq channel A
#|  |      |          |     R2+R3 freq channel B
#|  |      |          |     |     R4+R5 freq channel C
#|  |      |          |     |     |     R6 freq nouse
#|  |      |          |     |     |     |  R7 mixer
#|  |      |          |     |     |     |  |  R8 volA
#|  |      |          |     |     |     |  |  |  R9 volB
#|  |      |          |     |     |     |  |  |  |  R10 volC
#|  |      |          |     |     |     |  |  |  |  |  R11+R12 env freq
#|  |      |          |     |     |     |  |  |  |  |  |     R13 env shape 
#|  |      |          |     |     |     |  |  |  |  |  |     |     time delta in dez
#|  |      |          |     |     |     |  |  |  |  |  |     |     |     channelA + env
#|  |      |          |     |     |     |  |  |  |  |  |     |     |     |                channelB + env
#|  |      |          |     |     |     |  |  |  |  |  |     |     |     |                |                channelC + env
#|  |      |          |     |     |     |  |  |  |  |  |     |     |     |                |                |                 noise
#|  |      |          |     |     |     |  |  |  |  |  |     |     |     |  !=noise+tone  |   '=noise      |  .=tone         |  envelope freq+shape
#|  |      |          |     |     |     |  |  |  |  |  |     |     |     |  v             |   v  env on    |  v              |  |          irq per vbl
#14 001540 000CFDA000 26-02-E0-08-5E-..-04-32-0F-..-..-8E-..-.. #  13310|226!F           |    '\|\|\008E  |   .0           | 04 008E \|\|\ 20 

if [ "$DUMPFAST" = "" ]
then
  #exec sc68 --ym-engine=pulse -qqq "$@" &  
  exec sc68 -qqq "$@" &  
  bgjob=$!
  trap "kill $bgjob" 1 2 3
else
  f="-o/dev/null"
fi
cleanup() {
  if [ "$STYLE" = "splitscroll" ]
  then
    tput csr 0 $(tput lines)
  fi
  tput cup $(tput lines) 1
  echo ""
}
if [ "$STYLE" != "scroll" ]
then
  trap cleanup 1 2 3 
fi
tput clear
TimerLocation=28  # which line on the screen timer display should be
TimerSize=40      # how many timer lines to show
#tput csr 1 25    # scroll region

# tput options:
# https://www.gnu.org/software/termutils/manual/termutils-2.0/html_chapter/tput_1.html
# ed: erase until end of display
# el: erase until end of line
# sc: save cursor position
# rc: restore cursor position
# home: go to top left
# clear: erase whole screen
# cuu1: move cursor up by one
# dim: half bright
# sgr0: normal
# cup y x: move cursor to position y x
# csr a b: set scroll region from line a to line b
header="   VBL    YMtime     FreqA FreqB FreqC N  Mx VA VB VC FreqE Sh   delta  Channel A           Channel B           Channel C            N  Envelope        Upd" 
if [ "$STYLE" =  "splitscroll" ]
then
  p=2
else
  p=1
fi
a=${header%%Channel A*};TputInfoA=$(tput cup $((TimerLocation-p)) ${#a})
a=${header%%Channel B*};TputInfoB=$(tput cup $((TimerLocation-p)) ${#a})
a=${header%%Channel C*};TputInfoC=$(tput cup $((TimerLocation-p)) ${#a})
stdbuf -oL -eL sc68 "$@" --ym-engine=dump --ym-clean-dump  -qqq $f  |
awk \
    -v TputEd="$(tput ed)"       \
    -v TputEl="$(tput el)"       \
    -v TputUnderline="$(tput smul)"       \
    -v TputSc="$(tput sc)"       \
    -v TputRc="$(tput rc)"       \
    -v TputCsr="$(tput csr 0 $((TimerLocation-4)) )"       \
    -v TputHome="$(tput home)"   \
    -v TputClear="$(tput clear)" \
    -v TputCuu1="$(tput cuu1)" \
    -v TputDim="$(tput dim)" \
    -v TputNormal="$(tput sgr0)" \
    -v TputSettab="$(tput hts)" \
    -v TputInvertOn="$(tput smso)" \
    -v TputInvertOff="$(tput rmso)" \
    -v TputLower="$(tput cup $TimerLocation 0)" \
    -v TputInfoA="$TputInfoA" \
    -v TputInfoB="$TputInfoB" \
    -v TputInfoC="$TputInfoC" \
    -v maxtimerlines=$TimerSize \
    -v style="$STYLE" \
    -v show="$SHOW" \
    -v header="$header" \
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
notes ="C-0,C#0,D-0,D#0,E-0,F-0,F#0,G-0,G#0,A-0,A#0,B-0,C-1,C#1,D-1,D#1,E-1,F-1,F#1,G-1,G#1,A-1,A#1,B-1,C-2,C#2,D-2,D#2,E-2,F-2,F#2,G-2,G#2,A-2,A#2,B-2,C-3,C#3,D-3,D#3,E-3,F-3,F#3,G-3,G#3,A-3,A#3,B-3,C-4,C#4,D-4,D#4,E-4,F-4,F#4,G-4,G#4,A-4,A#4,B-4,C-5,C#5,D-5,D#5,E-5,F-5,F#5,G-5,G#5,A-5,A#5,B-5,C-6,C#6,D-6,D#6,E-6,F-6,F#6,G-6,G#6,A-6,A#6,B-6,C-7,C#7,D-7,D#7,E-7,F-7,F#7,G-7,G#7,A-7,A#7,B-7,C-8,C#8,D-8,D#8,E-8,F-8,F#8,G-8,G#8,A-8,A#8,B-8,C-9,C#9,D-9,D#9,E-9,F-9,F#9,G-9,G#9,A-9,A#9,B-9,C-a,C#a,D-a,D#a,E-a,F-a,F#a,G-a,G#a,A-a,A#a,B-a" 
        if(style=="splitscroll") { 
          printf TputCsr TputLower
        }
      }
function freq2note(reg,div) {
  # http://poi.ribbon.free.fr/tmp/freq2regs.htm
  # http://newt.phys.unsw.edu.au/jw/notes.html
  # register value
  #reg=strtonum("0x"rough)*256+strtonum("0x"fine)
  reg=strtonum("0x"reg)
  if((reg==0)||(div==-1)) {return "   "}
  if(div==0) {div=16}
  freq=2000000/div/reg
  midinote=12*log(freq/440)/log(2)+69;
  return substr(notes,1+(int(midinote)-12)*4,3)
}
function vol_(str,vol) {    # underlines as much letters as there is volume
  vol=strtonum("0x"vol)
  if(vol==0) { return str}  # enevlope is on or silent
  return substr(str,1,4) TputUnderline substr(str,5,vol) TputNormal substr(str,vol+5,length(str)) 
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
function timertyper(ovol,vol,ctrl,     timertype) {
# call if(vbl!=0 && timertypeN=="")
# timertypeN=timertyper(new[N],cN)
# if(timertypeN!="") {  output=output TputSc TputInfoA timertypeN TputRc }
            timertype=""
            if((vol!="..")&&(ctrl=="."))   { timertype="     SID(pwm)      " }
            if((vol!="..")&&(ctrl==" "))   { timertype=" digit/short wave  " }
            if(ovol=="10")                 { timertype="     syncbuzz      " }
  return TputInvertOn timertype TputInvertOff
}
      {
      dash=""
      gotdata=0
      if(style!="scroll") {
        if (oldvbl" " != $1" ") {    # duh, one point where awk is bad.
          timertype0=timertype1=timertype2=""
          if(style=="splitfix") {
            printf TputHome
            for(l=0;l<=VBLlines;l++) {
              printf "%02d\n",l
            }
            printf TputCuu1 
            printf TputEl 
          }
          #printf "%s\n%s",TputSc TputLower TputCuu1 TputCuu1, output TputEd TputRc
          printf TputSc TputLower TputCuu1 TputCuu1 TputCuu1 header "\n" TputEl TputRc
          if(VBLlines++>=24) { 
             VBLlines=0;
             #printf TputEd  
             #printf TputHome 
          }
          printedlines=0
          vbl=1
        }
        if(vbl--==0) {printf TputLower 
          if (style=="splitscroll") {printf TputCuu1 } 
          printf TputEd
        }
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
            rold[i]=old[i]
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
      if ((gotdata==1 || show=="all") && printedlines<maxtimerlines ) {
        if(gotdata==0) {
          fade1=TputDim
          fade2=TputNormal
        } else {
          fade1=fade2=""
        }
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
        if((o0==f0 c0 v0) && (vbl!=0) ) {
          output=output vol_("                   |",v0)
        } else {
          #output=output sprintf ("%3s%s%-12s|",f0,c0,v0)
          output=output vol_(sprintf ("%3s-%3s_%1s%-10s|",f0,freq2note(f0),c0,v0),v0)
          if(vbl!=0 && timertype0=="") {
            timertype0=timertyper(rold[9],new[9],c0)
            if(timertype0!="") {  output=output TputSc TputInfoA timertype0 TputRc }
          }
        } 
        o0=f0 c0 v0
        if((o1==f1 c1 v1) && (vbl!=0) ) {
          output=output vol_("                   |",v1)
        } else {
          output=output vol_(sprintf ("%3s-%3s_%s%-10s|",f1,freq2note(f1),c1,v1),v1)
          if(vbl!=0 && timertype1=="") {
            timertype1=timertyper(rold[10],new[10],c1)
            if(timertype1!="") {  output=output TputSc TputInfoB timertype1 TputRc }
          }
        } 
        o1=f1 c1 v1
        if((o2==f2 c2 v2) && (vbl!=0) ) {
          output=output vol_("                   |",v2)
        } else {
          output=output vol_(sprintf ("%3s-%3s_%s%-10s|",f2,freq2note(f2),c2,v2),v2)
          if(vbl!=0 && timertype2=="") {
            timertype2=timertyper(rold[11],new[11],c2)
            if(timertype2!="") {  output=output TputSc TputInfoC timertype2 TputRc }
          }
        } 
        o2=f2 c2 v2
        if(and(compl(mixer),0x38)!=0) {   # only wite noise freq when actually used
          output=output sprintf (" %2s ",old[7])
        } else {
          output=output sprintf (" %2s ","--")
        }
        if((old[14]=="0A") || (old[14]=="0E"))  {   # triangles are half period
          div=512 
        } else {
          if((old[14]=="08") || (old[14]=="0C")) {  # sawtooth
            div=256
          } else {
            div=-1
          }
        }
        output=output sprintf ("%4s(%3s)%c%s ",old[13]old[12],freq2note(old[13]old[12],div),shapewritten,shape["0x"old[14]])
        output=output sprintf ("%2d ",bytes-obytes)
        output=fade1 output fade2
        if (style!="splitscroll") {printf output }
        if (printedlines==0) {
          if(style=="splitscroll") { 
             printf TputSc TputLower TputCuu1 TputCuu1 TputCuu1 TputCuu1 "\n" output TputRc
          } else {
             printf "%s\n%s",TputSc TputLower TputCuu1 TputCuu1 TputCuu1, output TputEd TputRc
          }
        } else {
          if((style=="sscroll")||(style=="splitscroll")) {printf output "\n"}
        }
        if(style=="scroll") { obytes=bytes 
        } else {
          if(printedlines==0) { obytes=bytes }
        }
#        if(curtime > vbl) {
#          vbl=curtime+40048
          #printf "\n" curtime " " vbl "\n"
          if (style!="splitscroll") {
            printf "\n" TputEl
          }
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
      print "\n" outlines " lines, with " bytes " bytes. Total: " lines+2*bytes
    }'
#kill $bgjob
# First colums is the play pass number(when the music sequencer is call), you can ignore that. 
# Second is the timestamp. It's a YM clock cycle number (64bit). 
# For the Atari ST the clock frequency is 2Mhz. Everything period registers rely on that. 
# If your clock is different you'll have to convert all periods (0-1/2-3/4-5/6/11-12).
# `..' means the register is not updated. All write access are logged even if it's the same value.
# Just as the player does. Generally it does not matter and it can be optimized...
