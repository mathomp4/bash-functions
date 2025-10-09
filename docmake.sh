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
   echo "Usage: docmake (--debug | --aggressive | --vecttrap) --ninja --only-cmake -n|--dryrun|--dry-run --runtests --jobs <number_of_jobs> --extra <extra_name> --builddir <custom_build_dir> --installdir <custom_install_dir> --cmake-options <additional_cmake_options> --mit"
   echo ""
   echo "  --debug: build type is Debug"
   echo "  --aggressive: build type is Aggressive"
   echo "  --vecttrap: build type is VectTrap"
   echo "  --ninja: use Ninja as the build system"
   echo "  --only-cmake: only run the cmake command"
   echo "  -n|--dryrun|--dry-run: echo the cmake command and not run it"
   echo "  --runtests: run the tests after the build and install"
   echo '  --jobs <number_of_jobs>: specify the number of jobs to run in parallel'
   echo '  --extra <extra_name>: use a custom build and install directory with this additional name (relative to $CMAKE_BUILD_LOCATION/$current_basename and $CMAKE_INSTALL_LOCATION/$current_basename)'
   echo '  --builddir <custom_build_dir>: use a custom build directory (relative to $CMAKE_BUILD_LOCATION/$current_basename)'
   echo '  --installdir <custom_install_dir>: use a custom install directory (relative to $CMAKE_INSTALL_LOCATION/$current_basename)'
   echo '  --cmake-options <additional_cmake_options>: pass in additional CMake options'
   echo "  --mit: build for MIT ocean"
   echo "  --no-f2py: do not build f2py"
   echo 
   echo "  If the custom build and install directories are not given, the default build and install directories are:"
   echo '    $CMAKE_BUILD_LOCATION/$current_basename/build-$build_type'
   echo '    $CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type'
   echo '  where $current_basename is the name of the directory that docmake is called from'
   echo '  and $build_type is the build type (Debug, Aggressive, VectTrap, or Release)'
   echo '  If the Ninja generator is used, then the build and install directories are appended with "-Ninja"'
   echo 
   echo '  If the extra option is given, the build and install directories are:'
   echo '    $CMAKE_BUILD_LOCATION/$current_basename/build-<extra_name>-$build_type'
   echo '    $CMAKE_INSTALL_LOCATION/$current_basename/install-<extra_name>-$build_type'
   echo 
   echo '  If a custom build and/or install directory is given, the build and install directories are:'
   echo '    $CMAKE_BUILD_LOCATION/$current_basename/<custom_build_dir>-$build_type'
   echo '    $CMAKE_INSTALL_LOCATION/$current_basename/<custom_install_dir>-$build_type'
   echo '  where $current_basename is the name of the directory that docmake is called from'
   echo 
   echo "NOTE: Users will need to set the CMAKE_BUILD_LOCATION and CMAKE_INSTALL_LOCATION environment variables"
   echo "      to the desired build and install locations. These are currently set to:"
   echo 
   echo "      CMAKE_BUILD_LOCATION: $CMAKE_BUILD_LOCATION"
   echo "      CMAKE_INSTALL_LOCATION: $CMAKE_INSTALL_LOCATION"
   echo
   echo "      If these environment variables are set to the string 'pwd', then the build and install locations"
   echo "      will be set to the parent directory of the current working directory (i.e., the build and install"
   echo "      locations will be in the same directory as the source code)."
}

