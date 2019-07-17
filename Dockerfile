FROM ubuntu:18.04

WORKDIR /nanopore

RUN apt-get update
RUN apt-get -y install curl git build-essential default-jre default-jdk python3-minimal python3-pip

RUN git clone https://github.com/ncbi/ngs.git; \
    git clone https://github.com/ncbi/ncbi-vdb.git; \
    git clone https://github.com/ncbi/sra-tools.git

RUN cd /nanopore/ngs; ./configure; make; make install; \
    cd /nanopore/ncbi-vdb; ./configure; make; make install; \
    cd /nanopore/sra-tools; ./configure; make; make install

RUN ln -s /root/ncbi-outdir/sra-tools/linux/gcc/x86_64/rel/bin/fasterq-dump /usr/local/bin

RUN pip3 install NanoPlot nanofilt nanoQC

RUN mkdir /nanopore/minimap2; \
    cd /nanopore/minimap2; \
    curl -L https://github.com/lh3/minimap2/releases/download/v2.17/minimap2-2.17_x64-linux.tar.bz2 | tar -jxvf -; \
    ln -s /nanopore/minimap2/minimap2-2.17_x64-linux/minimap2 /usr/local/bin

VOLUME [ "/data" ]

# TODO:
#   По Sample Accession получать из SRA список ранов
#   и скачивать их при помощи fasterq-dump