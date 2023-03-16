#!/bin/bash

inputFiles="/home/botos/SVRAW1/gardeux/2021_06_01_WGS_Aedes_Aegypti/bam"
files=($(ls -1 $inputFiles/*_F[0-9][0-9].bam | sort -V))





for i in ${files[@]};
do
	session_name="$(basename $i .bam | tr -cs '[:alnum:]_-' '_')"
	echo "--- Processing sample  ${session_name} ---"
	tmux new-session -s "$session_name " -d "sh numtSquito_with_input.sh ${i}"
done
