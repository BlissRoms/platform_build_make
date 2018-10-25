#!/bin/bash

rom_fp="$(date +%y%m%d)"
rompath=$(pwd)
mkdir -p release/$rom_fp/
# Comment out 'set -e' if your session terminates. 
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
ver=$(date +"%F")

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
      echo "Usage: $0 options buildVariants blissBranch"
      echo "options: -c | --clean : Does make clean && make clobber and resets the treble device tree"
      echo "         -r | --release : Builds a twrp zip of the rom (only for A partition) default creates system.img"
      echo "         -s | --sync: Repo syncs the rom (clears out patches), then reapplies patches to needed repos"
      echo ""
      echo "buildVariants: arm64_a_stock | arm64_ab_stock : Vanilla Rom"
      echo "                arm64_a_gapps | arm64_ab_gapps : Stock Rom with Gapps Built-in"
      echo "                arm64_a_foss | arm64_ab_foss : Stock Rom with Foss"
      echo "                arm64_a_go | arm64_ab_go : Stock Rom with Go-Gapps"
      echo ""
      echo "blissBranch: select which bliss branch to sync, default is o8.1-los"
      ;;
    -v | --version)
      echo "Version: Bliss Treble Builder 0.3"
      echo "Updated: 7/29/2018"
      ;;
    -c | --clean)
      clean="y";
      echo "Cleaning build and device tree selected."
      ;;
    -r | --release)
      bliss_release="y";
      echo "Building as release selected."
      ;;
    -s | --sync)
      sync="y"
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

if [ "$1" = "arm64_a_stock" ];then
        bliss_variant=treble_arm64_avN-userdebug;
        bliss_variant_name=arm64-a-stock;
        bliss_partition="a";

elif [ "$1" = "arm64_a_gapps" ];then
        bliss_variant=treble_arm64_agS-userdebug;
        bliss_variant_name=arm64-a-gapps;
        bliss_partition="a";

elif [ "$1" = "arm64_a_foss" ];then
        bliss_variant=treble_arm64_afS-userdebug;
        bliss_variant_name=arm64-a-foss;
        bliss_partition="a";

elif [ "$1" = "arm64_a_go" ];then
        bliss_variant=treble_arm64_aoS-userdebug;
        bliss_variant_name=arm64-a-go;
        bliss_partition="a";

elif [ "$1" = "arm64_ab_stock" ];then
        bliss_variant=treble_arm64_bvN-userdebug;
        bliss_variant_name=arm64-ab-stock;
        bliss_partition="ab";

elif [ "$1" = "arm64_ab_gapps" ];then
        bliss_variant=treble_arm64_bgS-userdebug;
        bliss_variant_name=arm64-ab-gapps;
        bliss_partition="ab";

elif [ "$1" = "arm64_ab_foss" ];then
        bliss_variant=treble_arm64_bfS-userdebug;
        bliss_variant_name=arm64-ab-foss;
        bliss_partition="ab";

elif [ "$1" = "arm64_ab_go" ];then
        bliss_variant=treble_arm64_boS-userdebug;
        bliss_variant_name=arm64-ab-go;
        bliss_partition="ab";
else
	echo "you need to at least use '--help'"
fi

if [ "$2" = "" ];then
   romBranch="p9.0"
   echo "Using branch $romBranch for repo syncing Bliss."
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

