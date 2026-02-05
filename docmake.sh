# vim: ft=bash

# Notes for bash:
# - We use arrays (cmake_gen, additional_cmake_opts) so they expand cleanly.
# - --cmake-options <"..."> can include multiple flags; we split them via unquoted expansion or read -a.
# - Use $(dirname "${PWD}") for parent dir.

function usage() {
   echo "Usage: docmake (--debug | --aggressive | --vecttrap) --ninja --gnumake --only-cmake -n|--dryrun|--dry-run --runtests --jobs <number_of_jobs> --extra <extra_name> --builddir <custom_build_dir> --installdir <custom_install_dir> --cmake-options <additional_cmake_options> --mit --profile"
   echo ""
   echo "  --debug: build type is Debug"
   echo "  --aggressive: build type is Aggressive"
   echo "  --vecttrap: build type is VectTrap"
   echo "  --ninja: use Ninja as the build system (Default)"
   echo "  --gnumake: use GNU Make as the build system"
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
   echo "  --profile: enable CMake profiling (google-trace format). Output saved to <build_dir>/cmake_profile.json"
   echo
   echo "  If the custom build and install directories are not given, the default build and install directories are:"
   echo '    $CMAKE_BUILD_LOCATION/$current_basename/build-$build_type'
   echo '    $CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type'
   echo '  where $current_basename is the name of the directory that docmake is called from'
   echo '  and $build_type is the build type (Debug, Aggressive, VectTrap, or Release)'
   echo '  If the Ninja generator is used (default), then the build and install directories are appended with "-Ninja"'
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

   # Validate CMAKE_BUILD_LOCATION
   local CMAKE_BUILD_IN_PWD="false"
   if [ -z "$CMAKE_BUILD_LOCATION" ]; then
      echo "CMAKE_BUILD_LOCATION environment variable is not set"
      return 1
   else
      if [ "$CMAKE_BUILD_LOCATION" == "pwd" ]; then
         local _CMAKE_BUILD_LOCATION=$(dirname "$(pwd)")
         CMAKE_BUILD_IN_PWD="true"
      else
         local _CMAKE_BUILD_LOCATION="$CMAKE_BUILD_LOCATION"
      fi

      if [ ! -d "$_CMAKE_BUILD_LOCATION" ]; then
         echo "CMAKE_BUILD_LOCATION is not a directory"
         return 1
      fi
   fi

   # Validate CMAKE_INSTALL_LOCATION
   local CMAKE_INSTALL_IN_PWD="false"
   if [ -z "$CMAKE_INSTALL_LOCATION" ]; then
      echo "CMAKE_INSTALL_LOCATION environment variable is not set"
      return 1
   else
      if [ "$CMAKE_INSTALL_LOCATION" == "pwd" ]; then
         local _CMAKE_INSTALL_LOCATION=$(dirname "$(pwd)")
         CMAKE_INSTALL_IN_PWD="true"
      else
         local _CMAKE_INSTALL_LOCATION="$CMAKE_INSTALL_LOCATION"
      fi

      if [ ! -d "$_CMAKE_INSTALL_LOCATION" ]; then
         echo "CMAKE_INSTALL_LOCATION is not a directory"
         return 1
      fi
   fi

   # Must be in a CMake project dir
   if [ ! -f CMakeLists.txt ]; then
      echo "No CMakeLists.txt file found in the current directory"
      return 1
   fi
   if ! grep -q 'project' CMakeLists.txt; then
      echo "No project found in the CMakeLists.txt file. Are you sure this is a CMake project?"
      return 1
   fi

   # Defaults
   local only_cmake=false
   local dryrun=false
   local do_ninja=true  # Default to Ninja
   local runtests=false
   local mitbuild=false
   local use_f2py=true
   local do_profile=false
   local build_type="Release"
   local extra_name=""
   local custom_build_dir=""
   local custom_install_dir=""
   
   # Use arrays for safer flag handling
   local -a additional_cmake_opts=()
   local -a cmake_gen=()

   local num_jobs=10
   if [ -n "$DOCMAKE_NUM_JOBS" ]; then
      num_jobs=$DOCMAKE_NUM_JOBS
   fi

   while [ "$1" != "" ]; do
      case $1 in
         --debug)       build_type="Debug" ;;
         --aggressive)  build_type="Aggressive" ;;
         --vecttrap)    build_type="VectTrap" ;;
         --ninja)       do_ninja=true ;;
         --gnumake)     do_ninja=false ;;
         --only-cmake)  only_cmake=true ;;
         -n|--dryrun|--dry-run) dryrun=true ;;
         --runtests)    runtests=true ;;
         --mit)         mitbuild=true ;;
         --no-f2py)     use_f2py=false ;;
         --profile)     do_profile=true ;;
         --extra)
            shift; extra_name=$1 ;;
         --builddir)
            shift; custom_build_dir=$1 ;;
         --installdir)
            shift; custom_install_dir=$1 ;;
         --cmake-options)
            shift
            # Split string into array elements by spaces (mimic standard shell splitting)
            # This allows passing "-DVAR1=A -DVAR2=B" as one string
            read -ra new_opts <<< "$1"
            additional_cmake_opts+=("${new_opts[@]}")
            ;;
         --jobs)
            shift; num_jobs=$1 ;;
         -h|--help)
            usage; return 0 ;;
         *)
            echo "Unknown option: $1"
            usage; return 1 ;;
      esac
      shift
   done

   local current_basename=$(basename "$(pwd)")
   
   # Default build/install dirs
   local default_build_dir
   local default_install_dir
   
   if [ "$extra_name" != "" ]; then
      default_build_dir="$_CMAKE_BUILD_LOCATION/$current_basename/build-$extra_name-$build_type"
      default_install_dir="$_CMAKE_INSTALL_LOCATION/$current_basename/install-$extra_name-$build_type"
   else
      default_build_dir="$_CMAKE_BUILD_LOCATION/$current_basename/build-$build_type"
      default_install_dir="$_CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type"
   fi

   local build_dir
   local install_dir

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
      cmake_gen=("-G" "Ninja")
   fi

   if [[ $mitbuild == "true" ]]; then
      additional_cmake_opts+=("-DBUILD_MIT_OCEAN=ON" "-DMIT_CONFIG_ID=c90_llc90_02")
   fi

   if [[ $use_f2py == "false" ]]; then
      additional_cmake_opts+=("-DUSE_F2PY:BOOL=OFF")
   fi

   if [[ $do_profile == "true" ]]; then
      local profile_file="${build_dir}/cmake_profile.json"
      additional_cmake_opts+=("--profiling-format=google-trace" "--profiling-output=${profile_file}")
      echo "Profiling enabled: output will be at ${profile_file}"
   fi

   # Dry run
   if [ "$dryrun" == "true" ]; then
      echo "Running: cmake -B $build_dir -S . -DCMAKE_BUILD_TYPE=$build_type --install-prefix $install_dir ${cmake_gen[*]} ${additional_cmake_opts[*]}"
      if [ "$CMAKE_BUILD_IN_PWD" == "false" ]; then
         echo "Will symlink $build_dir to $(pwd)/$(basename "$build_dir")"
      fi
      if [ "$only_cmake" != "true" ]; then
         echo "Running: cmake --build $build_dir --target install -j $num_jobs"
      fi
      if [ "$CMAKE_INSTALL_IN_PWD" == "false" ]; then
         echo "Will symlink $install_dir to $(pwd)/$(basename "$install_dir")"
      fi
      if [ "$runtests" == "true" ]; then
         echo "Running: cmake --build $build_dir --target tests -j $num_jobs"
      fi
      return 0
   fi

   # Symlink build dir
   if [ "$CMAKE_BUILD_IN_PWD" == "false" ]; then
      if [ ! -L "$(pwd)/$(basename "$build_dir")" ]; then
         ln -sv "$build_dir" .
      else
         echo "$(basename "$build_dir") already exists. Not linking."
      fi
   fi

   # Run cmake
   cmake -B "$build_dir" -S . -DCMAKE_BUILD_TYPE="$build_type" --install-prefix "$install_dir" "${cmake_gen[@]}" "${additional_cmake_opts[@]}"

   if [ "$only_cmake" == "true" ]; then
      echo ""
      echo "To install, run:"
      echo "cmake --build '$build_dir' --target install -j ${num_jobs}"
      return 0
   fi

   # Symlink install dir
   if [ "$CMAKE_INSTALL_IN_PWD" == "false" ]; then
      if [ ! -L "$(pwd)/$(basename "$install_dir")" ]; then
         ln -sv "$install_dir" .
      else
         echo "$(basename "$install_dir") already exists. Not linking."
      fi
   fi

   # Run build + install
   cmake --build "$build_dir" --target install -j "${num_jobs}"

   # Run tests
   if [ "$runtests" == "true" ]; then
      cmake --build "$build_dir" --target tests -j "${num_jobs}"
   fi
}
