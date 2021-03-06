#!/bin/bash
set -e 
set -u
set -o pipefail

ENV=$1
# download miniconda and install
URL=https://nanomirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-$(uname -m).sh
PREFIX=$HOME/miniconda3

if [ ! -d $PREFIX ]
then
    wget -4 $URL && bash $(basename $URL) -b -p $PREFIX && \
    echo "successful installation" && \
    echo "export PATH=$PREFIX/bin:"'$PATH' >> ~/.bashrc
fi

if [ ! -f biosteup.yml ]
then
    wget --no-check-certificate \
        https://raw.github.com/xuzhougeng/zgtoolkits/master/biosetup.yml
fi

if [ $ENV ]
then
    $HOME/miniconda3/bin/conda env create  -f=biosetup.yml -p $ENV
else
    echo "software install path is unset"
    exit 0
fi
	