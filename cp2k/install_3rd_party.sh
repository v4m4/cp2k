#!/bin/bash -e

#
#
# this script installs a fairly complete up to date toolchain for development and use of cp2k.
#
# it does not try to build an efficient blas, nor important libraries such as libsmm.
#
#

mkdir -p 3rd_party
cd 3rd_party

INSTALLDIR=${PWD}/install
echo "All tools will be installed in " ${INSTALLDIR}
mkdir -p ${INSTALLDIR}


#
# number of processes to use for compilation
#
nprocs=`nproc --all`

#
# first get an up-to-date toolchain.
#

echo "==================== Installing binutils ================="
if [ -f binutils-2.24.tar.gz  ]; then
  echo "Installation already started, skipping it."
else
  wget http://ftp.gnu.org/gnu/binutils/binutils-2.24.tar.gz
  tar -xzf binutils-2.24.tar.gz
  cd binutils-2.24
  ./configure --prefix=${INSTALLDIR} --enable-gold --enable-plugins >& config.log
  make -j $nprocs >& make.log
  make -j $nprocs install >& install.log
  cd ..
fi

echo "==================== Installing valgrind ================="
if [ -f valgrind-3.10.0.tar.bz2 ]; then
  echo "Installation already started, skipping it."
else
  wget http://valgrind.org/downloads/valgrind-3.10.0.tar.bz2
  tar -xjf valgrind-3.10.0.tar.bz2
  cd valgrind-3.10.0
  ./configure --prefix=${INSTALLDIR} >& config.log
  make -j $nprocs >& make.log
  make -j $nprocs install >& install.log
  cd ..
fi

