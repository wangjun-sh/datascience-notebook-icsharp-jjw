


ARG BASE_CONTAINER=jupyter/datascience-notebook
FROM $BASE_CONTAINER

USER root

#RUN echo "\nc.NotebookApp.ip = '127.0.0.1' " >> "/etc/jupyter/jupyter_notebook_config.py"
RUN echo "\nc.NotebookApp.token = '' " >> "/etc/jupyter/jupyter_notebook_config.py"
RUN echo "\nc.NotebookApp.password = '' " >> "/etc/jupyter/jupyter_notebook_config.py"


EXPOSE 8888

################################################################################


ENV MONO_VERSION 5.0.1.1

RUN apt-get update -y \
  && apt-get install -y \ 
  curl \
  git \
  gnupg \
  gnupg1 \
  gnupg2 \
  apt-utils \
  && rm -rf /var/lib/apt/lists/*

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
  && echo "deb http://download.mono-project.com/repo/debian jessie/snapshots/$MONO_VERSION main" > /etc/apt/sources.list.d/mono-official.list \
  && apt-get update -y\
  && apt-get install -y binutils mono-devel ca-certificates-mono fsharp mono-vbnc nuget referenceassemblies-pcl \
  && rm -rf /var/lib/apt/lists/* /tmp/*

RUN cert-sync /etc/ssl/certs/ca-certificates.crt \
  && yes | certmgr -ssl -m https://go.microsoft.com \
  && yes | certmgr -ssl -m https://nugetgallery.blob.core.windows.net \
  && yes | certmgr -ssl -m https://nuget.org

RUN mkdir /icsharp \
  && chown -R $NB_USER /icsharp
WORKDIR /icsharp

RUN chown -R $NB_USER $HOME/.config/

USER $NB_USER

RUN git clone --recursive https://github.com/zabirauf/icsharp.git /icsharp

# Tests not working. Problems with paths.
# Workaround.

# Build scriptcs
WORKDIR /icsharp/Engine
RUN mozroots --import --sync --quiet \
  && mono ./.nuget/NuGet.exe restore ./ScriptCs.sln \
  && mkdir -p artifacts/Release/bin

# Build iCSharp
WORKDIR /icsharp
RUN mozroots --import --sync --quiet \
  && mono ./.nuget/NuGet.exe restore ./iCSharp.sln \
  && mkdir -p build/Release/bin \
  && xbuild ./iCSharp.sln /property:Configuration=Release /nologo /verbosity:normal \
  # Copy files safely
  && for line in $(find ./*/bin/Release/*); do cp $line ./build/Release/bin; done  \

  && mono ./.nuget/NuGet.exe install Open-XML-SDK \
  && mono ./.nuget/NuGet.exe install DocumentFormat.OpenXml \
  && mono ./.nuget/NuGet.exe install iTextSharp 


# Install kernel
COPY kernel.json /icsharp/kernel-spec/kernel.json
RUN jupyter-kernelspec install --user kernel-spec

USER root

RUN chown -R root $HOME/.config/

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_USER


################################################################################

USER $NB_UID