function docmake() {

   # Let's make sure that the CMAKE_BUILD_LOCATION and CMAKE_INSTALL_LOCATION
   # environment variables are set. If they are, let's also make sure that
   # they are directories

   # We need to allow for the builds to be in pwd. For that, if CMAKE_BUILD_LOCATION
   # or CMAKE_INSTALL_LOCATION is "pwd" then we need to handle that case

   local CMAKE_BUILD_IN_PWD="false"
   if [ -z "$CMAKE_BUILD_LOCATION" ]; then
      echo "CMAKE_BUILD_LOCATION environment variable is not set"
      return 1
   else
      if [ "$CMAKE_BUILD_LOCATION" == "pwd" ]; then
         local _CMAKE_BUILD_LOCATION=$(dirname $(pwd))
         local CMAKE_BUILD_IN_PWD="true"
      else
         local _CMAKE_BUILD_LOCATION="$CMAKE_BUILD_LOCATION"
      fi

      if [ ! -d "$_CMAKE_BUILD_LOCATION" ]; then
         echo "CMAKE_BUILD_LOCATION is not a directory"
         return 1
      fi
   fi

   local CMAKE_INSTALL_IN_PWD="false"
   if [ -z "$CMAKE_INSTALL_LOCATION" ]; then
      echo "CMAKE_INSTALL_LOCATION environment variable is not set"
      return 1
   else
      if [ "$CMAKE_INSTALL_LOCATION" == "pwd" ]; then
         local _CMAKE_INSTALL_LOCATION=$(dirname $(pwd))
         local CMAKE_INSTALL_IN_PWD="true"
      else
         local _CMAKE_INSTALL_LOCATION="$CMAKE_INSTALL_LOCATION"
      fi

      if [ ! -d "$_CMAKE_INSTALL_LOCATION" ]; then
         echo "CMAKE_INSTALL_LOCATION is not a directory"
         return 1
      fi
   fi

   # We want to make sure that the user is in a directory that has a CMakeLists.txt
   # file. If not, we will return an error
   if [ ! -f CMakeLists.txt ]; then
      echo "No CMakeLists.txt file found in the current directory"
      return 1
   fi

   # Also, let's make sure there is a project name in the CMakeLists.txt file
   if [ -z "$(grep project CMakeLists.txt)" ]; then
      echo "No project found in the CMakeLists.txt file. Are you sure this is a CMake project?"
      return 1
   fi

   # We want to use command line arguments for the build type and generator
   # for example:
   #   docmake --build-type=Release --generator=Unix|Ninja 
   #
   # we also want arguments like --only-cmake to only run the cmake command
   # and not the build and install commands
   # We also want a dryrun option to echo the cmake command and not run it
   # We also want the ability to pass in a custom build and install directory
   # We also need a way to pass in additional CMake options if desired

   only_cmake=false 
   dryrun=false
   do_ninja=false
   runtests=false
   mitbuild=false
   use_f2py=true
   build_type="Release"
   extra_name=""
   custom_build_dir=""
   custom_install_dir=""
   additional_cmake_options=""

   # We will also allow the user to specify the number of jobs to run in parallel
   # via environment variable DOCMAKE_NUM_JOBS or via a command line argument --jobs <number_of_jobs>
   # the default will be 10 jobs

   num_jobs=10
   if [ ! -z "$DOCMAKE_NUM_JOBS" ]; then
      num_jobs=$DOCMAKE_NUM_JOBS
   fi
   while [ "$1" != "" ]; do
      case $1 in
         --debug)
            build_type="Debug"
            ;;
         --aggressive)
            build_type="Aggressive"
            ;;
         --vecttrap)
            build_type="VectTrap"
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
         --mit)
            mitbuild=true
            ;;
         --no-f2py)
            use_f2py=false
            ;;
         --extra)
            shift
            extra_name=$1
            ;;
         --builddir)
            shift
            custom_build_dir=$1
            ;;
         --installdir)
            shift
            custom_install_dir=$1
            ;;
         --cmake-options)
            shift
            additional_cmake_options=$1
            ;;
         --jobs)
            shift
            num_jobs=$1
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
   #
   # Also, if --extra is provided, we will use that as the additional name
   # but if --builddir and --installdir are provided, we will use those and it superseded
   
   if [ "$extra_name" != "" ]; then
      local default_build_dir="$_CMAKE_BUILD_LOCATION/$current_basename/build-$extra_name-$build_type"
      local default_install_dir="$_CMAKE_INSTALL_LOCATION/$current_basename/install-$extra_name-$build_type"
   else
      local default_build_dir="$_CMAKE_BUILD_LOCATION/$current_basename/build-$build_type"
      local default_install_dir="$_CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type"
   fi
   if [ "$custom_build_dir" != "" ]; then
      build_dir="$_CMAKE_BUILD_LOCATION/$current_basename/$custom_build_dir"
      if [[ $custom_build_dir != *"$build_type"* ]]; then
         build_dir+="-$build_type"
      fi
   else
      build_dir="$default_build_dir"
   fi
   if [ "$custom_install_dir" != "" ]; then
      install_dir="$_CMAKE_INSTALL_LOCATION/$current_basename/$custom_install_dir"
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

   if [[ $mitbuild == "true" ]]; then
      additional_cmake_options+=" -DBUILD_MIT_OCEAN=ON -DMIT_CONFIG_ID=c90_llc90_02"
   fi

   if [[ $use_f2py == "false" ]]; then
      additional_cmake_options+=" -DUSE_F2PY:BOOL=OFF"
   fi


   if [ "$dryrun" == "true" ]; then
      echo "Running: cmake -B $build_dir -S . -DCMAKE_BUILD_TYPE=$build_type --install-prefix $install_dir $cmake_gen $additional_cmake_options"
      if [ "$CMAKE_BUILD_IN_PWD" == "false" ]; then
         echo "Will symlink $build_dir to $(pwd)/$(basename $build_dir)"
      fi
      if [ "$only_cmake" == "true" ]; then
         return
      else
         echo "Running: cmake --build $build_dir --target install -j $num_jobs"
      fi
      if [ "$CMAKE_INSTALL_IN_PWD" == "false" ]; then
         echo "Will symlink $install_dir to $(pwd)/$(basename $install_dir)"
      fi
      if [ "$runtests" == "true" ]; then
         echo "Running: cmake --build $build_dir --target tests -j $num_jobs"
      fi
      return
   fi

   # Link the build directory to the source directory, if the symlink does not exist, linking
   # NOTE: We do not want to do this if the build directory is in pwd
   # so we will check if CMAKE_BUILD_IN_PWD is set to false
   if [ "$CMAKE_BUILD_IN_PWD" == "false" ]; then
      if [ ! -L $(pwd)/$(basename $build_dir) ]; then
         ln -sv $build_dir .
      else
         echo "$(basename $build_dir) already exists. Not linking."
      fi
   fi
   # Run cmake
   cmake -B $build_dir -S . -DCMAKE_BUILD_TYPE=$build_type --install-prefix $install_dir $cmake_gen $additional_cmake_options
   # the build directory with the dirname of the full $build_dir path
   if [ "$only_cmake" == "true" ]; then
      echo ""
      echo "To install, run:"
      echo "cmake --build $build_dir --target install -j 10"
      return
   fi

   # Link the install directory to the source directory if the symlink does not exist, linking
   # the install directory with the dirname of the full $install_dir path
   # NOTE: We do not want to do this if the install directory is in pwd
   # so we will check if CMAKE_INSTALL_IN_PWD is set to false
   if [ "$CMAKE_INSTALL_IN_PWD" == "false" ]; then
      if [ ! -L $(pwd)/$(basename $install_dir) ]; then
         ln -sv $install_dir .
      else
         echo "$(basename $install_dir) already exists. Not linking."
      fi
   fi
   # Run the build and install
   cmake --build $build_dir --target install -j 10

   # Run tests if asked
   if [ "$runtests" == "true" ]; then
      cmake --build $build_dir --target tests -j 10
   fi
}

