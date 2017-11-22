#!/bin/sh
if [ "$#" -ne 5 ]; then
    echo "run as ./benchmark-ms-calidad.sh E STARTQ ENDQ DQ SAMPLES"
    exit;
fi
E=$1
STARTQ=$2
ENDQ=$3
DQ=$4
SAMPLES=$5
Rx=400
Ry=300
C=0
NOBJ=1
METHODS=("dummy" "BBox" "Avril" "Lambda (Newton)" "Lambda (Default)" "Flatrec" "Lambda (Inverse)" "Rectangle" "Recursive")
NM=8
for Q in `seq ${STARTQ} ${DQ} ${ENDQ}`;
do
    echo "Q=${Q} E=${E}  Rx=${Rx} Ry=${Ry} C=${C} NOBJ=${NOBJ}"
    M=0
    S=0
    #echo "./Renderer.exe ${Rx} ${}   ${N} ${R}    ${q} ${RPARAM}"
    for k in `seq 1 ${SAMPLES}`;
    do
        #x=`./${BINARY} ${DEV} ${N} ${R} ${q} ${RPARAM}`
        x=`./Renderer.exe ${Rx} ${Ry} ${E} ${Q} ${C} ${NOBJ}`
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
    echo "$Q   ${Rx}   ${Ry}   ${TMEAN}           ${TVAR}           ${TSTDEV}            ${TSTERR}" >> data/ms_calidad__E${E}.dat
    #echo -n "$C   ${RX}   ${RY}   ${TMEAN} ${TVAR} ${TSTDEV} ${TSTERR}         " >> data/fps_res_C${C}_E${E}.dat
    echo " "
done 
