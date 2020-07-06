#!/bin/sh
set -e

RUN=sudo
ROOT=
SU_USER=sh
INSTALL_EXTRAS=false
BUILD_IMAGE=false

configure () {
  if test -z "$ROBOCAMP_IMAGE_INSTALL" && which ubiquity > /dev/null
  then
    echo 'You are running this script in system builder mode. To install in this mode, $ROBOCAMP_IMAGE_INSTALL must be set to the path to the main drive (e.g. /dev/sda1).'
    if test -f "/opt/ros/melodic/lib/libtexas_robocamp.so"
      then echo 'The code for Texas RoboCamp 2020 is already installed on this computer. If you are a camper, you can continue on to the next part of the tutorial.'
      else echo 'If you are a camper, there is probably a problem with your setup.'
    fi
    exit 1
  fi
  if test -n "$ROBOCAMP_IMAGE_INSTALL"
  then
    if ! test -b "$ROBOCAMP_IMAGE_INSTALL"
    then
      echo 'Error: ROBOCAMP_IMAGE_INSTALL must be set to the path to the main drive (e.g. /dev/sda1).'
      exit 1
    fi
    ROOT=/target
    RUN="sudo chroot $ROOT"
    INSTALL_EXTRAS=true
    BUILD_IMAGE=true
    if ! test -f $ROOT/bin/cp
    then
      sudo mkdir $ROOT
      sudo mount $ROBOCAMP_IMAGE_INSTALL $ROOT
    fi
    cat $TARGET/resolv.conf 2>/dev/null | grep nameserver >/dev/null || sudo mount --bind /run $ROOT/run
    test -d $TARGET/proc/self || sudo mount --bind /proc /target/proc
    test -d $TARGET/sys/fs || sudo mount --bind /sys $TARGET/sys

    USER=bevo
    if ! grep "^$USER:" $ROOT/etc/passwd >/dev/null
    then
      echo "ERROR: The camper user must be named $USER."
      exit 1
    fi
    SU_USER="$RUN su $USER"
  fi
}

temp_install () {
  $RUN apt install $1
  $RUN apt-mark auto $1
}

add_key () {
  sudo apt-key --keyring $ROOT/etc/apt/trusted.gpg adv --keyserver keyserver.ubuntu.com --recv-keys "$@"
}

add_repo () {
  FILE=$1
  shift
  sudo sh -c "echo \"$@\" > $ROOT/etc/apt/sources.list.d/$FILE"
}

add_deb () {
  FILE=/tmp/`cat /dev/urandom | tr -dc '0-9A-F' | fold -w 16 | head -n 1`.deb
  $RUN which wget > /dev/null || temp_install wget
  $RUN wget --output-document $FILE $1
  $RUN apt install -y $FILE
  $RUN rm $FILE
}

# Use a function in case only part of the script is downloaded
setup () {
  configure

  COLOR_RED=`echo "\e[31m"`
  COLOR_GREEN=`echo "\e[32m"`
  COLOR_BURNT=`echo "\e[38;2;191;87;0m"`
  COLOR_RESET=`echo "\e[0m"`
  COLOR_BOLD=`echo "\e[1m"`
  if $RUN test `lsb_release -sc` != bionic
    then echo $COLOR_RED$COLOR_BOLD"ERROR: Texas RoboCamp 2020 is only compatible with Ubuntu 18.04."$COLOR_RESET
    echo $COLOR_RED"You are using version `lsb_release -sr`."$COLOR_RESET
    exit 1
  fi

  # Add repositories
  $RUN add-apt-repository universe
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

  if $INSTALL_EXTRAS
  then
    # Chrome
    add_key 4CCA1EAF950CEE4AB83976DCA040830F7FAC5991
    add_key EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796
    add_repo google-chrome.list "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main"
  fi

  $RUN apt update
  $RUN apt install -y ros-melodic-texas-robocamp-full

  add_deb https://zoom.us/client/latest/zoom_amd64.deb

  if $INSTALL_EXTRAS
  then
    $RUN apt install -y google-chrome-stable
    $RUN update-alternatives --set x-www-browser /usr/bin/firefox
    $RUN update-alternatives --set gnome-www-browser /usr/bin/firefox
    $RUN apt autoremove -y --purge

    echo "Filling in settings..."
    $SU_USER -c "dbus-run-session gsettings set org.gnome.shell favorite-apps \"['firefox.desktop', 'google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'terminator.desktop', 'code.desktop', 'Zoom.desktop']\""
    if lspci | grep VirtualBox
    then
      $SU_USER -c "dbus-run-session gsettings set org.gnome.desktop.screensaver lock-enabled false"
      $SU_USER -c "dbus-run-session gsettings set org.gnome.desktop.session idle-delay \"uint32 0\""
    fi
    echo "Done filling in settings"
  fi

  if $BUILD_IMAGE
  then
    sleep 3
    sudo lsof | grep $ROOT || true
    sudo umount -lR $ROOT/run $ROOT/dev $ROOT/proc $ROOT/sys || true
    sudo umount $ROOT
    sudo rmdir $ROOT
    which zerofree || sudo apt install zerofree
    echo "Shrinking target image..."
    sudo zerofree $ROBOCAMP_IMAGE_INSTALL
  fi
  echo $COLOR_GREEN$COLOR_BOLD"Finished installing packages for Texas RoboCamp 2020."$COLOR_RESET
}

setup
