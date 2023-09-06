FROM ubuntu:22.10

RUN apt-get update && apt-get install -y \
    jq \
    curl \
    libicu-dev

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

RUN az bicep install

# install bicep
RUN curl -sLo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
    && chmod +x ./bicep \
    && mv ./bicep /usr/local/bin/bicep \
    && bicep --version

VOLUME [ "/data" ]
WORKDIR /data

CMD ["/bin/bash", "-c", "az login && bash"]
