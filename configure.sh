#! /bin/bash

################################################################################
# Prepare
################################################################################

# Set up shell
if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
    set -x                      # Output commands
fi
set -e                          # Abort on errors



################################################################################
# Search
################################################################################

# TODO: Look not just for any BLAS, but for OpenBLAS specifically to
# ensure we are using an efficient BLAS

# if [ -z "${OPENBLAS_DIR}" ]; then
#     echo "BEGIN MESSAGE"
#     echo "OpenBLAS selected, but OPENBLAS_DIR not set. Checking some places..."
#     echo "END MESSAGE"
#     
#     FILES="include/gsl/gsl_math.h"
#     DIRS="/usr /usr/local /usr/local/gsl /usr/local/packages/gsl /usr/local/apps/gsl ${HOME} c:/packages/gsl"
#     for dir in $DIRS; do
#         OPENBLAS_DIR="$dir"
#         for file in $FILES; do
#             if [ ! -r "$dir/$file" ]; then
#                 unset OPENBLAS_DIR
#                 break
#             fi
#         done
#         if [ -n "$OPENBLAS_DIR" ]; then
#             break
#         fi
#     done
#     
#     if [ -z "$OPENBLAS_DIR" ]; then
#         echo "BEGIN MESSAGE"
#         echo "OpenBLAS not found"
#         echo "END MESSAGE"
#     else
#         echo "BEGIN MESSAGE"
#         echo "Found OpenBLAS in ${OPENBLAS_DIR}"
#         echo "END MESSAGE"
#     fi
# fi



################################################################################
# Build
################################################################################

if [ -z "${OPENBLAS_DIR}"                                            \
     -o "$(echo "${OPENBLAS_DIR}" | tr '[a-z]' '[A-Z]')" = 'BUILD' ]
then
    echo "BEGIN MESSAGE"
    echo "Using bundled OpenBLAS..."
    echo "END MESSAGE"
    
    # check for required tools. Do this here so that we don't require them when
    # using the system library
    if [ x$TAR = x ] ; then
      echo 'BEGIN ERROR'
      echo 'Could not find tar command. Please make sure that (gnu) tar is present'
      echo 'and that the TAR variable is set to its location.'
      echo 'END ERROR'
      exit 1
    fi
    #if [ x$PATCH = x ] ; then
    #  echo 'BEGIN ERROR'
    #  echo 'Could not find patch command. Please make sure that (gnu) tar is present'
    #  echo 'and that the PATCH variable is set to its location.'
    #  echo 'END ERROR'
    #  exit 1
    #fi

    # Set locations
    THORN=OpenBLAS
    NAME=OpenBLAS-0.2.12
    TARNAME=v0.2.12
    SRCDIR=$(dirname $0)
    BUILD_DIR=${SCRATCH_BUILD}/build/${THORN}
    if [ -z "${OPENBLAS_INSTALL_DIR}" ]; then
        INSTALL_DIR=${SCRATCH_BUILD}/external/${THORN}
    else
        echo "BEGIN MESSAGE"
        echo "Installing OpenBLAS into ${OPENBLAS_INSTALL_DIR} "
        echo "END MESSAGE"
        INSTALL_DIR=${OPENBLAS_INSTALL_DIR}
    fi
    DONE_FILE=${SCRATCH_BUILD}/done/${THORN}
    OPENBLAS_DIR=${INSTALL_DIR}
    
    if [ -e ${DONE_FILE} -a ${DONE_FILE} -nt ${SRCDIR}/dist/${NAME}.tar.gz \
                         -a ${DONE_FILE} -nt ${SRCDIR}/configure.sh ]
    then
        echo "BEGIN MESSAGE"
        echo "OpenBLAS has already been built; doing nothing"
        echo "END MESSAGE"
    else
        echo "BEGIN MESSAGE"
        echo "Building OpenBLAS"
        echo "END MESSAGE"
        
        # Build in a subshell
        (
        exec >&2                    # Redirect stdout to stderr
        if [ "$(echo ${VERBOSE} | tr '[:upper:]' '[:lower:]')" = 'yes' ]; then
            set -x                  # Output commands
        fi
        set -e                      # Abort on errors
        cd ${SCRATCH_BUILD}
        
        # Set up environment
        unset LIBS
        if echo '' ${ARFLAGS} | grep 64 > /dev/null 2>&1; then
            export OBJECT_MODE=64
        fi
        
        echo "OpenBLAS: Preparing directory structure..."
        mkdir build external done 2> /dev/null || true
        rm -rf ${BUILD_DIR} ${INSTALL_DIR}
        mkdir ${BUILD_DIR} ${INSTALL_DIR}
        
        echo "OpenBLAS: Unpacking archive..."
        pushd ${BUILD_DIR}
        ${TAR?} xzf ${SRCDIR}/dist/${TARNAME}.tar.gz
        
        echo "OpenBLAS: Configuring..."
        cd ${NAME}
        # no configuration necessary
        
        echo "OpenBLAS: Building..."
        ${MAKE} libs netlib shared CC="$CC" FC="$F90" CFLAGS="$CFLAGS" FFLAGS="$F90FLAGS" LDFLAGS="$LDFLAGS" LIBS="$LIBS"
        
        echo "OpenBLAS: Installing..."
        if [ "$(uname)" = "Darwin" ]; then
            # Create a script "install" that can handle the "-D"
            # option that OpenBLAS is using
            bindir="${BUILD_DIR}/bin"
            mkdir -p $bindir
            echo "exec ginstall" '"$@"' >$bindir/install
            chmod a+x $bindir/install
            export PATH="$bindir:$PATH"
        fi
        ${MAKE} install PREFIX="${INSTALL_DIR}"
        popd
        
        echo "OpenBLAS: Cleaning up..."
        rm -rf ${BUILD_DIR}
        
        date > ${DONE_FILE}
        echo "OpenBLAS: Done."
        )
        if (( $? )); then
            echo 'BEGIN ERROR'
            echo 'Error while building OpenBLAS. Aborting.'
            echo 'END ERROR'
            exit 1
        fi
    fi
    
