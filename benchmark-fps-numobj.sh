#!/bin/sh
if [ "$#" -ne 5 ]; then
    echo "run as ./benchmark-fps-numobj.sh STARTN ENDN DN Q SAMPLES"
    exit;
fi
E=4
STARTN=$1
ENDN=$2
DN=$3
Q=$4
SAMPLES=$5
Rx=800
Ry=600
C=0
METHODS=("dummy" "BBox" "Avril" "Lambda (Newton)" "Lambda (Default)" "Flatrec" "Lambda (Inverse)" "Rectangle" "Recursive")
NM=8
for N in `seq ${STARTN} ${DN} ${ENDN}`;
do
    M=0
    S=0
    NOBJ=$(($N*$N))
    echo "Q=${Q} E=${E}  Rx=${Rx} Ry=${Ry} C=${C} NOBJ=${NOBJ}"
    #echo "Rx=${RX} Ry=${RY}"
    #echo "./Renderer.exe ${Rx} ${}   ${N} ${R}    ${q} ${RPARAM}"
    for k in `seq 1 ${SAMPLES}`;
    do
        #x=`./${BINARY} ${DEV} ${N} ${R} ${q} ${RPARAM}`
        x=`./Renderer.exe ${Rx} ${Ry} ${E} ${Q} ${C} ${N}`
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
    echo "${NOBJ}   ${Rx}   ${Ry}   ${TMEAN}           ${TVAR}           ${TSTDEV}            ${TSTERR}" >> data/fps_nobj_E${E}.dat
    #echo -n "$C   ${RX}   ${RY}   ${TMEAN} ${TVAR} ${TSTDEV} ${TSTERR}         " >> data/fps_res_C${C}_E${E}.dat
    echo " "
done 