echo "==================== Installing lcov ======================"
if [ -f lcov-1.11.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget http://downloads.sourceforge.net/ltp/lcov-1.11.tar.gz
  tar -xzf lcov-1.11.tar.gz
  cd lcov-1.11
  # note.... this installs in ${INSTALLDIR}/usr/bin
  make PREFIX=${INSTALLDIR} install >& make.log
  cd ..
fi

echo "==================== Installing gcc ======================"
if [ -f gcc-4.9.1.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget https://ftp.gnu.org/gnu/gcc/gcc-4.9.1/gcc-4.9.1.tar.gz
  tar -xzf gcc-4.9.1.tar.gz
  cd gcc-4.9.1
  ./contrib/download_prerequisites >& prereq.log
  GCCROOT=${PWD}
  mkdir obj
  cd obj
  ${GCCROOT}/configure --prefix=${INSTALLDIR}  --enable-languages=c,c++,fortran --disable-multilib --disable-bootstrap --enable-lto --enable-plugins >& config.log
  make -j $nprocs >& make.log
  make -j $nprocs install >& install.log
  cd ../..
fi

# now we need these tools and compiler to be in the path
cat << EOF > setup
if [ -z "\${LD_LIBRARY_PATH}" ]
then
    LD_LIBRARY_PATH=${INSTALLDIR}/lib64:${INSTALLDIR}/lib; export LD_LIBRARY_PATH
else
    LD_LIBRARY_PATH=${INSTALLDIR}/lib64:${INSTALLDIR}/lib:\${LD_LIBRARY_PATH}; export LD_LIBRARY_PATH
fi
if [ -z "\${PATH}" ]
then
    PATH=${INSTALLDIR}/bin:${INSTALLDIR}/usr/bin; export PATH
else
    PATH=${INSTALLDIR}/bin:${INSTALLDIR}/usr/bin:\$PATH; export PATH
fi 
EOF
SETUPFILE=${PWD}/setup
source ${SETUPFILE}

# set some flags, leading to nice stack traces on crashes, yet, are optimized
export CFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math"
export FFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math"
export FCFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math"
export CXXFLAGS="-O2 -ftree-vectorize -g -fno-omit-frame-pointer -march=native -ffast-math"
export CC=gcc
export FC=gfortran
export F77=gfortran
export CXX=g++

echo "==================== Installing mpich ======================"
if [ -f mpich-3.1.2.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget http://www.mpich.org/static/downloads/3.1.2/mpich-3.1.2.tar.gz
  tar -xzf mpich-3.1.2.tar.gz
  cd mpich-3.1.2
  ./configure --prefix=${INSTALLDIR} >& config.log
  make -j $nprocs >& make.log
  make -j $nprocs install >& install.log
  cd ..
fi

echo "==================== Installing scalapack ======================"
if [ -f scalapack_installer.tgz ]; then
  echo "Installation already started, skipping it."
else
  wget http://www.netlib.org/scalapack/scalapack_installer.tgz
  tar -xzf scalapack_installer.tgz
  # we dont know the version
  cd scalapack_installer_*
  SLROOT=${PWD}
  # needs fixing for compile options, we use echo as mpirun command to avoid testing,
  # yet download blas / lapack... whole installer is a bit serial as well (and fails with --make="make -j32"
  ./setup.py --mpirun=echo --downblas --downlapack >& make.log
  # copy libraries where we like them
  cp install/lib/* ${INSTALLDIR}/lib/
  cd ..
fi

echo "==================== Installing libxc ===================="
if [ -f libxc-2.0.1.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget http://www.cp2k.org/static/downloads/libxc-2.0.1.tar.gz
  echo "c332f08648ec2bc7ccce83e45a84776215aa5dfebc64fae2a23f2ac546d41ea4 *libxc-2.0.1.tar.gz" | sha256sum  --check
  tar -xzf libxc-2.0.1.tar.gz
  cd libxc-2.0.1
  ./configure  --prefix=${INSTALLDIR} >& config.log
  make -j $nprocs >& make.log
  make install >& install.log
  cd ..
fi

echo "==================== Installing libint ===================="
if [ -f libint-1.1.4.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget http://www.cp2k.org/static/downloads/libint-1.1.4.tar.gz
  echo "f67b13bdf1135ecc93b4cff961c1ff33614d9f8409726ddc8451803776885cff *libint-1.1.4.tar.gz" | sha256sum  --check
  tar -xzf libint-1.1.4.tar.gz
  cd libint-1.1.4
  ./configure  --prefix=${INSTALLDIR} --with-libint-max-am=5 --with-libderiv-max-am1=4 --with-cc-optflags="$CFLAGS" --with-cxx-optflags="$CXXFLAGS" >& config.log
  make -j $nprocs >&  make.log
  make install >& install.log
  cd ..
fi

echo "==================== Installing FFTW ===================="
if [ -f fftw-3.3.4.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget http://www.cp2k.org/static/downloads/fftw-3.3.4.tar.gz
  echo "8f0cde90929bc05587c3368d2f15cd0530a60b8a9912a8e2979a72dbe5af0982 *fftw-3.3.4.tar.gz" | sha256sum  --check 
  tar -xzf fftw-3.3.4.tar.gz
  cd fftw-3.3.4
  ./configure  --prefix=${INSTALLDIR} --enable-openmp >& config.log
  make -j $nprocs >&  make.log
  make install >& install.log
  cd ..
fi

echo "==================== Installing ELPA ===================="
# elpa expect FC to be an mpi fortran compiler that's happy with long lines, and that a bunch of libs can be found
export FC="mpif90 -ffree-line-length-none"
export LDFLAGS="-L${INSTALLDIR}/lib"
export LIBS="-lscalapack -lreflapack -lrefblas"
if [ -f elpa-2013.11.008.tar.gz ]; then
  echo "Installation already started, skipping it."
else
  wget http://www.cp2k.org/static/downloads/elpa-2013.11.008.tar.gz
  echo "d4a028fddb64a7c1454f08b930525cce0207893c6c770cb7bf92ab6f5d44bd78 *elpa-2013.11.008.tar.gz" | sha256sum  --check
  tar -xzf elpa-2013.11.008.tar.gz

  # need both flavors ?
  cp -rp ELPA_2013.11 ELPA_2013.11-mt

  cd ELPA_2013.11-mt
  ./configure  --prefix=${INSTALLDIR} --enable-openmp=yes --with-generic --enable-shared=no >& config.log
  # wrong deps, build serially ?
  make -j 1 >&  make.log
  make install >& install.log
  cd ..

  cd ELPA_2013.11
  ./configure  --prefix=${INSTALLDIR} --enable-openmp=no --with-generic --enable-shared=no >& config.log
  # wrong deps, build serially ?
  make -j 1 >&  make.log
  make install >& install.log
  cd ..
fi

echo "==================== generating arch files ===================="
echo "these can be found in the arch subdirectory"
mkdir -p arch

WFLAGS="-Waliasing -Wampersand -Wc-binding-type -Wintrinsic-shadow -Wintrinsics-std -Wline-truncation -Wno-tabs -Wrealloc-lhs-all -Wtarget-lifetime -Wunderflow -Wunused-but-set-variable -Wunused-variable -Werror"

cat << EOF > arch/local.pdbg
CC       = gcc
CPP      =
FC       = mpif90 
LD       = mpif90
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__parallel -D__SCALAPACK -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -I${INSTALLDIR}/include\
           -std=f2003 -fimplicit-none -ffree-form\
           -O1 -fno-omit-frame-pointer -fcheck=bounds,do,recursion,pointer -g  \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -L${INSTALLDIR}/lib/\
           -fsanitize=leak
LIBS     = -lxc -lderiv -lint  -lscalapack -lreflapack -lrefblas -lstdc++ -lfftw3
EOF

cat << EOF > arch/local.popt
CC       = gcc
CPP      =
FC       = mpif90 
LD       = mpif90
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__parallel -D__SCALAPACK -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -I${INSTALLDIR}/include -std=f2003 -fimplicit-none -O3 -march=native -ffast-math -g -ffree-form \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -L${INSTALLDIR}/lib
LIBS     = -lxc -lderiv -lint  -lscalapack -lreflapack -lrefblas -lstdc++ -lfftw3 
EOF

cat << EOF > arch/local.psmp
CC       = gcc
CPP      =
FC       = mpif90 
LD       = mpif90
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__parallel -D__SCALAPACK -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -fopenmp -I${INSTALLDIR}/include -std=f2003 -fimplicit-none -O3 -march=native -ffast-math -g -ffree-form \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -fopenmp -L${INSTALLDIR}/lib/
LIBS     = -lxc -lderiv -lint  -lscalapack -lreflapack -lrefblas -lstdc++ -lfftw3 -lfftw3_omp
EOF

cat << EOF > arch/local.sdbg
CC       = gcc
CPP      =
FC       = gfortran 
LD       = gfortran
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -I${INSTALLDIR}/include\
           -std=f2003 -fimplicit-none -ffree-form\
           -O1 -fno-omit-frame-pointer -fcheck=bounds,do,recursion,pointer -g  \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -L${INSTALLDIR}/lib
           -fsanitize=leak
LIBS     = -lxc -lderiv -lint -lreflapack -lrefblas -lstdc++ -lfftw3 
EOF

cat << EOF > arch/local.sopt
CC       = gcc
CPP      =
FC       = gfortran 
LD       = gfortran
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -I${INSTALLDIR}/include -std=f2003 -fimplicit-none -O3 -march=native -ffast-math -g -ffree-form \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -L${INSTALLDIR}/lib/
LIBS     = -lxc -lderiv -lint -lreflapack -lrefblas -lstdc++ -lfftw3 
EOF

cat << EOF > arch/local.ssmp
CC       = gcc
CPP      =
FC       = gfortran 
LD       = gfortran
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -fopenmp -I${INSTALLDIR}/include -std=f2003 -fimplicit-none -O3 -march=native -ffast-math -g -ffree-form \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -fopenmp -L${INSTALLDIR}/lib/
LIBS     = -lxc -lderiv -lint  -lreflapack -lrefblas -lstdc++ -lfftw3 -lfftw3_omp
EOF

cat << EOF > arch/local_valgrind.sdbg
CC       = gcc
CPP      =
FC       = gfortran 
LD       = gfortran
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -I${INSTALLDIR}/include\
           -std=f2003 -fimplicit-none -ffree-form\
           -O0 -fno-omit-frame-pointer -g  \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -L${INSTALLDIR}/lib
LIBS     = -lxc -lderiv -lint -lreflapack -lrefblas -lstdc++ -lfftw3 
EOF

cat << EOF > arch/local_valgrind.pdbg
CC       = gcc
CPP      =
FC       = mpif90 
LD       = mpif90
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__parallel -D__SCALAPACK -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5
FCFLAGS  = -I${INSTALLDIR}/include\
           -std=f2003 -fimplicit-none -ffree-form\
           -O0 -fno-omit-frame-pointer -g  \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -L${INSTALLDIR}/lib
LIBS     = -lxc -lderiv -lint  -lscalapack -lreflapack -lrefblas -lstdc++ -lfftw3
EOF

cat << EOF > arch/local_cuda.psmp
NVCC     = nvcc -D__GNUC_MINOR__=6
CC       = gcc
CPP      =
FC       = mpif90 
LD       = mpif90
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__parallel -D__SCALAPACK -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5 -D__ACC -D__DBCSR_ACC -D__PW_CUDA 
FCFLAGS  = -fopenmp -I${INSTALLDIR}/include -std=f2003 -fimplicit-none -O3 -march=native -ffast-math -g -ffree-form \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -fopenmp -L${INSTALLDIR}/lib/ -L/usr/local/cuda/lib64
NVFLAGS  = \$(DFLAGS) -g -O2 -arch sm_35
LIBS     = -lxc -lderiv -lint  -lscalapack -lreflapack -lrefblas -lstdc++ -lfftw3 -lfftw3_omp -lcudart -lcufft -lcublas -lrt
EOF

cat << EOF > arch/local_cuda.ssmp
NVCC     = nvcc -D__GNUC_MINOR__=6
CC       = gcc
CPP      =
FC       = gfortran 
LD       = gfortran
AR       = ar -r
WFLAGS   = ${WFLAGS}
DFLAGS   = -D__LIBINT -D__FFTW3 -D__LIBXC2 -D__LIBINT_MAX_AM=6 -D__LIBDERIV_MAX_AM1=5 -D__ACC -D__DBCSR_ACC -D__PW_CUDA
FCFLAGS  = -fopenmp -I${INSTALLDIR}/include -std=f2003 -fimplicit-none -O3 -march=native -ffast-math -g -ffree-form \$(DFLAGS) \$(WFLAGS)
LDFLAGS  = -fopenmp -L${INSTALLDIR}/lib/ -L/usr/local/cuda/lib64
NVFLAGS  = \$(DFLAGS) -g -O2 -arch sm_35
LIBS     = -lxc -lderiv -lint  -lreflapack -lrefblas -lstdc++ -lfftw3 -lfftw3_omp -lcudart -lcufft -lcublas -lrt
EOF

echo "Ha... done!"
echo "to use this toolchain use: source ${SETUPFILE}"

#EOF
