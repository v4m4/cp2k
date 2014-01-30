! *****************************************************************************
!> \brief Driver mode - To communicate with i-PI Python wrapper
!> \par History
!>      none
!> \author Michele Ceriotti 03.2012
! *****************************************************************************
MODULE ipi_driver

  USE cell_types,                      ONLY: cell_create,&
                                             cell_type,&
                                             init_cell
  USE cp_external_control,             ONLY: external_control
  USE cp_subsys_types,                 ONLY: cp_subsys_type
  USE f77_interface,                   ONLY: default_para_env
  USE force_env_methods,               ONLY: force_env_calc_energy_force
  USE force_env_types,                 ONLY: force_env_get,&
                                             force_env_set_cell,&
                                             force_env_type
  USE global_types,                    ONLY: global_environment_type
  USE input_section_types,             ONLY: section_vals_get_subs_vals,&
                                             section_vals_type,&
                                             section_vals_val_get
  USE iso_c_binding
  USE kinds,                           ONLY: default_path_length,&
                                             default_string_length,&
                                             dp
  USE message_passing,                 ONLY: mp_bcast,&
                                             mp_sync
  USE virial_types,                    ONLY: virial_type
#include "cp_common_uses.h"                                               

  IMPLICIT NONE
  
  PRIVATE

  CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'ipi_driver'

  PUBLIC :: run_driver

  INTERFACE
  SUBROUTINE usleep(useconds) bind(C)
  ! integer(c_int) function usleep(useconds) bind(C)
  USE iso_c_binding
    INTEGER(c_int32_t), value                :: useconds

! end function

  END SUBROUTINE
  END INTERFACE

  CONTAINS
! *****************************************************************************
!> \brief
!> \par History
!>       12.2013 included in repository 
!> \author Ceriotti
! *****************************************************************************
 
  SUBROUTINE run_driver ( force_env, globenv, error )
    TYPE(force_env_type), POINTER            :: force_env
    TYPE(global_environment_type), POINTER   :: globenv
    TYPE(cp_error_type), INTENT(inout)       :: error

    CHARACTER(len=*), PARAMETER :: routineN = 'run_driver', &
      routineP = moduleN//':'//routineN
    INTEGER, PARAMETER                       :: MSGLEN = 12

    CHARACTER(len=default_path_length)       :: c_hostname, drv_hostname
    CHARACTER(LEN=default_string_length)     :: header
    CHARACTER*1024                           :: host
    INTEGER                                  :: drv_port, idir, ii, inet, ip, &
                                                nat, nread, port, readbuffer, &
                                                slock, socket, swait, uwait
    LOGICAL                                  :: drv_unix, hasdata = .FALSE., &
                                                ionode = .FALSE., should_stop
    REAL(KIND=dp)                            :: cellh(3,3), cellih(3,3), pot, &
                                                vir(3,3)
    REAL(KIND=dp), ALLOCATABLE               :: combuf(:)
    TYPE(cell_type), POINTER                 :: cpcell
    TYPE(cp_subsys_type), POINTER            :: subsys
    TYPE(section_vals_type), POINTER         :: drv_section, motion_section
    TYPE(virial_type), POINTER               :: virial

