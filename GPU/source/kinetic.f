c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     #################################################################
c     ##                                                             ##
c     ##  subroutine kinetic  --  compute kinetic energy components  ##
c     ##                                                             ##
c     #################################################################
c
c
c     "kinetic" computes the total kinetic energy and kinetic energy
c     contributions to the pressure tensor by summing over velocities
c
c
#include "tinker_macro.h"
      subroutine kinetic (eksum,ekin,temp)
      use atmtyp
      use atoms
      use bath
      use domdec
      use group
      use mdstuf
      use moldyn
      use units
      use usage
      use mpi
      implicit none
      integer i,j,k,ierr,iglob
      integer start,stop
      real(r_p) eksum,value
      real(r_p) weigh,temp
      real(r_p) term
      real(r_p) ekin(3,3)
      real(r_p) inert(3,3)
c
!$acc data copyout(eksum,ekin)
!$acc&     present(use,glob,v)
!$acc&     async
c
c     zero out the total kinetic energy and its outer product
c
!$acc parallel loop collapse(2) async
      do j = 1, 3
         do k = 1, 3
            ekin(k,j) = 0.0_re_p
         end do
      end do
!$acc serial async
      eksum = 0.0_re_p
!$acc end serial
c
c     get the total kinetic energy and tensor for atomic sites
c
!$acc parallel loop async
      do i = 1, nloc
         iglob = glob(i)
         if (use(iglob)) then
!$acc loop seq collapse(2)
            do j = 1, 3
               do k = 1, 3
            term = 0.5_re_p * mass(iglob) / convert
                  value = term * v(j,iglob) * v(k,iglob)
!$acc atomic update
                  ekin(k,j) = ekin(k,j) + value
               end do
            end do
         end if
      end do

      if (nproc.ne.1) then
!$acc wait
!$acc host_data use_device(ekin)
         call MPI_ALLREDUCE(MPI_IN_PLACE,ekin,9,MPI_RPREC,MPI_SUM,
     $                      COMM_TINKER,ierr)
!$acc end host_data
      end if
!$acc serial async
      eksum = ekin(1,1) + ekin(2,2) + ekin(3,3)
!$acc end serial
!$acc update host(eta) async
!$acc wait
!$acc end data
c
      if (isobaric .and. barostat.eq.'BUSSI') then
         term = real(nfree,t_p)*gasconst*kelvin*taupres*taupres
         value = 0.5_re_p * term * eta * eta
         do j = 1, 3
            ekin(j,j) = ekin(j,j) + value/3.0_re_p
         end do
         eksum = eksum + value
      end if
c
c     set the instantaneous temperature from total kinetic energy
c
      temp = 2.0_re_p * eksum / (real(nfree,r_p) * gasconst)
      end
c
c
      subroutine kineticgpu (eksum,ekin,temp)
      use atmtyp
      use atoms
      use bath
      use domdec
      use energi ,only: calc_e
      use group
      use mdstuf
      use moldyn
      use units
      use usage
      use mpi
      implicit none
      integer i,j,k,ierr,iglob
      integer start,stop
      real(r_p) eksum,value
      real(r_p) weigh,temp
      real(r_p) term
      real(r_p) ekin(3,3)
      real(r_p) inert(3,3)
      real(r_p),save:: ekin11,ekin12,ekin13
      real(r_p),save:: ekin21,ekin22,ekin23
      real(r_p),save:: ekin31,ekin32,ekin33
      logical,save::f_in=.true.

      if (f_in) then
         f_in=.false.
         ekin11=0;ekin22=0;ekin33=0;
!$acc enter data copyin(ekin11,ekin22,ekin33)
      end if
c
!$acc host_data use_device(ekin,eksum,temp
!$acc&         )
c
c     get the total kinetic energy and tensor for atomic sites
c
!$acc parallel loop collapse(2) async
!$acc&         present(ekin11,ekin22,ekin33) default(present)
      do i = 1, nloc
         do j = 1, 3
            iglob = glob(i)
            if (use(iglob)) then
               term = 0.5_re_p * mass(iglob) / convert
               if (j.eq.1) then
                  ekin11 = ekin11 + real(term*v(1,iglob)*v(1,iglob),r_p)
                  !ekin21 = ekin21 + real(term*v(1,iglob)*v(2,iglob),r_p)
                  !ekin31 = ekin31 + real(term*v(1,iglob)*v(3,iglob),r_p)
               else if (j.eq.2) then
                  !ekin12 = ekin12 + real(term*v(2,iglob)*v(1,iglob),r_p)
                  ekin22 = ekin22 + real(term*v(2,iglob)*v(2,iglob),r_p)
                  !ekin32 = ekin32 + real(term*v(2,iglob)*v(3,iglob),r_p)
               else
                  !ekin13 = ekin13 + real(term*v(3,iglob)*v(1,iglob),r_p)
                  !ekin23 = ekin23 + real(term*v(3,iglob)*v(2,iglob),r_p)
                  ekin33 = ekin33 + real(term*v(3,iglob)*v(3,iglob),r_p)
               end if
            end if
         end do
      end do

!$acc serial async deviceptr(ekin,eksum,temp)
!$acc&       present(ekin11,ekin22,ekin33)
      ekin(1,1) = ekin11
      !ekin(2,1) = ekin21
      !ekin(3,1) = ekin31
      !ekin(1,2) = ekin12
      ekin(2,2) = ekin22
      !ekin(3,2) = ekin32
      !ekin(1,3) = ekin13
      !ekin(2,3) = ekin23
      ekin(3,3) = ekin33

      !---zero out the total kinetic energy and its outer product
      ekin11 = 0.0_re_p
      ekin22 = 0.0_re_p
      ekin33 = 0.0_re_p

      !---set the instantaneous temperature from total kinetic energy
      eksum = ekin(1,1) + ekin(2,2) + ekin(3,3)
      temp  = 2.0_re_p*real(eksum,r_p) / (real(nfree,r_p) * gasconst)
!$acc end serial

      if (nproc.ne.1) then
!$acc wait
         call MPI_ALLREDUCE(MPI_IN_PLACE,ekin,9,MPI_RPREC,MPI_SUM,
     &                      COMM_TINKER,ierr)
      end if
c
      if (isobaric.and.barostat.eq.'BUSSI') then
         term  = real(nfree,t_p)*gasconst*kelvin*taupres*taupres
!$acc serial async deviceptr(ekin)
         value = 0.5_re_p * term * eta * eta / 3.0
         ekin(1,1) = ekin(1,1) + value
         ekin(2,2) = ekin(2,2) + value
         ekin(3,3) = ekin(3,3) + value
 
         !---set the instantaneous temperature from total kinetic energy
         eksum = ekin(1,1) + ekin(2,2) + ekin(3,3)
         temp  = 2.0_re_p*real(eksum,r_p) / (real(nfree,r_p) * gasconst)
!$acc end serial
      else if (nproc.ne.1) then
         !---set the instantaneous temperature from total kinetic energy
!$acc serial async deviceptr(eksum,ekin,temp)
         eksum = ekin(1,1) + ekin(2,2) + ekin(3,3)
         temp  = 2.0_re_p*real(eksum,r_p) / (real(nfree,r_p) * gasconst)
!$acc end serial
      end if
c
!$acc end host_data
      end
