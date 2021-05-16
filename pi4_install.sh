#!/bin/bash

# colours
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' #no colour

clear
printf "${YELLOW}Raspberry Pi 4 (aarch64) cardano node installer:\n"
printf "${CYAN}Visit PixelPool.io for support$NC\n"
printf "\n${YELLOW}I advise you to run this script in a tmux session: $NC\n"
printf "This is to ensure that if the ssh connection is lost your progress is not\n"
printf "\n\tTo start a new session\n"
printf "${CYAN}\ttmux new -s install_cardano ${NC}\n"
printf "\n\tTo exit press <CTRL>+b then after press d\n"
printf "\tTo reattach use (in case your connection drops)\n"
printf "${CYAN}\ttmux ls\n"
printf "\ttmux attach-session -t install_cardano\n$NC\n"

printf "\n${YELLOW}Continue: $NC\n"
while true; do
    read -p "Please type yes or no: " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

printf "${YELLOW}INSTALLING DEPENDENCIES${NC}\n"
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install git jq bc make automake rsync htop curl build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf -y
# Raspberry pi dependencies
sudo apt-get -y install libncurses-dev libtinfo5 llvm libnuma-dev -y #libsodium-dev

printf "${YELLOW}CREATING ~/git DIRECTORY${NC}\n"
mkdir $HOME/git
cd $HOME/git
printf "${YELLOW}INSTALLING LIBSODIUM${NC}\n"
git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

sudo ln -s /usr/local/lib/libsodium.so.23.3.0 /usr/lib/libsodium.so.23

printf "${YELLOW}GET CABAL${NC}\n"
# get cabal
mkdir -p ~/.local/bin
wget https://downloads.haskell.org/~cabal/cabal-install-3.4.0.0/cabal-install-3.4.0.0-aarch64-ubuntu-18.04.tar.xz
tar -xvf cabal-install-3.4.0.0-aarch64-ubuntu-18.04.tar.xz 
rm cabal-install-3.4.0.0-aarch64-ubuntu-18.04.tar.xz
mv cabal ~/.local/bin
#sudo rm /usr/bin/cabal
echo 'export PATH="~/.local/bin:$PATH"' >> .bashrc
source $HOME/.bashrc
	
# build ghc
printf "${YELLOW}GET AND BUILD GHC${NC}\n"
wget https://downloads.haskell.org/~ghc/8.10.4/ghc-8.10.4-aarch64-deb10-linux.tar.xz
tar -xvf ghc-8.10.4-aarch64-deb10-linux.tar.xz
rm ghc-8.10.4-aarch64-deb10-linux.tar.xz
cd ghc-8.10.4/
./configure
sudo make install
cp /usr/local/bin/ghc ~/.local/bin
#sudo rm -rf ghc-8.10.4


printf "${YELLOW}EXPORTING VARIABLES${NC}\n"
echo PATH="$HOME/.local/bin:$PATH" >> $HOME/.bashrc
echo export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" >> $HOME/.bashrc
echo export NODE_HOME=$HOME/cardano-node >> $HOME/.bashrc
#echo export NODE_CONFIG=$NETWORK_TYPE>> $HOME/.bashrc
echo export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g') >> $HOME/.bashrc
source $HOME/.bashrc


printf "${YELLOW}CHECKING CABAL AND GHC VERSIONS${NC}\n"
cabal update
cabal --version
ghc --version

# BUILD -------------------------------------------------------------
printf "${YELLOW}BUILD NODE - *NOTE THIS MAY TAKE HOURS ON A PI*$NC\n"
cd $HOME/git
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node
git fetch --all --recurse-submodules --tags
git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

cabal configure -O0 -w ghc-8.10.4

echo -e "package cardano-crypto-praos\n flags: -external-libsodium-vrf" > cabal.project.local
sed -i $HOME/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g"
rm -rf $HOME/git/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.4

cabal build cardano-cli cardano-node

sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli

sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node

printf "\n{$YELLOW}Cardano versions:\n$NC"
cardano-node version
cardano-cli version
printf "\n{$YELLOW}Done! Created by ${CYAN}[PIXEL]${YELLOW} pool.\n$NC"
printf "\n{$YELLOW}\nNow run configure.sh$NC"
# END BUILD ---------------------------------------------------------
