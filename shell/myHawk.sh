#!/bin/bash

set -e
set -u
set -o pipefail

#modified from NIKS script and HAWK script
#echo $PATH

## test whether the input is suitable for analysis
echo "Run this script under the root directory of your project"

if [ $# -lt 1 ] && [ $(wc -l $1) -lt 8 ]
then
  echo "You should provide a configure file including the follwing setting  "
  echo  "ctrDir=/scratch/atif/1000_genomes/BEB		#directory for control read files  "
  echo  "caseDir=/scratch/atif/1000_genomes/BEB		#directory for case read files  "
  echo  "hawkDir=/scratch/atif/hawk			#directory where hawk is installed  "
  echo  "jellyfishDir=/home/atif/jellyfish-Hawk/bin		#directory where jellyfish is installed  "
  echo  "abyssDir=/path/to/abyss/bin	#directory where abyss is installed  "
  echo  "sortDir=/path/to/parallelsort/bin		#directory where parallel sort is installed  "
  echo  "CORES=30 #number of cores to use for blast searches "
  echo  "KMERSIZE=31 # RD:61  "
exit 1
fi

config=$1
if [ ! -f ${config} ] && [ ! -r ${config} ]
then
	echo "$1 is not a file or is not readable  "
fi

# data , program, and options setting
wdDir=$(pwd)
ctrDir=$(awk 'BEGIN{FS="="}; $1~/ctrDir/ { print $2}' $config)
caseDir=$(awk 'BEGIN{FS="="}; $1~/caseDir/ { print $2}' $config)
hawkDir=$(awk 'BEGIN{FS="="}; $1~/hawkDir/ { print $2}' $config)
jellyfishDir=$(awk 'BEGIN{FS="="}; $1~/jellyfishDir/ { print $2}' $config)
sortDir=$(awk 'BEGIN{FS="="}; $1~/sortDir/ { print $2}' $config)
abyssDir=$(awk 'BEGIN{FS="="}; $1~/abyssDir/ { print $2}' $config)
CORES=$(awk 'BEGIN{FS="="}; $1~/CORES/ { print $2}' $config)
# kmer size should between 2,31
KMERSIZE=$(awk 'BEGIN{FS="="}; $1~/KMERSIZE/ { print $2}' $config)

# be aware of newline
# counting k-mers
for dir in ${ctrDir} ${caseDir}
do
    cd $dir
    OUTPREFIX=$(basename ${dir})
  	mkdir -p ${OUTPREFIX}_kmers
    # test if it is gzipped
    if [ $(ls $dir | grep -c gz ) -ge  1  ]
    then
      ${jellyfishDir}/jellyfish count -C -o ${OUTPREFIX}_kmers/tmp -m ${KMERSIZE} -t ${CORES} -s 2G <( zcat *.fq.gz )
    else
      ${jellyfishDir}/jellyfish count -C -o ${OUTPREFIX}_kmers/tmp -m ${KMERSIZE} -t ${CORES} -s 2G *fq
    fi

  	COUNT=$(ls ${OUTPREFIX}_kmers/tmp* |wc -l)
  # merge k-mers results
  	if [ $COUNT -eq 1 ]
  	then
   		mv ${OUTPREFIX}_kmers/tmp_0 ${OUTPREFIX}_kmers_jellyfish
  	else
  		${jellyfishDir}/jellyfish merge -o ${OUTPREFIX}_kmers_jellyfish ${OUTPREFIX}_kmers/tmp*
  	fi

  	rm -rf ${OUTPREFIX}_kmers
  	COUNT=$(ls ${OUTPREFIX}_kmers_jellyfish |wc -l)

  	if [ $COUNT -eq 1 ]
  	then
  		${jellyfishDir}/jellyfish histo -f -o ${OUTPREFIX}.kmers.hist.csv -t ${CORES} ${OUTPREFIX}_kmers_jellyfish
  		awk '{print $2"\t"$1}' ${OUTPREFIX}.kmers.hist.csv > ${OUTPREFIX}_tmp
  		mv ${OUTPREFIX}_tmp ${OUTPREFIX}.kmers.hist.csv
  		awk -f ${hawkDir}/countTotalKmer.awk ${OUTPREFIX}.kmers.hist.csv >> ${dir}/total_kmers.txt
  		CUTOFF=1
  		echo $CUTOFF > ${OUTPREFIX}_cutoff.csv
  		${jellyfishDir}/jellyfish dump -c -L `expr $CUTOFF + 1` ${OUTPREFIX}_kmers_jellyfish > ${OUTPREFIX}_kmers.txt
  		${sortDir}/sort --parallel=${CORES} -n -k 1 ${OUTPREFIX}_kmers.txt > ${OUTPREFIX}_kmers_sorted.txt
  		rm ${OUTPREFIX}_kmers_jellyfish
  		rm ${OUTPREFIX}_kmers.txt
  		echo "${dir}/${OUTPREFIX}_kmers_sorted.txt" >> ${dir}/sorted_files.txt
  	fi
done

## it will wirte sorted_files.txt total_kmers.txt under corresponding directory(ctrDir, caseDir)

cd $wdDir
# Finding significant k-mers
if [ ! -e case_out_sig.fasta ] && [ ! -e control_out_sig.fasta ]
then
  cp ${ctrDir}/sorted_files.txt ./control_sorted_files.txt
  cp ${ctrDir}/total_kmers.txt ./control_total_kmers.txt
  cp ${caseDir}/sorted_files.txt ./case_sorted_files.txt
  cp ${caseDir}/total_kmers.txt ./case_total_kmers.txt

  caseCount=$(cat case_sorted_files.txt | wc -l );
  controlCount=$(cat control_sorted_files.txt | wc -l);

  $hawkDir/hawk $caseCount $controlCount
  $hawkDir/bonf_fasta
fi

#Merging k-mers
file=case_out_sig.fasta
suffix=25_49
cutoff=49
${abyssDir}/ABYSS -k25 -c0 -e0 $file -o case_abyss.fa
awk '!/^>/ { next } { getline seq } length(seq) >= 49 { print $0 "\n" seq }' case_abyss.fa > case_abyss.$suffix.fa

file=control_out_sig.fasta
cutoff=49
${abyssDir}/ABYSS -k25 -c0 -e0 $file -o control_abyss.fa
awk '!/^>/ { next } { getline seq } length(seq) >= 49 { print $0 "\n" seq }' control_abyss.fa > control_abyss.$suffix.fa

#The k-mers with significant association to case and controls will be in 'case_out_sig.fasta' and 'control_out_sig.fasta'
#and the assembled sequences will be in 'case_abyss.25_49.fasta' and 'control_abyss.25_49.fasta' respectively.

# comemment out the follwing or modify for your purparse
blastn -db ../BLAST/TAIR10 -query case_abyss.25_49.fa -outfmt 6 -out case.txt
awk 'BEGIN{FS="\t"}  $3<100 && $4==$8 && $5==1 {print $2 "\t" $9 "\t" $10}' case.txt > case.bed

blastn -db ../BLAST/TAIR10 -query control_abyss.25_49.fa -outfmt 6 -out control.txt
awk 'BEGIN{FS="\t"}  $3<100 && $4==$8 && $5==1 {print $2 "\t" $9 "\t" $10}' control.txt > control.bed
