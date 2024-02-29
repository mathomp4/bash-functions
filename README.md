# Useful bash functions

## docmake

This is a script use to automate building GEOS builds. It eases the CMake to have source code in swdev, but builds and installs in
nobackups or other places. This is good because swdev is limited in space and backed up, but nobackups is not backed up and have 
more space.

### Requirements

A user must have the following environment variables set:

- `CMAKE_BUILD_LOCATION`: The location where the build will be done. This is usually a nobackup location.
- `CMAKE_INSTALL_LOCATION`: The location where the build will be installed. This is usually a nobackup location.

### Usage

```
Usage: docmake (--debug | --aggressive) --ninja --only-cmake -n|--dryrun|--dry-run --runtests --builddir <custom_build_dir> --installdir <custom_install_dir> --cmake-options <additional_cmake_options>

  --debug: build type is Debug
  --aggressive: build type is Aggressive
  --ninja: use Ninja as the build system
  --only-cmake: only run the cmake command
  -n|--dryrun|--dry-run: echo the cmake command and not run it
  --runtests: run the tests after the build and install
  --builddir <custom_build_dir>: use a custom build directory (relative to $CMAKE_BUILD_LOCATION/$current_basename)
  --installdir <custom_install_dir>: use a custom install directory (relative to $CMAKE_INSTALL_LOCATION/$current_basename)
  --cmake-options <additional_cmake_options>: pass in additional CMake options

  If the custom build and install directories are not given, the default build and install directories are:
    $CMAKE_BUILD_LOCATION/$current_basename/build-$build_type-SLES<OS_VERSION>
    $CMAKE_INSTALL_LOCATION/$current_basename/install-$build_type-SLES<OS_VERSION>
  where $current_basename is the name of the directory that docmake is called from
  and $build_type is the build type (Debug, Aggressive, or Release)
  If the Ninja generator is used, then the build and install directories are appended with "-Ninja"

  If a custom build and/or install directory is given, the build and install directories are:
    $CMAKE_BUILD_LOCATION/$current_basename/<custom_build_dir>-$build_type-SLES<OS_VERSION>
    $CMAKE_INSTALL_LOCATION/$current_basename/<custom_install_dir>-$build_type-SLES<OS_VERSION>
  where $current_basename is the name of the directory that docmake is called from
```

## cmpnc4

This function compares two netCDF files using `nccmp -dmfgsB`.

Call as:
```bash
cmpnc4 file1.nc4 file2.nc4
```

## dropin

This function is used to "drop in" to a SLURM allocation.

Call as:
```bash
dropin <jobid>
```

## makebench

This function is used to change the partition and qos of a SLURM job to use the `preops` partition and `benchmark` qos.

Call as:
```bash
makebench <jobid>
```

## rgi

This function runs `ripgrep` but ignores any `build*` and `install*` directories

Call as:
```bash
rgi <pattern>
```

## sq

This runs `squeue` and then pipes the output to `rpen.py` to colorize the output.

Call as:
```bash
sq <options>
```