!MIK DRIVER
! server address parsing
! buffers and temporaries for communication
! access cp2k structures

    ionode=(default_para_env%source==default_para_env%mepos)

    ! reads driver parameters from input
    motion_section => section_vals_get_subs_vals(force_env%root_section,"MOTION",error=error)
    drv_section     => section_vals_get_subs_vals(motion_section,"DRIVER",error=error)

    CALL section_vals_val_get(drv_section,"HOST",c_val=drv_hostname,error=error)
    CALL section_vals_val_get(drv_section,"PORT",i_val=drv_port,error=error)
    CALL section_vals_val_get(drv_section,"UNIX",l_val=drv_unix,error=error)

    
    ! opens the socket
    socket=0    
    inet=1
    IF (ionode) THEN
       WRITE(*,*) "@ i-PI DRIVER BEING LOADED"
       WRITE(*,*) "@ INPUT DATA: ", TRIM(drv_hostname), drv_port, drv_unix                          
       c_hostname=TRIM(drv_hostname)//ACHAR(0)
       CALL open_socket(socket, .NOT. drv_unix, drv_port, c_hostname) 
    ENDIF    
    
    !now we have a socket, so we can initialize the CP2K environments. 
    NULLIFY(cpcell)
    CALL cell_create(cpcell,error=error)
    uwait=10000  ! number of MICROseconds to be waited in filesystem lock
    driver_loop: DO
      ! do communication on master node only...
      header = ""

      ! this syncs the processes, possibly (see sockets.c) without calling MPI_Barrier, 
      ! which is nice as MPI_barrier eats up a lot of CPU for nothing
      inet=slock(default_para_env%source, default_para_env%mepos) 
      CALL mp_sync(default_para_env%group)

      IF (ionode) nread=readbuffer(socket, header, MSGLEN)
      IF (ionode)  WRITE(0,*) "returned from readbuffer" 

      inet=swait(uwait, default_para_env%source, default_para_env%mepos)
      CALL mp_sync(default_para_env%group)

      CALL mp_bcast(nread,default_para_env%source, default_para_env%group)
      IF (nread .EQ. 0) THEN
        IF (ionode) WRITE(*,*) " @ DRIVER MODE: Could not read from socket, exiting now."
        EXIT
      ENDIF

      CALL mp_bcast(header,default_para_env%source, default_para_env%group)
      
      IF (ionode) WRITE(*,*) " @ DRIVER MODE: Message from server: ", TRIM(header)
      IF (TRIM(header) == "STATUS") THEN          

         inet=slock(default_para_env%source, default_para_env%mepos) 
         CALL mp_sync(default_para_env%group)
         IF (ionode) THEN  ! does not  need init (well, maybe it should, just to check atom numbers and the like... )
            IF (hasdata) THEN
               CALL writebuffer(socket,"HAVEDATA    ",MSGLEN)
            ELSE
               CALL writebuffer(socket,"READY       ",MSGLEN)
            ENDIF
         ENDIF
         inet=swait(uwait,default_para_env%source, default_para_env%mepos)
         CALL mp_sync(default_para_env%group)
      ELSE IF (TRIM(header) == "POSDATA") THEN              
         IF (ionode) THEN        
            nread=readbuffer(socket, cellh, 9*8)
            nread=readbuffer(socket, cellih, 9*8)
            nread=readbuffer(socket, nat, 4)
            cellh=TRANSPOSE(cellh)
            cellih=TRANSPOSE(cellih)
         ENDIF
         CALL mp_bcast(cellh,default_para_env%source, default_para_env%group)
         CALL mp_bcast(cellih,default_para_env%source, default_para_env%group)
         CALL mp_bcast(nat,default_para_env%source, default_para_env%group)
         IF (.not.ALLOCATED(combuf)) ALLOCATE(combuf(3*nat))
         IF (ionode) nread=readbuffer(socket, combuf, nat*3*8)
         CALL mp_bcast(combuf,default_para_env%source, default_para_env%group)
         
         CALL force_env_get(force_env,subsys=subsys,error=error)
         IF (nat/=subsys%particles%n_els) WRITE(*,*) &
                " @DRIVER MODE: Uh-oh! Particle number mismatch between i-pi and cp2k input!"
         ii=0
         DO ip=1,subsys%particles%n_els
          DO idir=1,3
             ii=ii+1
             subsys%particles%els(ip)%r(idir)=combuf(ii)
          END DO
         END DO
         CALL init_cell(cpcell, hmat=cellh)
         CALL force_env_set_cell(force_env,cell=cpcell,error=error)
         
         CALL force_env_calc_energy_force(force_env,calc_force=.TRUE. ,error=error)
    
         IF (ionode) WRITE(*,*) " @ DRIVER MODE: Received positions "
         
         combuf=0
         ii=0
         DO ip=1,subsys%particles%n_els
          DO idir=1,3
             ii=ii+1
             combuf(ii)=subsys%particles%els(ip)%f(idir)
          END DO
         END DO         
         CALL force_env_get(force_env, potential_energy=pot, error=error)
         CALL force_env_get(force_env,cell=cpcell, virial=virial, error=error)
         vir = TRANSPOSE(virial%pv_virial)
         
         CALL external_control(should_stop,"DPI",globenv=globenv,error=error)
         IF (should_stop) EXIT
       
         hasdata=.TRUE.
      ELSE IF (TRIM(header)=="GETFORCE") THEN
         IF (ionode) WRITE(*,*) " @ DRIVER MODE: Returning v,forces,stress "
         IF (ionode) THEN     
            CALL writebuffer(socket,"FORCEREADY  ",MSGLEN)            
            CALL writebuffer(socket,pot,8)
            CALL writebuffer(socket,nat,4)            
            CALL writebuffer(socket,combuf,3*nat*8)
            CALL writebuffer(socket,vir,9*8)

            ! i-pi can also receive an arbitrary string, that will be printed out to the "extra" 
            ! trajectory file. this is useful if you want to return additional information, e.g.
            ! atomic charges, wannier centres, etc. one must return the number of characters, then
            ! the string. here we just send back zero characters.            
            nat=0
            CALL writebuffer(socket,nat,4)  ! writes out zero for the length of the "extra" field (not implemented yet!)
         ENDIF
         hasdata=.FALSE.
      ELSE 
         IF (ionode) WRITE(*,*) " @DRIVER MODE:  Socket disconnected, time to exit. "
         EXIT
      ENDIF
    ENDDO driver_loop  
    
  END SUBROUTINE run_driver
  
END MODULE ipi_driver