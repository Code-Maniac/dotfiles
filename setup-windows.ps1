<<<<<<< HEAD
echo "Install chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

echo "Install Nerd Fonts (Droid Sans Mono)"
curl.exe -A "MS" https://webinstall.dev/nerdfont

echo "Install Apps"
$apps = 
    "microsoft-windows-terminal",
    "rust",
    "python3",
    "conan",
    "cmake",
    "git",
    "git-lfs",
    "gimp",
    "jetbrainstoolbox",
    "google-chrome",
    "7zip",
    "autoruns"

foreach ($app in $apps) {
    echo "Install $app"
    choco install -y $app
}

echo "Install oh-my-posh"
winget install XP8K0HKJFRXGCK

echo "Install additional folder/file icons"
Install-Module -Name Terminal-Icons -Repository PSGallery

echo "Install WSL Ubuntu (BIOS Hardware Virtualisation must be enabled)"
wsl --install -d Ubuntu

echo "Copy Window Terminal settings to AppData Local"
cp ./winterm/settings.json $env:LOCALAPPDATA/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json

echo "Copy powershell profile"
cp ./powershell/Microsoft.PowerShell_profile.ps1 $PROFILE

echo "Copy .ideavimrc"
cp ./vim/ideavimrc $env:USERPROFILE/.ideavimrc

echo "All finished"