rm -f device/*/sepolicy/common/private/genfs_contexts

if [ $clean == "y" ];then
    (cd device/phh/treble; git clean -fdx; bash generate.sh $rom)
    make clean && make clobber
else
    (cd device/phh/treble; bash generate.sh $rom)
fi

sed -i -e 's/BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1610612736/BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648/g' device/phh/treble/phhgsi_arm64_a/BoardConfig.mk

if  [ $sync == "y" ];then
if [ -z "$local_patches" ];then
    if [ -d patches ];then
        ( cd patches; git fetch; git reset --hard; git checkout origin/$localManifestBranch)
    else
        git clone https://github.com/BlissRoms/treble_patches patches -b $localManifestBranch
    fi
else
    rm -Rf patches
    mkdir patches
    unzip  "$local_patches" -d patches
fi
echo "Let the patching begin"
bash "$rompath/build/make/core/treble/apply-patches.sh" $rompath/patches
fi

if [[ $patch == "y" ]];then
echo "Let the patching begin"
bash "$rompath/build/make/core/treble/apply-patches.sh" $rompath/patches
fi

blissRelease(){
if [[ "$1" = "y" && $bliss_partition = "a" ]];then
       echo "Building twrp flashable gsi.."
        if [ -d $OUT/img2sdat ] ;then
             cp -r $rompath/build/make/core/treble/img2sdat/* $OUT/img2sdat
         else
             mkdir -p $OUT/img2sdat
             cp -r $rompath/build/make/core/treble/img2sdat/* $OUT/img2sdat
        fi
        if [ -d $OUT/twrp_flashables ] ;then
             cp -r $rompath/build/make/core/treble/twrp_flashables/* $OUT/twrp_flashables
         else
             mkdir -p $OUT/twrp_flashables
             cp -r $rompath/build/make/core/treble/twrp_flashables/* $OUT/twrp_flashables
        fi
        cp $OUT/system.img $OUT/img2sdat/system.img
        cd $OUT/img2sdat
        ./img2sdat.py system.img -o tmp -v 4
        cd $rompath
        cp $OUT/img2sdat/tmp/* $OUT/twrp_flashables/arm64a
        cd $OUT/twrp_flashables/arm64a
        7za a -tzip arm64a.zip *
        cd $rompath
        cp $OUT/twrp_flashables/arm64a/arm64a.zip $rompath/release/$rom_fp/Bliss-$ver-$bliss_variant_name.zip
        rm -rf $OUT/img2sdat $OUT/twrp_flashables
        filename=Bliss-$ver-$bliss_variant_name.zip
        filesize=$(stat -c%s release/$rom_fp/$filename)
        md5sum release/$rom_fp/Bliss-$ver-$bliss_variant_name.zip > release/$rom_fp/Bliss-$ver-$bliss_variant_name.zip.md5
        md5sum_file=Bliss-$ver-$bliss_variant_name.zip.md5
else
        if  [[ "$1" = "n" || $bliss_partition = "ab" ]];then
        echo "Twrp Building is currently not suported on a/b"
        fi
        echo "Copying $OUT/system.img -> release/$rom_fp/Bliss-$ver-$bliss_variant_name.img"
        cp $OUT/system.img release/$rom_fp/Bliss-$ver-$bliss_variant_name.img
        filename=Bliss-$ver-$bliss_variant_name.img
        filesize=$(stat -c%s release/$rom_fp/$filename)
        md5sum release/$rom_fp/Bliss-$ver-$bliss_variant_name.img  > release/$rom_fp/Bliss-$ver-$bliss_variant_name.img.md5
        md5sum_file=Bliss-$ver-$bliss_variant_name.img.md5
fi
}

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

if [[ "$1" = "arm64_a_stock" || "$1" = "arm64_a_gapps" || "$1" = "arm64_a_foss" || "$1" = "arm64_a_go" || "$1" = "arm64_ab_stock" || "$1" = "arm64_ab_gapps" || "$1" = "arm64_ab_foss" || "$1" = "arm64_ab_go" ]];then
echo "Setting up build env for $1"
. build/envsetup.sh
fi

buildVariant() {
		## echo "running lunch for $1"
        ## lunch $1
        echo "Running lunch for $bliss_variant"
        lunch $bliss_variant
        make WITHOUT_CHECK_API=true BUILD_NUMBER=$rom_fp installclean
        make WITHOUT_CHECK_API=true BUILD_NUMBER=$rom_fp -j$jobs systemimage
        make WITHOUT_CHECK_API=true BUILD_NUMBER=$rom_fp vndk-test-sepolicy
        blissRelease $bliss_release $bliss_partition
        blissHeader $filename $filesize $md5sum_file
}

if [[ "$1" = "arm64_a_stock" || "$1" = "arm64_a_gapps" || "$1" = "arm64_a_foss" || "$1" = "arm64_a_go" || "$1" = "arm64_ab_stock" || "$1" = "arm64_ab_gapps" || "$1" = "arm64_ab_foss" || "$1" = "arm64_ab_go" ]];then
buildVariant $bliss_variant $bliss_variant_name
fi

