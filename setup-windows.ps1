echo "Install chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

echo "Install Nerd Fonts (Droid Sans Mono)"
curl.exe -A "MS" https://webinstall.dev/nerdfont

echo "Install Window Terminal"
choco install microsoft-windows-terminal

echo "Install WSL Ubuntu (BIOS Hardware Virtualisation must be enabled)"
wsl --install -d Ubuntu

echo "All finished"