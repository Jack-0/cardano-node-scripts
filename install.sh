#!/bin/bash

# colours
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' #no colour

# install options
NETWORK_TYPE="mainnet"
PI=0

# GET USER OPTIONS---------------------------------------------------
clear
printf "\n$YELLOW Network type:\n$CYAN"
printf "\t1) Mainnet\n"
printf "\t2) Testnet\n$NC"

read n
case $n in
  1) NETWORK_TYPE="mainnet";;
  2) NETWORK_TYPE="testnet";;
  *) printf "$RED Invalid option... Quiting\n $NC"
	  exit;;
esac

printf "\n$YELLOW Is this running on a Raspberry Pi 4 (aarch64): $NC\n"

while true; do
    read -p "Please type yes or no: " yn
    case $yn in
        [Yy]* ) PI=1; 
		break;;
        [Nn]* ) PI=0;
		break;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "var = $PI"

printf "\n$YELLOW Options selected: $NC\n"
printf "\nNetwork =$CYAN $NETWORK_TYPE $NC\n"
printf "\n $YELLOW Continue? $NC\n"

while true; do
    read -p "Please type yes or no: " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
# END GET USER OPTIONS-----------------------------------------------

# INSTALL CABAL AND GHC
printf "$YELLOW INSTALLING CABAL AND GHC $NC\n"

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install git jq bc make automake rsync htop curl build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf -y

mkdir $HOME/git
cd $HOME/git
git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

sudo ln -s /usr/local/lib/libsodium.so.23.3.0 /usr/lib/libsodium.so.23

sudo apt-get -y install pkg-config libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev build-essential curl libgmp-dev libffi-dev libncurses-dev libtinfo5



# IF AARCH get build otherwise build from source
if [ $PI=1 ]; then
	# USER IS USING AARCH64
	
	# get cabal
	mkdir -p ~/.local/bin
	wget https://downloads.haskell.org/~cabal/cabal-install-3.4.0.0/cabal-install-3.4.0.0-aarch64-ubuntu-18.04.tar.xz
	tar -xvf cabal-install-3.4.0.0-aarch64-ubuntu-18.04.tar.xz 
	rm cabal-install-3.4.0.0-aarch64-ubuntu-18.04.tar.xz
	mv cabal ~/.local/bin
	sudo rm /usr/bin/cabal
	echo 'export PATH="~/.local/bin:$PATH"' >> .bashrc
	source $HOME/.bashrc
	
	# build ghc
	wget https://downloads.haskell.org/~ghc/8.10.4/ghc-8.10.4-aarch64-deb10-linux.tar.xz
	tar -xvf ghc-8.10.4-aarch64-deb10-linux.tar.xz
	rm ghc-8.10.4-aarch64-deb10-linux.tar.xz
	cd ghc-8.10.4/
	./configure
	sudo make install
	cp /usr/local/bin/ghc ~/.local/bin
	source $HOME/.bashrc
	sudo rm -rf ghc-8.10.4

	sudo apt-get install llvm libsodium-dev -y
	
else
	# USER IS NOT USING AARCH64
	printf "$YELLOW When prompted to answser:\n"
	printf "$CYAN \tNO $NC to installing haskell-language-server (HLS)\n" 
	printf "$CYAN \tYES $NC to automatically add the required PATH variable to .bashrc\n"
	read -n 1 -s -r -p "Press any key to continue"
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
	
	cd $HOME
	source .bashrc

	ghcup upgrade
	ghcup install cabal 3.4.0.0
	ghcup set cabal 3.4.0.0

	ghcup install ghc 8.10.4
	ghcup set ghc 8.10.4
fi


# PATHS
echo PATH="$HOME/.local/bin:$PATH" >> $HOME/.bashrc
echo export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" >> $HOME/.bashrc
echo export NODE_HOME=$HOME/cardano-node >> $HOME/.bashrc
echo export NODE_CONFIG=$NETWORK_TYPE>> $HOME/.bashrc
echo export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g') >> $HOME/.bashrc
source $HOME/.bashrc


cabal update
cabal --version
ghc --version

# BUILD -------------------------------------------------------------
printf "$YELLOW BUILD NODE $NC\n"
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

cardano-node version
cardano-cli version
# END BUILD ---------------------------------------------------------
