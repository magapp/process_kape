FROM python:3.12-slim

# --- Wine + PowerShell for Windows ---
ENV DEBIAN_FRONTEND=noninteractive
ENV WINEDEBUG=-all
ENV WINEPREFIX=/root/.wine
ENV PS_VERSION=7.4.6

# i386 architecture + wine + unzip
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        wine \
        wine32:i386 \
        wget \
        unzip \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# wine-mono (needed for .NET support)
RUN wget -q https://dl.winehq.org/wine/wine-mono/11.0.0/wine-mono-11.0.0-x86.msi -O /tmp/wine-mono.msi \
    && wine msiexec /i /tmp/wine-mono.msi \
    && rm /tmp/wine-mono.msi

# Install PowerShell for Windows directly into the wine prefix
RUN wget -q "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/PowerShell-${PS_VERSION}-win-x86.zip" \
        -O /tmp/pwsh.zip \
    && mkdir -p "$WINEPREFIX/drive_c/pwsh" \
    && unzip -q /tmp/pwsh.zip -d "$WINEPREFIX/drive_c/pwsh" \
    && rm /tmp/pwsh.zip

# Create a shell wrapper so "powershell" works as a normal command
RUN printf '#!/bin/bash\nexec wine %s/drive_c/pwsh/pwsh.exe "$@"\n' "$WINEPREFIX" \
        > /usr/local/bin/powershell \
    && chmod +x /usr/local/bin/powershell

# Warm up the wine prefix so first run isn't slow
RUN powershell -noni -c 'echo "done"'

# --- Flask app ---
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY bin/requirements.txt /app/bin/requirements.txt
RUN python -m venv /app/bin/env \
    && /app/bin/env/bin/pip install --no-cache-dir -r /app/bin/requirements.txt

COPY . .

RUN mkdir -p downloaded result temporary_processing \
    && chmod +x /app/bin/build_timeline.py /app/bin/build_ip_lists.py /app/bin/merge_csv.py

EXPOSE 5000

CMD ["python", "app.py"]
