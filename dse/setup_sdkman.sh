#!/bin/bash

umask 0022

if [ ! -f $HOME/.bash_profile ]; then

    cat << EOF > $HOME/.bash_profile
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi
EOF

fi

touch $HOME/.bashrc

curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install maven 3.3.9
sdk install gradle 4.10.3
sdk install sbt 0.13.18

