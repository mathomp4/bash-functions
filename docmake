# vim: ft=bash

#set -euo pipefail

# We are going to write a bash function to handle all the above cases
# it will have two arguments: build type and generator
# The generator will default to "Unix Makefiles" if not given
# We also need to capture the name of the directory that it is called from
# and use to add onto both the build and install directories (which are
# based on CMAKE_BUILD_LOCATION and CMAKE_INSTALL_LOCATION)
# such that the build and install directories are:
#   $CMAKE_BUILD_LOCATION/$current_basename/build-$build_type
#   $CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type
# if using the Makefile generator, and if Ninja is used, then the build
# and install directories are:
#   $CMAKE_BUILD_LOCATION/$current_basename/build-$build_type-Ninja
#   $CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type-Ninja

function usage() {
   echo "Usage: docmake (--debug | --aggressive) --ninja --only-cmake -n|--dryrun|--dry-run --runtests --builddir <custom_build_dir> --installdir <custom_install_dir>"
   echo ""
   echo "  --debug: build type is Debug"
   echo "  --aggressive: build type is Aggressive"
   echo "  --ninja: use Ninja as the build system"
   echo "  --only-cmake: only run the cmake command"
   echo "  -n|--dryrun|--dry-run: echo the cmake command and not run it"
   echo "  --runtests: run the tests after the build and install"
   echo '  --builddir <custom_build_dir>: use a custom build directory (relative to $CMAKE_BUILD_LOCATION/$current_basename)'
   echo '  --installdir <custom_install_dir>: use a custom install directory (relative to $CMAKE_INSTALL_LOCATION/$current_basename)'
   echo 
   echo "  If the custom build and install directories are not given, the default build and install directories are:"
   echo '    $CMAKE_BUILD_LOCATION/$current_basename/build-$build_type-SLES<OS_VERSION>'
   echo '    $CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type-SLES<OS_VERSION>'
   echo '  where $current_basename is the name of the directory that docmake is called from'
   echo '  and $build_type is the build type (Debug, Aggressive, or Release)'
   echo '  If the Ninja generator is used, then the build and install directories are appended with "-Ninja"'
   echo 
   echo '  If a custom build and/or install directory is given, the build and install directories are:'
   echo '    $CMAKE_BUILD_LOCATION/$current_basename/<custom_build_dir>-$build_type-SLES<OS_VERSION>'
   echo '    $CMAKE_INSTALL_LOCATION/$current_basename/<custom_install_dir>-$build_type-SLES<OS_VERSION>'
   echo '  where $current_basename is the name of the directory that docmake is called from'
   echo 
   echo "NOTE: Users will need to set the CMAKE_BUILD_LOCATION and CMAKE_INSTALL_LOCATION environment variables"
   echo "      to the desired build and install locations. These are currently set to:"
   echo 
   echo "      CMAKE_BUILD_LOCATION: $CMAKE_BUILD_LOCATION"
   echo "      CMAKE_INSTALL_LOCATION: $CMAKE_INSTALL_LOCATION"
}

