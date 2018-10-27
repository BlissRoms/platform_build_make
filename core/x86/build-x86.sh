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
proprietary="n"
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
      echo "		 -p | --patch: Run the patches only"
      echo "		 -r | --proprietary: build needed items from proprietary vendor (non-public)"
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
    -r | --proprietary)
      proprietary="y";
      echo "proprietary selected."
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
else
	echo "you need to at least use '--help'"

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
   
elif [ "$2" = "none" ];then
   export USE_FOSS=false
   export USE_OPENGAPPS=false
   echo "Building with no app stores"
   
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
	
else 
	echo "Not gonna sync this round"
fi

if [ $clean == "y" ];then
	echo "Cleaning up a bit"
    make clean && make clobber 
fi

if  [ $sync == "y" ];then
	echo "Let the patching begin"
	bash "$rompath/vendor/x86/utils/autopatch.sh"
fi

if  [ $patch == "y" ];then
	echo "Let the patching begin"
	bash "$rompath/vendor/x86/utils/autopatch.sh"
fi

echo "Removing: device/*/sepolicy/common/private/genfs_contexts"
rm -f device/*/sepolicy/common/private/genfs_contexts
echo "Removing: vendor/bliss/build/tasks/kernel.mk"
rm -f vendor/bliss/build/tasks/kernel.mk

if [[ "$1" = "android_x86_64-user" || "$1" = "android_x86_64-userdebug" || "$1" = "android_x86_64-eng" || "$1" = "android_x86-user" || "$1" = "android_x86-userdebug" || "$1" = "android_x86-eng" ]];then
echo "Setting up build env for: $1"
	. build/envsetup.sh
fi

buildProprietary() {
	echo "Setting up Proprietary environment for: $1"
	lunch $1
	echo "Building proprietary tools, part 1... This won't take too long..."
	mka update_engine_applier
	echo "Building proprietary tools... part 2... This may take a while..."
	mka proprietary
}

buildVariant() {
	echo "Starting lunch command for: $1"
	lunch $1
	echo "Starting up the build... This may take a while..."
	mka iso_img
}

if  [ $proprietary == "y" ];then
	buildProprietary $bliss_variant
fi

if [[ "$1" = "android_x86_64-user" || "$1" = "android_x86_64-userdebug" || "$1" = "android_x86_64-eng" || "$1" = "android_x86-user" || "$1" = "android_x86-userdebug" || "$1" = "android_x86-eng" ]];then
	buildVariant $bliss_variant $bliss_variant_name
fi
