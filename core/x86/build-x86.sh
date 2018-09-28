#!/bin/bash

rom_fp="$(date +%y%m%d)"
rompath=$(pwd)
mkdir -p release/$rom_fp/
set -e

localManifestBranch="p9.0"
rom="bliss"
bliss_variant=""
bliss_variant_name=""
bliss_release="n"
bliss_partiton=""
filename=""
file_size=""
clean="n"
sync="n"
patch="n"
romBranch=""

if [ -z "$USER" ];then
        export USER="$(id -un)"
fi
export LC_ALL=C

if [[ $(uname -s) = "Darwin" ]];then
        jobs=$(sysctl -n hw.ncpu)
elif [[ $(uname -s) = "Linux" ]];then
        jobs=$(nproc)
fi


while test $# -gt 0
do
  case $1 in

  # Normal option processing
    -h | --help)
      echo "Usage: $0 options buildVariants blissBranch/extras"
      echo "options: -s | --sync: Repo syncs the rom (clears out patches), then reapplies patches to needed repos"
      echo ""
      echo "buildVariants: "
      echo "android_x86-user, android_x86-userdebug, android_x86-eng,  "
      echo "android_x86_64-user, android_x86_64-userdebug, android_x86_64-eng"
      echo "blissBranch: select which bliss branch to sync, default is o8.1-los"
      echo "extras: specify 'foss' or 'gapps' to be built in"
      ;;
    -c | --clean)
      clean="y";
      echo "Cleaning build and device tree selected."
      ;;
    -v | --version)
      echo "Version: Bliss x86 Builder 0.1"
      echo "Updated: 9/20/2018"
      ;;
    -s | --sync)
      sync="y";
      echo "Repo syncing and patching selected."
      ;;
    -p | --patch)
      patch="y";
      echo "patching selected."
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


if [ "$1" = "android_x86_64-user" ];then
        bliss_variant=android_x86_64-user;
        bliss_variant_name=android_x86_64-user;

elif [ "$1" = "android_x86_64-userdebug" ];then
        bliss_variant=android_x86_64-userdebug;
        bliss_variant_name=android_x86_64-userdebug;

elif [ "$1" = "android_x86_64-eng" ];then
        bliss_variant=android_x86_64-eng;
        bliss_variant_name=android_x86_64-eng;
        
elif [ "$1" = "android_x86-eng" ];then
        bliss_variant=android_x86-eng;
        bliss_variant_name=android_x86-eng;

elif [ "$1" = "android_x86-userdebug" ];then
        bliss_variant=android_x86-userdebug;
        bliss_variant_name=android_x86-userdebug;

elif [ "$1" = "android_x86-eng" ];then
        bliss_variant=android_x86-eng;
        bliss_variant_name=android_x86-eng;

fi


if [ "$2" = "" ];then
   romBranch="p9.0"
   echo "Using branch $romBranch for repo syncing Bliss."
   
elif [ "$2" = "foss" ];then
   export USE_OPENGAPPS=false
   export USE_FOSS=true
   echo "Building with FDroid & microG included"
   
elif [ "$2" = "gapps" ];then
   export USE_FOSS=false
   export USE_OPENGAPPS=true
   echo "Building with OpenGapps included"
   
else
   romBranch="$2"
   echo "Using branch $romBranch for repo syning Bliss."
   
fi

if  [ $sync == "y" ];then
         repo init -u https://github.com/BlissRoms/platform_manifest.git -b $romBranch 
         rm -f .repo/local_manifests/*
	if [ -d $rompath/.repo/local_manifests ] ;then
		 cp -r $rompath/build/make/core/x86/x86_manifests/* $rompath/.repo/local_manifests
	else
		 mkdir -p $rompath/.repo/local_manifests
		 cp -r $rompath/build/make/core/x86/x86_manifests/* $rompath/.repo/local_manifests
	fi
	
	repo sync -c -j$jobs --no-tags --no-clone-bundle --force-sync
fi

if [ $clean == "y" ];then
    make clean && make clobber 
fi

if  [ $sync == "y" ];then
	bash "$rompath/vendor/x86/utils/autopatch.sh"
fi

if  [ $patch == "y" ];then
	bash "$rompath/vendor/x86/utils/autopatch.sh"
fi

rm -f device/*/sepolicy/common/private/genfs_contexts
rm -f vendor/bliss/build/tasks/kernel.mk

blissHeader(){
        file_size=$(echo "${filesize}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
        echo -e ""
        echo -e "      ___           ___                   ___           ___      "
        echo -e "     /\  \         /\__\      ___        /\  \         /\  \     "
        echo -e "    /::\  \       /:/  /     /\  \      /::\  \       /::\  \    "
        echo -e "   /:/\:\  \     /:/  /      \:\  \    /:/\ \  \     /:/\ \  \   "
        echo -e "  /::\~\:\__\   /:/  /       /::\__\  _\:\~\ \  \   _\:\~\ \  \  "
        echo -e " /:/\:\ \:\__\ /:/__/     __/:/\/__/ /\ \:\ \ \__\ /\ \:\ \ \__\ "
        echo -e " \:\~\:\/:/  / \:\  \    /\/:/  /    \:\ \:\ \/__/ \:\ \:\ \/__/ "
        echo -e "  \:\ \::/  /   \:\  \   \::/__/      \:\ \:\__\    \:\ \:\__\   "
        echo -e "   \:\/:/  /     \:\  \   \:\__\       \:\/:/  /     \:\/:/  /   "
        echo -e "    \::/__/       \:\__\   \/__/        \::/  /       \::/  /    "
        echo -e "     ~~            \/__/                 \/__/         \/__/     "
        echo -e ""
        echo -e "===========-Bliss Package Complete-==========="
        echo -e "File: $1"
        echo -e "MD5: $3"
        echo -e "Size: $file_size"
        echo -e "==============================================="
        echo -e "Have A Truly Blissful Experience"
        echo -e "==============================================="
        echo -e ""
}

if [[ "$1" = "android_x86_64-user" || "$1" = "android_x86_64-userdebug" || "$1" = "android_x86_64-eng" || "$1" = "android_x86-user" || "$1" = "android_x86-userdebug" || "$1" = "android_x86-eng" ]];then
echo "$1"
	. build/envsetup.sh
fi

buildVariant() {
	lunch $1
	mka iso_img
	blissHeader $filename $filesize $md5sum_file
}

if [[ "$1" = "android_x86_64-user" || "$1" = "android_x86_64-userdebug" || "$1" = "android_x86_64-eng" || "$1" = "android_x86-user" || "$1" = "android_x86-userdebug" || "$1" = "android_x86-eng" ]];then
	buildVariant $bliss_variant $bliss_variant_name
fi
