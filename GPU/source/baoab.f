c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     ######################################################################
c     ##                                                                  ##
c     ##  subroutine baoab  --  BAOAB Langevin molecular dynamics step    ##
c     ##                                                                  ##
c     ######################################################################
c
c
c     "baoab" performs a single molecular dynamics time step
c     via the BAOAB recursion formula
c
c     literature reference:
c
c     Efficient molecular dynamics using geodesic integration 
c     and solvent-solute splitting B. Leimkuhler and C. Matthews,
c     Proceedings of the Royal Society A, 472: 20160138, 2016
c
c
#include "tinker_macro.h"
      subroutine baoab (istep,dt)
      use atmtyp
      use atomsMirror
      use bath
      use cutoff
      use domdec
      use deriv    ,only:info_forces,cDef,ftot_l,comm_forces
      use energi   ,only: info_energy,calc_e,chk_energy_fluct
      use freeze
      use inform
      use langevin
      use mdstuf
      use mdstuf1
      use moldyn
      use mpi
      use random_mod
      use timestat
      use tinMemory,only: prmem_requestm
      use tinheader,only: re_p
      use units
      use usage
      use utilbaoab
      use utils    ,only: set_to_zero1m
      use utilgpu  ,only: rec_queue,def_queue
      use virial
      implicit none
      integer  ,intent(in):: istep
      real(r_p),intent(in):: dt
      integer i,j,iglob
      real(r_p) dt_2

      dt_2 = 0.5_re_p*dt

      if (istep.eq.1) then
         if (use_piston) pres = atmsph
         call set_langevin_thermostat_coeff(dt)
      end if

      if (use_piston) call apply_b_piston(dt_2,pres)
c
c     find quarter step velocities and half step positions via BAOAB recursion
c
      call integrate_vel( a,dt_2 )
c
      if (use_rattle) then
         call rattle2(dt)
         call save_atoms_pos
      end if
c
      if (use_piston) then
         call apply_a_piston(dt_2,istep,.true.)
         call apply_o_piston(dt)
      else
         call integrate_pos( dt_2 )
      end if
c
      if (use_rattle) call rattle (dt_2)
      if (use_rattle) call rattle2(dt_2)
c
      call apply_langevin_thermostat
c
      if (use_rattle) call rattle2(dt_2)
      if (use_rattle) call save_atoms_pos
c
c     find full step positions via BAOAB recursion
c
      if(use_piston) then
         call apply_a_piston(dt_2,istep,.TRUE.)
      else
         call integrate_pos( dt_2 )
      end if
c
      if (use_rattle) call rattle (dt_2)
      if (use_rattle) call rattle2(dt_2)
c
c     Reassign the particules that have changed of domain
c
c     -> real space
      call reassign
c
c     -> reciprocal space
      call reassignpme(.false.)
c
c     communicate positions
c
      call commpos
      call commposrec
c
      if (.not.ftot_l) then
         call prmem_requestm(derivs,3,nbloc,async=.true.)
         call set_to_zero1m(derivs,3*nbloc,rec_queue)
      end if
c
      call reinitnl(istep)
c
      call mechanicstep(istep)
c
      call allocstep
c
c     rebuild the neighbor lists
c
      if (use_list) call nblist(istep)
c
c     get the potential energy and atomic forces
c
      call gradient (epot,derivs)
c
c     MPI : get total energy
c
      call reduceen(epot)
c
c     communicate forces
c
      call comm_forces( derivs )
c
c     aMD/GaMD contributions
c
      call aMD (derivs,epot)
c
c     Debug print information
c
      if (deb_Energy) call info_energy(rank)
      if (deb_Force)  call info_forces(cDef)
      if (deb_Atom)   call info_minmax_pva
      if (abort)      call emergency_save
      if (abort)      __TINKER_FATAL__
c
c     use Newton's second law to get the next accelerations;
c     find the full-step velocities using the BAOAB recursion
c
      call integrate_vel(derivs,a,dt_2)
c
c     find the constraint-corrected full-step velocities
c
      if (use_rattle)  call rattle2 (dt)
c
      call temper   (dt,eksum,ekin,temp)
      call pressure (dt,ekin,pres,stress,istep)
c
c     make half-step temperature and pressure corrections
c
      call pressure2 (epot,temp)
c
c     total energy is sum of kinetic and potential energies
c
      if (calc_e) then
!$acc serial present(epot,eksum,etot) async
         etot = eksum + epot
!$acc end serial
      end if
c
c     compute statistics and save trajectory for this step
c
      call mdstat (istep,dt,etot,epot,eksum,temp,pres)
      call mdsave (istep,dt,epot)
      call mdrestgpu (istep)

      if (use_piston) then
!$acc update host(pres) async
!$acc wait
         call apply_b_piston(dt_2,pres)
      endif

      end
