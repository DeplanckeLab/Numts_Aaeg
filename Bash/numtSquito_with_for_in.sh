#!/bin/bash

### run the for loop based on this script to generate the numts and breakpoints of the Mosquito.
### based on the https://github.com/WeiWei060512/NUMTs-detection pipeline


pblat="/data/botos/2022_12_01_NUMTS_Aedes_Aegypti/Software/icebert-pblat-c744fdf/./pblat"

inputFiles="/home/botos/SVRAW1/gardeux/2021_06_01_WGS_Aedes_Aegypti/bam"
files=($(ls -1 $inputFiles/*_F[0-9][0-9].bam | sort -V))

for i in ${files[@]};
	do
		echo "--- Processing sample  $(basename $i .bam) ---"
		INPUT_BAM=$i 
		FILE_in=($(basename $i .bam))

		mkdir -p $PWD/NUMTS_OUTPUT_$FILE_in
		OUTPUT_DIR="$PWD/NUMTS_OUTPUT_$FILE_in"
		echo -e "OUTPUT will be stored in $OUTPUT_DIR"
		REF_Genome="/data/botos/2022_12_01_NUMTS_Aedes_Aegypti/Aedes_aegypti/FASTA/Aedes_aegypti_lvpagwg.AaegL5.51.fa"
	
		CLUSTER_SCRIPT="/data/botos/2022_12_01_NUMTS_Aedes_Aegypti/NUMTs-detection_pipeline_used/scripts/searchNumtCluster_fromDiscordantReads.py"
		BREAKPOINT_SCRIPT="/data/botos/2022_12_01_NUMTS_Aedes_Aegypti/NUMTs-detection_pipeline_used/scripts/searchBreakpoint_fromblatoutputs.py"

		SAMPLE_ID1="${INPUT_BAM##*/}"
		SAMPLE_ID2="${SAMPLE_ID1%.bam}"
		echo -e "Working on sample $SAMPLE_ID2"
		OUTPUT="${OUTPUT_DIR}/${SAMPLE_ID2}"

		INPUT_DISC="${OUTPUT}.mt.disc.sam"
		INPUT_SPLIT="${OUTPUT}.mt.split.sam"
	

		echo "Running first samtools"
		samtools view -@ 24 -m 10G -h -F 2  $INPUT_BAM | grep -e @ -e MT -e chrM | samtools sort -@ 24 -m 10G -n  | samtools view -h |  samblaster --ignoreUnmated -e -d $INPUT_DISC -s $INPUT_SPLIT -o /data/botos/2022_12_01_NUMTS_Aedes_Aegypti/null_${FILE_in}

		echo "First samtools done"
		python3 $CLUSTER_SCRIPT ${SAMPLE_ID2} ${INPUT_BAM} ${INPUT_DISC}

		echo "look for cluster's done, move to look for breakpoints"

		while read line;
	       	do
			echo $line
			INPUT_Dis="$(echo $line | cut -d " " -f3)"
			echo "input dis is: $INPUT_Dis"
			INPUT_Split="$(echo $line | cut -d " " -f4)"
			echo "input_split is: $INPUT_Split "
			INPUT_WGS="$(echo $line | cut -d " " -f5)"
			echo "input_wgs is: $INPUT_WGS"
			CHR="$(echo $line | cut -d " " -f6)"
			echo "chr is: $CHR"
			START="$(echo $line | cut -d " " -f7)"
			echo "start is: $START"
			END="$(echo $line | cut -d " " -f8)"
			echo "end is: $END"
			sampleID="$(echo $line | cut -d " " -f1)"
			echo "sampleID is: $sampleID"
			REGION="${CHR}:${START}-${END}"
			echo "region is: $REGION"
			OUTPUT="${OUTPUT_DIR}/${sampleID}_${CHR}.${START}.${END}"
			echo "output is: $OUTPUT"
	
			echo -e "running samtools 1"
			samtools view ${INPUT_WGS} ${REGION} >${OUTPUT}.sam
			echo -e "samtools 2 done"
			
			echo -e "running awk"
			awk '$6 !~ /150M|149M|148M|149S|148S/' ${OUTPUT}.sam | cut -f1,10 >${OUTPUT}.fasta
			echo -e "awk done"
			
			echo -e "running perl"
			perl -pi -e 's/^/>/g' ${OUTPUT}.fasta
			echo -e "perl 1 done"
	
			perl -pi -e 's/\t/\n/g' ${OUTPUT}.fasta
			echo -e "perl 2 done"
		
			echo -e "running blat script"
			#Downloaded pblat and testing it with 24 cores rather than solo blat...
			#http://icebert.github.io/pblat/
			$pblat -threads=24 ${REF_Genome} ${OUTPUT}.fasta ${OUTPUT}.psl
			echo -e "blat done"
			
			echo -e "running breakpoint script"
			python3 ${BREAKPOINT_SCRIPT} ${OUTPUT}.psl ${sampleID} ${CHR} ${START} ${END} ${OUTPUT}
			echo -e "breakpoints script done"
			
			rm ${OUTPUT}.fasta
			rm ${OUTPUT}.sam

		done < ${INPUT_DISC}.breakpointINPUT.tsv
		echo -e "Done with sample $FILE_in"
		
done
