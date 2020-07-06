#!/bin/sh
set -e

add_key () {
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "$@"
}

add_repo () {
  FILE=$1
  shift
  sudo sh -c "echo \"$@\" > /etc/apt/sources.list.d/$FILE"
}

add_deb () {
  FILE=/tmp/`cat /dev/urandom | tr -dc '0-9A-F' | fold -w 16 | head -n 1`.deb
  sudo wget --output-document $FILE $1
  sudo apt install -y $FILE
  sudo rm $FILE
}

# Use a function in case only part of the script is downloaded
setup () {
  COLOR_RED=`echo "\e[31m"`
  COLOR_GREEN=`echo "\e[32m"`
  COLOR_BURNT=`echo "\e[38;2;191;87;0m"`
  COLOR_RESET=`echo "\e[0m"`
  COLOR_BOLD=`echo "\e[1m"`
  if sudo test `lsb_release -sc` != bionic
    then echo $COLOR_RED$COLOR_BOLD"ERROR: Texas RoboCamp 2020 is only compatible with Ubuntu 18.04."$COLOR_RESET
    echo $COLOR_RED"You are using version `lsb_release -sr`."$COLOR_RESET
    exit 1
  fi

  # Add repositories
  sudo add-apt-repository universe
  # ROS
  add_key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
  add_repo ros-latest.list "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main"
  # Gazebo
  add_key D2486D2DD83DB69272AFE98867170598AF249743
  add_repo gazebo-stable.list "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -sc) main"
  # VS Code
  add_key BC528686B50D79E339D3721CEB3E94ADBE1229CF
  add_repo vscode.list "deb [arch=amd64] http://packages.microsoft.com/repos/vscode stable main"
  # Our repository
  add_key 4F96EF95D295866724CAEEDA0540E766C789458D
  add_repo robocamp.list "deb [arch=amd64] https://texas-robocamp.github.io/packages-virtual $(lsb_release -sc) main"

  sudo apt update
  sudo apt install -y ros-melodic-texas-robocamp-full

  add_deb https://zoom.us/client/latest/zoom_amd64.deb

  echo $COLOR_GREEN$COLOR_BOLD"Finished installing packages for Texas RoboCamp 2020."$COLOR_RESET
}

setup
