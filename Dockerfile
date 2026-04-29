FROM python:3.12-slim

# --- Wine + PowerShell for Windows ---
ENV DEBIAN_FRONTEND=noninteractive
ENV WINEDEBUG=-all
ENV WINEPREFIX=/root/.wine
ENV WINEARCH=win64
ENV DISPLAY=:99
ENV PS_VERSION=7.4.6

# i386 architecture + wine + xvfb + unzip
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        wine \
        wine64 \
        wine32:i386 \
        xvfb \
        x11-utils \
        wget \
        unzip \
        zip \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Initialise Wine prefix, install wine-mono (.NET Framework support for KAPE/EZParser tools)
# and PowerShell 7 (real binary, replaces wine-mono's stub powershell.exe)
RUN Xvfb :99 -screen 0 1024x768x16 & \
       sleep 2 \
    && wineboot --init \
    && wineserver --wait \
    && wget -q https://dl.winehq.org/wine/wine-mono/9.4.0/wine-mono-9.4.0-x86.msi -O /tmp/wine-mono.msi \
    && wine msiexec /i /tmp/wine-mono.msi \
    && wineserver --wait \
    && rm /tmp/wine-mono.msi \
    && wget -q "https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/PowerShell-${PS_VERSION}-win-x64.zip" \
         -O /tmp/pwsh.zip \
    && mkdir -p "$WINEPREFIX/drive_c/pwsh" \
    && unzip -q /tmp/pwsh.zip -d "$WINEPREFIX/drive_c/pwsh" \
    && chmod +x "$WINEPREFIX/drive_c/pwsh/"*.exe \
    && rm /tmp/pwsh.zip \
    && kill %1 || true \
    && rm -f /tmp/.X99-lock /tmp/.X99-unix

# Wrapper script
RUN printf '#!/bin/bash\nexec wine "%s/drive_c/pwsh/pwsh.exe" "$@"\n' "$WINEPREFIX" \
        > /usr/local/bin/powershell \
    && chmod +x /usr/local/bin/powershell

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

CMD ["bash", "-c", "Xvfb :99 -screen 0 1024x768x16 & exec python app.py"]
