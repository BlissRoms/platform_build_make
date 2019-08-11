#
# Copyright (C) 2019 BlissRoms & Aren Clegg
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#  Version: ROM Builder 0.7
#  Updated: 8/10/2019
#

#!/bin/bash

# Import/create build-rom.cfg variables
rm -rf build-rom.cfg
cat > build-rom.cfg << EOF
rompath=$(pwd)
bliss_device=""
bliss_debug=""
build_options=""
bliss_branch=""
rom_variant=""
clean="n"
cleanOption=""
debug="n"
official="n"
officialOption=""
patchOption=""
releaseOption=""
sync="n"
syncOption=""
EOF

#Import build-rom.cfg variables
source build-rom.cfg

# Clear Terminal Screeen
clear

# Define USER and define how many threads the cpu has
if [ -z "$USER" ];then
        export USER="$(id -un)"
fi

if [[ $(uname -s) = "Darwin" ]];then
        jobs=$(sysctl -n hw.ncpu)
elif [[ $(uname -s) = "Linux" ]];then
        jobs=$(nproc)
fi

# Code that interputs the command line switches
while test $# -gt 0
do
  case $1 in

  # Normal option processing
    -c | --clean)
      clean="y";
      echo "Clean build."
      ;;
    -d | --debug)
      debug="y";
      echo "Build Debug/eng build for testing **OFFICIAL BUILDS ARE DISABLED IN DEBUG MODE**"
      ;;
    -s | --sync)
      sync="y"
      echo "Repo sync."
      ;;
    -o | --official)
      official="y"
      echo "Building Official Bliss ROM."
      ;;
    -p | --patch)
      patchOption="p";
      echo "patching selected."
      ;;
    -r | --release)
      releaseOption="r";
      echo "Building as release selected."
      ;;
  # ...

  # Special cases
    --)
      break
      ;;
    --*)
      # error unknown (long) option $1
      ;;
    -?)
      # error unknown (short) option $1
      ;;

  # FUN STUFF HERE:
  # Split apart combined short options
    -*)
      split=$1
      shift
      set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
      continue
      ;;

  # Done with options
    *)
      break
      ;;
  esac

  # for testing purposes:
  shift
done

# these variables can't be stored in the .cfg file
bliss_branch=$3
bliss_device=$2
rom_variant=$1
build_options=$cleanOption$syncOption$officialOption$patchOption$releaseOption

# If build_options is not empty add the - options flag
if [ ! -z $build_options ];then
   build_options=-$cleanOption$syncOption$officialOption$patchOption$releaseOption
fi

display_help(){
 echo "Usage: $0 options arm/treble device_name"
      echo "options:"
      echo "-c | --clean    : Does make clean && make clobber"
      echo "-o | --official : Builds the rom as OFFICIAL"
      echo "-s | --sync     : Repo sync repos"
      echo "-----------------------------------------------------------------"
      echo "Treble Only Flags"
      echo "-----------------------------------------------------------------"
      echo "-p | --patch    : "
      echo "-r | --release  : "
      echo ""
}

# If rom_variant is empty, stop the script
if [[ -z $rom_variant || ! $rom_variant == "arm" ]];then
   clear
   echo "==========================="
   echo "No Rom variant was selected"
   echo "==========================="
   display_help
   exit
fi

# If bliss_device is empty, stop the script
if [ -z $bliss_device ];then
    clear
    echo "======================"
    echo "No Device was selected"
    echo "======================"
    display_help
    exit
fi

read -p "Continuing in 1 second..." -t 1
echo "Continuing..."

# If statement for $sync
if  [[ $sync == "y" && $1 = "arm" ]];then
    repo sync -c -j$jobs --force-sync
    syncOption="s"
fi

# If statment for $clean
if [[ $clean == "y" && $1 = "arm" ]];then
    make -j$jobs clean
    cleanOption="c"
fi

# If statment for $debug
if [[ $debug == "y" && $1 = "arm" ]];then
    bliss_debug="eng"
else
    bliss_debug="userdebug"
fi


# If statement for $official
if [[ $official == "y" && $1 = "arm" && $debug == "n" ]];then
    export BLISS_BUILDTYPE=OFFICIAL
    officialOption="o"
else
    export BLISS_BUILDTYPE=UNOFFICIAL
fi

# Build rom function
blissBuildVariant_arm() {
        lunch bliss_$2-$bliss_debug
        make -j$jobs blissify
}

# Build treble rom function
blissBuildVariant_treble() {
       bash /build/make/core/treble/build-treble.sh $1 $2 $3
}

# If statment for building arm or treble
if [ $rom_variant = "arm" ];then
   . build/envsetup.sh
   blissBuildVariant_arm $rom_variant $bliss_device $bliss_debug

elif [ $rom_variant = "treble" ];then
   blissBuildVariant_treble $build_options $bliss_device $bliss_branch
fi
