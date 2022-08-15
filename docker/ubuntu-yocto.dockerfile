FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.utf8
ARG USER=nick
ARG PUID=1000
ARG PGID=1000

# From https://wiki.st.com/stm32mpu/wiki/PC_prerequisites
# From https://variwiki.com/index.php?title=Yocto_Build_Release&release=mx8x-yocto-hardknott-5.10.72_2.2.1-v1.0#Installing_required_packages

RUN apt-get update && apt-get install -y \
    asciidoc \
    autoconf \
    automake \
    bc \
    bison \
    bsdmainutils \
    build-essential \
    chrpath \
    coreutils \
    corkscrew \
    cpio \
    curl \
    cvs \
    debianutils \
    desktop-file-utils \
    device-tree-compiler \
    diffstat \
    docbook-utils \
    dos2unix \
    flex \
    g++ \
    g++-multilib \
    gawk \
    gcc \
    gcc-multilib \
    git-core \
    git-lfs \
    groff \
    help2man \
    iputils-ping \
    libarchive-dev \
    libarchive-zip-perl \
    libegl1-mesa \
    libelf-dev \
    libgl1-mesa-dev \
    libglib2.0-dev \
    libglu1-mesa-dev \
    libgmp-dev \
    libmpc-dev \
    libncurses5 \
    libncurses5-dev \
    libncursesw5-dev \
    libsdl1.2-dev \
    libssl-dev \
    libtool \
    libxml2-utils \
    libyaml-dev \
    linux-headers-generic \
    lrzsz \
    lzop \
    make \
    mercurial \
    mtd-utils \
    nfs-common \
    nfs-kernel-server \
    pv \
    pylint3 \
    python-pysqlite2 \
    python3 \
    python3-git \
    python3-jinja2 \
    python3-pexpect \
    python3-pip \
    rename \
    sed \
    socat \
    subversion \
    texi2html \
    texinfo \
    u-boot-tools \
    unzip \
    wget \
    xterm \
    xz-utils \
    zlib1g-dev 

# Set up locales
RUN apt-get install -y \
    locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 

# Aditional tools
RUN apt-get install -y \
    sudo vim gdisk tree tmux zip

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# fix python <-> python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 3

# repo tool
RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+rx /usr/local/bin/repo

# User management
RUN groupadd -g ${PGID} ${USER} && \
    useradd -u ${PUID} -g ${PGID} -m ${USER} -s /usr/bin/zsh && \
    usermod -a -G sudo ${USER} && \
    usermod -a -G users ${USER}
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ${USER}

# install user dotfiles
RUN git clone https://github.com/code-maniac/dotfiles /home/${USER}/.dotfiles
WORKDIR /home/${USER}/.dotfiles
RUN ./install
