#!/bin/bash
# version 1.1
# function:  provide different function to align and vairant calling
# author: xuzhougeng, xuzhougeng@163.com

set -e
set -u
set -o pipefail

PATH=/home/wangjw/miniconda3/bin:/usr/local/bin:/usr/bin:/bin

# /public1/wangjw/linzhi_20170715/Data/PD/FCH2LCHCCXY_L7_wHAXPI051602-43
samplePath=$1
index=/public1/wangjw/linzhi_20170715/chiIndex/hirsuta.fa


mkdir -p /public1/wangjw/linzhi_20170715/alignment
alignDir=/public1/wangjw/linzhi_20170715/alignment

# alignment
for sample in `cat samplePath`
do
    filename=${sample##*/}
    bwa mem -t 8 -B 2 $index ${sample} ${sample}_1.fq.gz ${sample}_2.fq.gz >\
     alignDir/${filename}.sam 2>  alignDir/${filename}.log
done

# convert sort and index

for sample in `cat samplePath`
do
  output=${sample##*/}
  samtools view -b -o alignDir/${output}.bam alignDir/${filename}.sam
  samtools sort -o alignDir/${output}.sorted.bam alignDir/${output}.bam
  samtools index alignDir/${output}.sorted.bam
done
