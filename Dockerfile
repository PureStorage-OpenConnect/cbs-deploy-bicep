FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    jq \
    curl \
    libicu-dev

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# upgrade az cli
RUN az upgrade --yes --all

# enable az auto-upgrade
RUN az config set auto-upgrade.enable=yes

RUN az bicep install

# install bicep
RUN curl -sLo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
    && chmod +x ./bicep \
    && mv ./bicep /usr/local/bin/bicep \
    && bicep --version

ENV PURE_RUN_IN_DOCKERIMAGE=1

VOLUME [ "/data" ]
WORKDIR /data

CMD ["/bin/bash", "-c", "az login && bash"]
