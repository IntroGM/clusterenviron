#!/bin/bash

# LMK 2015-10-09
# Script to process DOUAR output. Each timestep goes into a separate tar archive.
#  - Handles normal and debug output
#  - Assumes input_of_outputs.txt to exist in the working directory
#  - Assumes Douar output files to exist in the working directory
#  - Assumes models are not nested

# Default values for command line arguments.
# Modify for your needs.

POSTPROCBIN=$HOME/bin/douar-post
HANDLE_DEBUG=0
HANDLE_OUTPUT=1
BASENAME=`basename \`pwd | sed "s/\/OUT//"\``
REPROCESS=0
ONLYSTEPS=""
STARTSTEP=0
LOGGING=0
CREATETAR=0
EVERYNSTEP=1

# ---------------------------------------------------------------------------- #

USAGE_LINE="Usage: $0 [options below]

  -p prefix    Prefix output with this string. Default is '$BASENAME'.
  -o [0|1]     Handle regular output files. Default is ${HANDLE_OUTPUT}.
  -d [0|1]     Handle debug output files. Default is ${HANDLE_DEBUG}.
  -b path      Path to the Douar post-processing executable.
               Default is: $POSTPROCBIN
  -r [0|1]     Reprocess existing post-process output.
               Default is ${REPROCESS}.
  -s step(s)   Only postprocess given step(s) (separated by spaces).
  -S step      Start from given step.
  -n N         Process every Nth step only. Default is every step.
  -l [0|1]     Logging on/off. Default is ${LOGGING}.
  -t [0|1]     Move created VTK files into TAR archives. Default is ${CREATETAR}.
  -h           Print this help.
"

