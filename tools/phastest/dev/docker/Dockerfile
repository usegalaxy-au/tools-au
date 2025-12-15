FROM ubuntu:20.04

ARG GOSU_VERSION=1.11
ARG DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get update && \
  apt-get install -y \
    build-essential \
    locales

RUN apt-get install -y --no-install-recommends \
  wget \
  bzip2 \
  perl \
  gcc \
  git \
  gnupg \
  make \
  munge \
  curl \
  tar \
  python3 \
  python3-pip \
  libpam0g-dev \
  psmisc \
  bash-completion \
  net-tools \
  iputils-ping \
  ssh \
  openssh-server \
  openssh-client \
  cpanminus

# Create symlink for python
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -s /usr/bin/python3 /usr/bin/python2

# Install libraries that BioPerl dependencies depend on
RUN apt-get install --yes \
  libdb-dev \
  zlib1g-dev \
  graphviz

# Install perl modules
RUN cpanm --notest \
    CPAN::Meta \
    YAML \
    Digest::SHA \
    Module::Build \
    Test::Most \
    Test::Weaken \
    Test::Memory::Cycle \
    Clone

# Install perl modules for network and SSL (and their dependencies)
RUN apt-get install --yes \
  openssl \
  libssl-dev

RUN cpanm --notest \
  IO::Socket::INET6 \
  LWP \
  LWP::Protocol::https

# Install packages for XML processing
RUN apt-get install --yes \
  expat \
  libexpat-dev \
  libxml2-dev \
  libxslt1-dev \
  libgdbm-dev

RUN cpanm --notest \
  XML::Parser \
  XML::Parser::PerlSAX \
  XML::DOM \
  XML::DOM::XPath \
  XML::SAX \
  XML::SAX::Writer \
  XML::Simple \
  XML::Twig \
  XML::Writer \
  XML::LibXML

# Install what counts as BioPerl dependencies
RUN cpanm --notest \
  HTML::TableExtract \
  Algorithm::Munkres \
  Array::Compare \
  Convert::Binary::C \
  Error \
  Graph \
  GraphViz \
  Inline::C \
  PostScript::TextBlock \
  Set::Scalar \
  Sort::Naturally \
  Math::Random \
  Spreadsheet::ParseExcel \
  IO::String \
  JSON \
  Data::Stag

RUN cpanm --notest \
  Bio::DB::GenBank \
  Bio::Perl \
  Mail::Sendmail \
  JSON::XS \
  LWP::Simple

# Install database connectivity packages
RUN apt-get install --yes \
  libdbi-perl \
  libdbd-mysql-perl \
  libdbd-pg-perl \
  libdbd-sqlite3-perl

RUN cpanm --notest \
  DB_File

# Install GD and other graphics dependencies
RUN apt-get install --yes \
  libgd-dev

RUN cpanm --notest \
  GD \
  SVG \
  SVG::Graph

# Install BLAST+
RUN wget -q https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.13.0/ncbi-blast-2.13.0+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-2.13.0+-x64-linux.tar.gz -C /usr/local/ && \
    ln -s /usr/local/ncbi-blast-2.13.0+ /BLAST+ && \
    ln -s /usr/local/ncbi-blast-2.13.0+/bin/* /usr/local/bin/ && \
    rm -f ncbi-blast-2.13.0+-x64-linux.tar.gz

# Install additional bioinformatics tools
RUN apt-get install -y \
    hmmer \
    diamond-aligner \
    barrnap

# Set PHASTEST environment
ENV PHASTEST_HOME="/root/phastest-app"
ENV PHASTEST_CLUSTER_HOME="/root/phastest-app"
ENV PHASTEST_CLUSTER_HOST="root@127.0.0.1"
ENV PHASTEST_CLUSTER_HOSTNAME="127.0.0.1"
ENV PHASTEST_CLUSTER_USERNAME="root"
ENV PATH="$PATH":"${PHASTEST_HOME}/sub_programs":"${PHASTEST_HOME}/sub_programs/tRNAscan-SE-1.23":"${PHASTEST_HOME}/sub_programs/tRNAscan-SE-1.23/bin":"${PHASTEST_HOME}/sub_programs/FragGeneScan1.20":"${PHASTEST_HOME}/sub_programs/Prodigal-2.6.3":"${PHASTEST_HOME}/bin"

# Create directory structure
RUN mkdir -p /root/phastest-app

# Copy entire PHASTEST application
COPY ./phastest-app-docker/helpers /root/phastest-app/helpers
COPY ./phastest-app-docker/lib /root/phastest-app/lib
COPY ./phastest-app-docker/scripts /root/phastest-app/scripts
COPY ./phastest-app-docker/sub_programs /root/phastest-app/sub_programs

# Create symlink for the path expected by phastest.sh
RUN ln -s /root/phastest-app /phastest-app

# Set up PHASTEST sub-programs
# Build tRNAscan-SE
RUN set -x \
    && cd /root/phastest-app/sub_programs/tRNAscan-SE-1.23 \
    && make \
    && make install \
    && make testrun \
    && make clean \
    && cd /

# Build FragGeneScan if present
RUN set -x \
    && if [ -d "/root/phastest-app/sub_programs/FragGeneScan1.20" ]; then \
        cd /root/phastest-app/sub_programs/FragGeneScan1.20 \
        && make \
        && cd /; \
    fi

# Build Prodigal if present
RUN set -x \
    && if [ -d "/root/phastest-app/sub_programs/Prodigal-2.6.3" ]; then \
        cd /root/phastest-app/sub_programs/Prodigal-2.6.3 \
        && make \
        && cd /; \
    fi

# Setup PHASTEST databases
# Will be skipped if DBs are not baked into image
RUN set -x \
    && if [ -f "/root/phastest-app/DB/prophage_virus.db" ]; then \
        makeblastdb -in /root/phastest-app/DB/prophage_virus.db -dbtype prot; \
    fi \
    && if [ -f "/root/phastest-app/DB/bacteria_all_select.db" ]; then \
        makeblastdb -in /root/phastest-app/DB/bacteria_all_select.db -dbtype prot; \
    fi \
    && if [ -f "/root/phastest-app/DB/swissprot.db" ]; then \
        makeblastdb -in /root/phastest-app/DB/swissprot.db -dbtype prot; \
    fi \
    && if [ -f "/root/phastest-app/DB/bacteria_all_select.db" ]; then \
        diamond makedb --in /root/phastest-app/DB/bacteria_all_select.db -d /root/phastest-app/DB/bacteria_all_select.dmnd; \
    fi \
    && if [ -f "/root/phastest-app/DB/swissprot.db" ]; then \
        diamond makedb --in /root/phastest-app/DB/swissprot.db -d /root/phastest-app/DB/swissprot.dmnd; \
    fi

# Set proper permissions
RUN chmod -R +x /root/phastest-app/scripts/ && \
    chmod -R +x /root/phastest-app/sub_programs/

# Create necessary directories
RUN mkdir -p /root/phastest-app/log

# Copy over the phastest entrypoint
COPY ./phastest.sh /usr/bin/phastest
RUN chmod +x /usr/bin/phastest

WORKDIR /root/phastest-app

ENTRYPOINT ["/usr/bin/phastest"]