function docmake() {

   # Let's make sure that the CMAKE_BUILD_LOCATION and CMAKE_INSTALL_LOCATION
   # environment variables are set. If they are, let's also make sure that
   # they are directories

   if [ -z "$CMAKE_BUILD_LOCATION" ]; then
      echo "CMAKE_BUILD_LOCATION environment variable is not set"
      return 1
   else
      if [ ! -d "$CMAKE_BUILD_LOCATION" ]; then
         echo "CMAKE_BUILD_LOCATION is not a directory"
         return 1
      fi
   fi

   if [ -z "$CMAKE_INSTALL_LOCATION" ]; then
      echo "CMAKE_INSTALL_LOCATION environment variable is not set"
      return 1
   else
      if [ ! -d "$CMAKE_INSTALL_LOCATION" ]; then
         echo "CMAKE_INSTALL_LOCATION is not a directory"
         return 1
      fi
   fi

   # We want to use command line arguments for the build type and generator
   # for example:
   #   docmake --build-type=Release --generator=Unix|Ninja 
   #
   # we also want arguments like --only-cmake to only run the cmake command
   # and not the build and install commands
   # We also want a dryrun option to echo the cmake command and not run it
   # We also want the ability to pass in a custom build and install directory
  
   only_cmake=false 
   dryrun=false
   do_ninja=false
   runtests=false
   build_type="Release"
   custom_build_dir=""
   custom_install_dir=""
   while [ "$1" != "" ]; do
      case $1 in
         --debug)
            build_type="Debug"
            ;;
         --aggressive)
            build_type="Aggressive"
            ;;
         --ninja)
            do_ninja=true
            ;;
         --only-cmake)
            only_cmake=true
            ;;
         -n | --dryrun | --dry-run)
            dryrun=true
            ;;
         --runtests)
            runtests=true
            ;;
         --builddir)
            shift
            custom_build_dir=$1
            ;;
         --installdir)
            shift
            custom_install_dir=$1
            ;;
         -h | --help)
            usage
            return
            ;;
         *)
            echo "Unknown option: $1"
            usage
            return 1
            ;;
      esac
      shift
   done

   local current_basename=$(basename $(pwd))
   # if the custom build and install directories are given, use them
   # otherwise, use the default build and install directories. Note that the
   # custom build and install directories will need to be relative to the
   # $CMAKE_BUILD_LOCATION and $CMAKE_INSTALL_LOCATION and we will append
   # the build type and the OS version to the custom build and install directories
   # if those words are not already in the custom build and install directories

   local default_build_dir="$CMAKE_BUILD_LOCATION/$current_basename/build-$build_type"
   local default_install_dir="$CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type"
   if [ "$custom_build_dir" != "" ]; then
      build_dir="$CMAKE_BUILD_LOCATION/$current_basename/$custom_build_dir"
      if [[ $custom_build_dir != *"$build_type"* ]]; then
         build_dir+="-$build_type"
      fi
   else
      build_dir="$default_build_dir"
   fi
   if [ "$custom_install_dir" != "" ]; then
      install_dir="$CMAKE_INSTALL_LOCATION/$current_basename/$custom_install_dir"
      if [[ $custom_install_dir != *"$build_type"* ]]; then
         install_dir+="-$build_type"
      fi
   else
      install_dir="$default_install_dir"
   fi

   if [ "$do_ninja" == "true" ]; then
      build_dir+="-Ninja"
      install_dir+="-Ninja"
      cmake_gen="-G Ninja"
   else
      cmake_gen=""
   fi

   # we also will append SLES12 or SLES15 depending on the OS version
   OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | cut -d. -f1 | sed 's/"//g')
   # we append only if we don't have "SLES12" or "SLES15" in build_dir and install_dir
   
   if [[ $build_dir != *SLES* ]]; then
      build_dir+="-SLES$OS_VERSION"
   fi
   if [[ $install_dir != *SLES* ]]; then
      install_dir+="-SLES$OS_VERSION"
   fi

   if [ "$dryrun" == "true" ]; then
      echo "Running: cmake -B $build_dir -S . -DCMAKE_BUILD_TYPE=$build_type --install-prefix $install_dir $cmake_gen"
      if [ "$only_cmake" == "true" ]; then
         return
      else
         echo "Running: cmake --build $build_dir --target install -j 10"
      fi
      return
   fi

   # Link the build directory to the source directory, if the symlink does not exist, linking
   if [ ! -L $(pwd)/$(basename $build_dir) ]; then
      ln -sv $build_dir .
   else
      echo "$(basename $build_dir) already exists. Not linking."
   fi
   # Run cmake
   cmake -B $build_dir -S . -DCMAKE_BUILD_TYPE=$build_type --install-prefix $install_dir $cmake_gen
   # the build directory with the dirname of the full $build_dir path
   if [ "$only_cmake" == "true" ]; then
      echo ""
      echo "To install, run:"
      echo "cmake --build $build_dir --target install -j 10"
      return
   fi

   # Link the install directory to the source directory if the symlink does not exist, linking
   # the install directory with the dirname of the full $install_dir path
   if [ ! -L $(pwd)/$(basename $install_dir) ]; then
      ln -sv $install_dir .
   else
      echo "$(basename $install_dir) already exists. Not linking."
   fi
   # Run the build and install
   cmake --build $build_dir --target install -j 10

   # Run tests if asked
   if [ "$runtests" == "true" ]; then
      cmake --build $build_dir --target tests -j 10
   fi
}