find_file_up () {
  S="${PWD}"
  while [ -n "${S}" ]
  do
    if [ -f "$S/$1" ]
    then
      echo "$S"
    fi

    S=${S%/*}
  done

  echo ""
}

while getopts p:b:o:d:r:s:l:t:S:n:h OPT; do
  case "$OPT" in
    t)
      CREATETAR="$OPTARG" ;;
    l)
      LOGGING="$OPTARG" ;;
    s)
      ONLYSTEPS="$OPTARG" ;;
    S)
      STARTSTEP="$OPTARG" ;;
    p)
      BASENAME="$OPTARG" ;;
    o)
      HANDLE_OUTPUT="$OPTARG" ;;
    d)
      HANDLE_DEBUG="$OPTARG" ;;
    n)
      EVERYNSTEP="$OPTARG" ;;
    b)
      if [ -x "$OPTARG" ];
      then
        POSTPROCBIN="$OPTARG" 
      else
        echo "File $OPTARG not executable" >&2
        exit 1 
      fi ;;
    r)
      REPROCESS="$OPTARG" ;;
    h)
      echo "$USAGE_LINE"
      exit 0 ;;
    [?])
      echo "$USAGE_LINE" >&2
      exit 1 ;;
  esac
done

if [ $LOGGING -eq 1 ];
then
  LOGFILE="process_outbin_$$.log"
else
  LOGFILE="/dev/null"
fi
TEMPFILE=`mktemp`

trap ctrl_c INT 

function ctrl_c() {
  rm $TEMPFILE
  echo "Caught SIGINT. Exiting." >> $LOGFILE
  exit 1
}

if [ -f "input_of_outputs.txt" ]
then
  echo "Found input_of_outputs.txt" >> $LOGFILE
  REMOVE_INPUTOFOUTPUTS=0
else
  INOUTLOC=`find_file_up input_of_outputs.txt`
  if [ -n "$INOUTLOC" ] 
  then
    echo "Using input_of_outputs.txt from $INOUTLOC"
    ln -s $INOUTLOC/input_of_outputs.txt .
    REMOVE_INPUTOFOUTPUTS=1
  else
    echo "Error: input_of_outputs.txt does not exist" >&2
    exit 1
  fi
fi

echo "Prefix: $BASENAME" >&2
echo "  Output: $HANDLE_OUTPUT" >&2
echo "  Debug:  $HANDLE_DEBUG" >&2

for f in ./time_*
do
  BINFILE=$f
  echo $f | grep '\/time_[0-9]\{4\}.*bin$' > /dev/null
  if [ $? -eq 0 ];
  then
    TSTEP=`echo $f | sed 's/.*\/time_\([0-9]\{4\}\).*bin$/\1/g'`
  else
    echo '!! Output filename not time_xxxx[_xxxx].bin' >&2
    echo $f >&2
    exit 1
  fi

  echo $f | grep '\/time_[0-9]\{4\}_[0-9]\{4\}.*bin$' > /dev/null
  if [ $? -eq 0 ];
  then
    ISDEBUG=1
    DSTEP=`echo $f | sed 's/.*\/time_[0-9]\{4\}_\([0-9]\{4\}\).bin$/\1/g'`
  else
    ISDEBUG=0
    DSTEP=""
  fi

  ITSTEP=$((10#$TSTEP)) #`echo $TSTEP | sed 's/^0*\([0-9]+\)/\1/g'` #$((TSTEP+0))
  IDSTEP=$((10#$DSTEP)) #`echo $DSTEP | sed 's/^0*\([0-9]+\)/\1/g'` #IDSTEP=$((DSTEP+0))

  SKIPTHIS=0
  if [ -n "$ONLYSTEPS" ];
  then
    SKIPTHIS=1
    for ALLOWSTEP in $ONLYSTEPS;
    do
      if [ $ALLOWSTEP -eq $ITSTEP ];
      then
        SKIPTHIS=0
        break
      fi
    done
  fi

  if [ $ITSTEP -lt $STARTSTEP ];
  then
      SKIPTHIS=1
  fi

  if [ $(( ($ITSTEP-$STARTSTEP) % $EVERYNSTEP )) -ne 0 ];
  then
      SKIPTHIS=1
  fi

  if [ $SKIPTHIS -eq 1 ];
  then
    continue
  fi
  
  echo ==== $BINFILE ====  >> $LOGFILE
  echo TSTEP = $ITSTEP >> $LOGFILE
  echo ISDEBUG = $ISDEBUG >> $LOGFILE
  echo DSTEP = $IDSTEP >> $LOGFILE
  
  if [ $ISDEBUG -eq 1 ]
  then
    if [ $HANDLE_DEBUG -eq 0 ]
    then
      continue
    fi
    echo "OUT" > $TEMPFILE
    echo $ITSTEP >> $TEMPFILE
    echo "y" >> $TEMPFILE	# is a debug output
    echo $IDSTEP >> $TEMPFILE
    echo "n" >> $TEMPFILE	# is not at nested model
    echo "1" >> $TEMPFILE	# VTK output
    echo "Processing debug output,  step $ITSTEP / $IDSTEP"
  else
    if [ $HANDLE_OUTPUT -eq 0 ]
    then
      continue
    fi
    echo "OUT" > $TEMPFILE
    echo $ITSTEP >> $TEMPFILE
    echo "n" >> $TEMPFILE	# is not a debug output
    echo "n" >> $TEMPFILE	# is not at nested model
    echo "1" >> $TEMPFILE	# VTK output
    echo "Processing regular output, step $ITSTEP"
  fi

  if [ $ISDEBUG -eq 1 ]
  then
    TARF="${BASENAME}_${TSTEP}_${DSTEP}.tar"
  else
    TARF="${BASENAME}_${TSTEP}.tar"
  fi

  SKIPPROCESSING=0
  if [ $REPROCESS -eq 0 ]
  then
    # check if time step is already processed into a tar archive
    if [ -f "${TARF}" ]
    then
      echo "TAR ${TARF} exists (reprocess: 0)" >> $LOGFILE
      echo "  ... skip" >&2
      SKIPPROCESSING=1
      CREATETAR=0  # do not overwrite anything in tar files
    fi
    
    if [ $SKIPPROCESSING -eq 0 ]
    then
      # check if time step is already processed into a vtk file
      if [ $ISDEBUG -eq 1 ]
      then
        LSRES=`ls ${BASENAME}_*_${TSTEP}_${DSTEP}.vtk 2> /dev/null 1> /dev/null`
        RES=$?
      else
        LSRES=`ls ${BASENAME}_*_${TSTEP}.vtk 2> /dev/null 1> /dev/null`
        RES=$?
      fi
      if [ $RES -eq 0 ] 
      then
        echo "VTK file(s) for ${TSTEP} exists (reprocess: 0)" >> $LOGFILE
        echo "  ... skip" >&2
        SKIPPROCESSING=1
      fi

      #for vtkf in ./*.vtk
      #do
      #  DATANAME=`echo $vtkf | sed 's/\.vtk$//g' | sed 's/^\.\///g'`

      #  if [ $ISDEBUG -eq 1 ]
      #  then
      #    LOOKFOR="^[a-zA-Z0-9_]\+_[a-zA-Z0-9_]\+_${TSTEP}_${DSTEP}$"
      #  else
      #    LOOKFOR="^[a-zA-Z0-9_]\+_[a-zA-Z0-9_]\+_${TSTEP}$"
      #  fi
      #  RET=`echo ${DATANAME} | grep "${LOOKFOR}"`
      #  if [ $? -eq 0 ]
      #  then
      #    echo "VTK ${DATANAME} exists (reprocess: 0)" >> $LOGFILE
      #    echo "  ... skip" >&2
      #    SKIPPROCESSING=1
      #    break
      #  fi
      #done
    fi
  fi

  if [ $SKIPPROCESSING -eq 0 ]
  then
    $POSTPROCBIN < $TEMPFILE >> $LOGFILE
  else
    continue
  fi
  
  for vtkf in ./*.vtk
  do
    if [ ! -f "$vtkf" ]; then continue; fi
    DATANAME=`echo $vtkf | sed 's/\.vtk$//g' | sed 's/^\.\///g'`
    
    if [ $ISDEBUG -eq 1 ]
    then
      NEWVTKF="./${BASENAME}_${DATANAME}_${TSTEP}_${DSTEP}.vtk"
    else
      NEWVTKF="./${BASENAME}_${DATANAME}_${TSTEP}.vtk"
    fi
    
    RET=`echo $DATANAME | grep "_[0-9]\+$"`
    if [ $? -eq 0 ]
    then
      echo "Not renaming ${DATANAME}.vtk -- already processed(?)" >> $LOGFILE
      if [ $ISDEBUG -eq 1 ]
      then
        LOOKFOR="^[a-zA-Z0-9_]\+_[a-zA-Z0-9_]\+_${TSTEP}_${DSTEP}$"
      else
        LOOKFOR="^[a-zA-Z0-9_]\+_[a-zA-Z0-9_]\+_${TSTEP}$"
      fi
      RET=`echo ${DATANAME} | grep "${LOOKFOR}"`
      if [ $? -eq 0 ]
      then
        NEWVTKF="${DATANAME}.vtk"
      fi
    else
      echo "Moving $vtkf -> $NEWVTKF" >> $LOGFILE
      mv $vtkf $NEWVTKF
    fi

    if [ $CREATETAR -eq 1 ]
    then
      if [ -f $NEWVTKF ]
      then
        tar --append --file=$TARF $NEWVTKF
        rm -f $NEWVTKF
      fi
    fi
  done  
done

rm $TEMPFILE
if [ "$REMOVE_INPUTOFOUTPUTS" -eq 1 ]
then
  rm -f input_of_outputs.txt
fi
