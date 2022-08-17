FROM fedora:35

ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.utf8
ARG USER=nick
ARG PUID=1000
ARG PGID=1000

# From https://wiki.st.com/stm32mpu/wiki/PC_prerequisites
# From https://variwiki.com/index.php?title=Yocto_Build_Release&release=mx8x-yocto-hardknott-5.10.72_2.2.1-v1.0#Installing_required_packages
RUN dnf upgrade -y && dnf install -y \
    gawk \
    make \
    wget \
    tar \
    bzip2 \
    gzip \
    python3 \
    unzip \
    perl \
    patch \
    diffutils \
    diffstat \
    git \
    cpp \
    gcc \
    gcc-c++ \
    glibc-devel \
    texinfo \
    chrpath \
    ccache \
    perl-Data-Dumper \
    perl-Text-ParseWords \
    perl-Thread-Queue \
    perl-bignum \
    socat \
    python3-pexpect \
    findutils \
    which \
    file \
    cpio \
    python \
    python3-pip \
    xz \
    python3-GitPython \
    python3-jinja2 \
    SDL-devel \
    xterm \
    rpcgen \
    mesa-libGL-devel \
    perl-FindBin \
    perl-File-Compare \
    perl-File-Copy \
    perl-locale \
    zstd \
    lz4

# Set up locales
# RUN dnf install -y \
#     locales && \
#     locale-gen en_US.UTF-8 && \
#     update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 

# Aditional tools
RUN dnf install -y \
    sudo vim gdisk tree tmux zip zsh

# repo tool
RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+rx /usr/local/bin/repo

# User management
RUN groupadd -g ${PGID} ${USER} && \
    useradd -u ${PUID} -g ${PGID} -m ${USER} -s /usr/bin/zsh && \
    usermod -a -G wheel ${USER} && \
    usermod -a -G users ${USER}
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ${USER}

# install user dotfiles
RUN git clone https://github.com/code-maniac/dotfiles /home/${USER}/.dotfiles
WORKDIR /home/${USER}/.dotfiles
RUN ./install

WORKDIR /home/${USER}