fi



################################################################################
# Configure Cactus
################################################################################

# Set options
if [ "${OPENBLAS_DIR}" != '/usr' -a             \
     "${OPENBLAS_DIR}" != '/usr/local' -a       \
     "${OPENBLAS_DIR}" != 'NO_BUILD' ]
then
    : ${OPENBLAS_INC_DIRS=}
    : ${OPENBLAS_LIB_DIRS="${OPENBLAS_DIR}/lib"}
fi
: ${OPENBLAS_LIBS='openblas'}

# Pass options to Cactus
echo "BEGIN MAKE_DEFINITION"
echo "HAVE_OPENBLAS     = 1"
echo "OPENBLAS_DIR      = ${OPENBLAS_DIR}"
echo "OPENBLAS_INC_DIRS = ${OPENBLAS_INC_DIRS}"
echo "OPENBLAS_LIB_DIRS = ${OPENBLAS_LIB_DIRS}"
echo "OPENBLAS_LIBS     = ${OPENBLAS_LIBS}"
echo "BLAS_DIR          = ${OPENBLAS_DIR}"
echo "BLAS_INC_DIRS     = ${OPENBLAS_INC_DIRS}"
echo "BLAS_LIB_DIRS     = ${OPENBLAS_LIB_DIRS}"
echo "BLAS_LIBS         = ${OPENBLAS_LIBS}"
echo "LAPACK_DIR        = ${OPENBLAS_DIR}"
echo "LAPACK_INC_DIRS   = ${OPENBLAS_INC_DIRS}"
echo "LAPACK_LIB_DIRS   = ${OPENBLAS_LIB_DIRS}"
echo "LAPACK_LIBS       = ${OPENBLAS_LIBS}"
echo "END MAKE_DEFINITION"

echo 'INCLUDE_DIRECTORY $(OPENBLAS_INC_DIRS)'
echo 'LIBRARY_DIRECTORY $(OPENBLAS_LIB_DIRS)'
echo 'LIBRARY           $(OPENBLAS_LIBS)'
