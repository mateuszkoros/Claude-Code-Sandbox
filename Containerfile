FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    nodejs \
    npm \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create workspace directory
WORKDIR /workspace

# Set proxy environment variables
ENV HTTP_PROXY=http://squid-proxy:3128
ENV HTTPS_PROXY=http://squid-proxy:3128
ENV http_proxy=http://squid-proxy:3128
ENV https_proxy=http://squid-proxy:3128

# Add Claude location to path
ENV PATH="${PATH}:/root/.local/bin"

# Custom Shell prompt just for fun
RUN echo 'export PS1="\\[\\033[0;31m\\]\\342\\224\\214\\342\\224\\200[\\[\\033[0;39m\\]\\u\\[\\033[01;33m\\]@\\[\\033[01;96m\\]\\h\\[\\033[0;31m\\]]\\342\\224\\200[\\[\\033[0m\\]\\[\\e[01;33m\\]\\D{%F %T}\\[\\033[0;31m\\]]\\342\\224\\200[\\[\\033[0;32m\\]\\w\\[\\033[0;31m\\]]\\n\\[\\033[0;31m\\]\\342\\224\\224\\342\\224\\200\\342\\224\\200\\342\\225\\274 \\[\\033[0m\\]\\[\\e[01;33m\\]\\\\$\\[\\e[0m\\]"' >> /root/.bashrc

# Keep container running
CMD ["bash"]
