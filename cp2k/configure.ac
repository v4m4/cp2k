AC_INIT(CP2K, 2.5, , cp2k, http://cp2k.org)

AC_PROG_CC()
AC_PROG_FC()
AC_FC_FREEFORM()

AC_LANG(Fortran)
AC_CHECK_LIB(fftw3, dfftw_execute_dft)
AC_CHECK_LIB(xc, xc_f90_func_init,,,-lm)
AC_CHECK_LIB(scalapack, pdgemm,,,[-lreflapack -lrefblas])
AC_CHECK_LIB(elpa, solve_evp_real_2stage)

AC_LANG(C)
AC_CHECK_LIB(int, init_libint)
AC_CHECK_LIB(deriv, init_libderiv_base)
AC_CHECK_LIB(cudart, cudaSetDevice)
AC_CHECK_LIB(cudart, cudaStreamCreateWithPriority)
AC_CHECK_LIB(nvToolsExt, nvtxNameOsThread)

echo libxc ${ac_cv_lib_xc_xc_f90_func_init}
#AC_FC_FUNC(dfftw_execute_dft)
#AC_CHECK_LIB(fftw3, ${dfftw_execute_dft})
#AC_FC_FUNC(xc_f90_func_init)
#AC_CHECK_LIB(xc, ${xc_f90_func_init}, , ,-lm)
#AC_FC_FUNC(pdgemm)
#AC_CHECK_LIB(scalapack, ${pdgemm}, , ,-lreflapack -lrefblas)

#AC_SEARCH_LIBS(dfftw_execute_dft, fftw3)
#AC_SEARCH_LIBS(${pdgemr2d}, )
#echo $FC_MODEXT
#echo $FC
#echo $name
#echo "fftw: $HAVE_LIBfftw3"
