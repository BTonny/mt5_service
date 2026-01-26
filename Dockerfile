# Use Ubuntu 22.04 LTS - better Wine 64-bit support
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set Wine environment variables BEFORE any Wine operations
ENV WINEARCH=win64
ENV WINEPREFIX=/config/.wine
ENV DISPLAY=:0
ENV XDG_RUNTIME_DIR=/tmp/runtime-root
ENV WINEDEBUG=-all

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg2 \
    software-properties-common \
    python3 \
    python3-pip \
    dos2unix \
    netcat \
    xvfb \
    x11vnc \
    fluxbox \
    && rm -rf /var/lib/apt/lists/*

# Add i386 architecture for Wine dependencies
RUN dpkg --add-architecture i386

# Add WineHQ repository (Ubuntu 22.04)
# Note: apt-key is deprecated but still works reliably on Ubuntu 22.04
RUN wget -qO- https://dl.winehq.org/wine-builds/winehq.key | apt-key add - && \
    apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ jammy main'

# Install essential system libraries that Wine depends on (both 64-bit and 32-bit)
RUN apt-get update && apt-get install -y \
    libc6:i386 \
    libncurses5:i386 \
    libstdc++6:i386 \
    libgcc1:i386 \
    libc6 \
    libncurses5 \
    libstdc++6 \
    libgcc1 \
    libx11-6:i386 \
    libx11-6 \
    libxext6:i386 \
    libxext6 \
    libxrender1:i386 \
    libxrender1 \
    libfreetype6:i386 \
    libfreetype6 \
    libgl1-mesa-glx:i386 \
    libgl1-mesa-glx \
    libglu1-mesa:i386 \
    libglu1-mesa \
    libasound2:i386 \
    libasound2-plugins:i386 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Update package lists and install Wine with ALL dependencies
RUN apt-get update && \
    apt-get install -y --install-recommends --no-install-suggests \
        winehq-stable \
        wine-stable \
        wine-stable-amd64 \
        wine-stable-i386:i386 \
        libwine:i386 \
        libwine \
        fonts-wine \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify Wine installation and DLLs
RUN wine --version && \
    echo "Wine installed successfully" && \
    echo "Wine DLLs location check:" && \
    (find /usr -type d -name "wine" 2>/dev/null | head -5 || echo "Wine directories found") && \
    echo "Checking for kernel32.dll:" && \
    (find /usr -name "*kernel32*" -type f 2>/dev/null | head -3 || echo "kernel32 not found in standard locations") && \
    echo "Wine installation verification complete"
RUN mkdir -p /app /scripts /config /var/log && \
    chmod 755 /app /scripts /config /var/log

# Copy application files
COPY app /app
COPY scripts /scripts
COPY root /root

# Convert scripts to Unix format and make executable
RUN dos2unix /scripts/*.sh && \
    chmod +x /scripts/*.sh

# Create log file
RUN touch /var/log/mt5_setup.log && \
    chmod 644 /var/log/mt5_setup.log

# Expose ports
EXPOSE 3000 5000 5001 8001 18812

# Volume for Wine configuration
VOLUME /config

# Set working directory
WORKDIR /app

# Start script
CMD ["/scripts/01-start.sh"]
