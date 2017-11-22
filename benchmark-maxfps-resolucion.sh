#!/bin/sh
if [ "$#" -ne 6 ]; then
    echo "run as ./benchmark-maxfps-resolucion.sh E STARTN ENDN DN Q SAMPLES"
    exit;
fi
E=$1
STARTN=$2
ENDN=$3
DN=$4
Q=$5
SAMPLES=$6
Rx=400
Ry=300
C=1
NOBJ=1
METHODS=("dummy" "BBox" "Avril" "Lambda (Newton)" "Lambda (Default)" "Flatrec" "Lambda (Inverse)" "Rectangle" "Recursive")
NM=8
for R in `seq ${STARTN} ${DN} ${ENDN}`;
do
    M=0
    S=0
    RX=$(($Rx*$R))
    RY=$(($Ry*$R))
    echo "Q=${Q} E=${E}  Rx=${RX} Ry=${RY} C=${C} NOBJ=${NOBJ}"
    #echo "Rx=${RX} Ry=${RY}"
    #echo "./Renderer.exe ${Rx} ${}   ${N} ${R}    ${q} ${RPARAM}"
    for k in `seq 1 ${SAMPLES}`;
    do
        #x=`./${BINARY} ${DEV} ${N} ${R} ${q} ${RPARAM}`
        x=`./Renderer.exe ${RX} ${RY} ${E} ${Q} ${C} ${NOBJ}`
        oldM=$M;
        M=$(echo "scale=10;  $M+($x-$M)/$k"           | bc)
        S=$(echo "scale=10;  $S+($x-$M)*($x-${oldM})" | bc)
    done
    echo "done"
    MEAN=$M
    VAR=$(echo "scale=10; $S/(${SAMPLES}-1.0)"  | bc)
    STDEV=$(echo "scale=10; sqrt(${VAR})"       | bc)
    STERR=$(echo "scale=10; ${STDEV}/sqrt(${SAMPLES})" | bc)
    TMEAN=${MEAN}
    TVAR=${VAR}
    TSTDEV=${STDEV}
    TSTERR=${STERR}
    echo "---> E=${E} --> (MEAN, VAR, STDEV, STERR) -> (${TMEAN}[ms], ${TVAR}, ${TSTDEV}, ${TSTERR})"
    echo "$Q   ${RX}   ${RY}   ${TMEAN}           ${TVAR}           ${TSTDEV}            ${TSTERR}" >> data/maxfps_res_Q${Q}_E${E}.dat
    #echo -n "$C   ${RX}   ${RY}   ${TMEAN} ${TVAR} ${TSTDEV} ${TSTERR}         " >> data/fps_res_C${C}_E${E}.dat
    echo " "
done 