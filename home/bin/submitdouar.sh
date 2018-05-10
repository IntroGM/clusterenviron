#!/bin/bash 

DOUARBIN=${HOME}/bin/douar_wsmp
WRKDIR=/globalscratch/${USER}

RUNTIME="23:59:59"
NTASKS=16
QUEUE="normal"
MEMPERCPU=12000
RESTART=0
RESTARTDIR=""
DEBUGGER=""

USAGE_LINE="
 
 Usage: $0 -i inputfile [options]

 Options:
  -b {douar binary}      Default: $DOUARBIN
  -t {runtime}           Default: $RUNTIME
  -n {ntasks}            Default: $NTASKS
  -m {mempercpu}         Default: $MEMPERCPU
  -r {restartdir}        Default: $RESTARTDIR
  -q {queue}             Default: $QUEUE
  -d {debugger cmd}      Default: $DEBUGGER
"

ARGFLAG_I=0

while getopts i:b:d:t:n:m:r:q:h OPT; do
  case "$OPT" in
    i)
      ARGFLAG_I=1
      INPUTFILE="$OPTARG"
      if [ ! -f "$INPUTFILE" ]
      then
        echo "Input file ($INPUTFILE) does not exist!"
        exit 1
      fi ;;
    b)
      DOUARBIN="$OPTARG" 
      if [ ! -f "$DOUARBIN" ]
      then
        echo "Binary $DOUARBIN does not exist!"
        exit 1
      fi ;;
    d)
      DEBUGGER="$OPTARG" ;;
    t)
      RUNTIME="$OPTARG" ;;
    n)
      NTASKS=$OPTARG ;;
    m)
      MEMPERCPU=$OPTARG ;;
    h)
      echo "$USAGE_LINE"
      exit 0 ;;
    r)
      RESTART=1
      RESTARTDIR=$OPTARG ;;
    q)
      QUEUE=$OPTARG ;;
    [?])
      echo "$USAGE_LINE" >&2
      exit 1 ;;
  esac
done

if [ $ARGFLAG_I -eq 0 ]
then
  echo "Must define input file with -i" >&2
  exit 1 
fi

echo $INPUTFILE
WORKNAME=`basename $INPUTFILE|sed 's/\(.*\)\.\(.*\)/\1/'`
SECID=`date +%y%m%d%H%M%S`
if [ $RESTART == 1 ]
then
    WRK=${RESTARTDIR}
else
    WRK=${WORKNAME}_${SECID}
fi


cd ${WRKDIR}  # should be externally defined
if [ ! -e douar/$WRK ]
then
  mkdir douar/$WRK
fi

cd douar/$WRK
# needed for normal output
mkdir -p OUT
# needed for debug output
mkdir -p DEBUG/mpilogs
mkdir -p DEBUG/OLSF
mkdir -p DEBUG/SURFACES
mkdir -p DEBUG/FORCES
mkdir -p DEBUG/BC

if [ -e input.txt ]
then
    cp input.txt input.txt_${SECID}
fi
cp $INPUTFILE input.txt

SINFOFILE="job_info.txt"

module load intel
module load mvapich2
export MV2_ENABLE_AFFINITY=0

sbatch <<EOF
#!/bin/bash -l
#SBATCH -J ${WORKNAME}
#SBATCH -e ${WORKNAME}_e%j
#SBATCH -o ${WORKNAME}_o%j
#SBATCH -t ${RUNTIME}
#SBATCH -n ${NTASKS}
# ! SBATCH --nodes=${NNODES}
# ! SBATCH --ntasks-per-node=${NTASKSPERNODE}
#SBATCH --mem-per-cpu=${MEMPERCPU}
#SBATCH -p ${QUEUE}
echo Submitted: `date` >> $SINFOFILE
echo Started: \`date\` >> $SINFOFILE
echo Nodes: \$SLURM_NODELIST >> $SINFOFILE
echo Bin: ${DOUARBIN} >> $SINFOFILE
echo "Dbg: ${DEBUGGER}" >> $SINFOFILE
echo Num of nodes: \$SLURM_NNODES >> $SINFOFILE
echo Num of procs: \$SLURM_NPROCS >> $SINFOFILE
srun ${DEBUGGER} ${DOUARBIN}
EOF
