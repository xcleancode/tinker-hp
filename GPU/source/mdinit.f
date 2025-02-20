c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     ###############################################################
c     ##                                                           ##
c     ##  subroutine mdinit  --  initialize a dynamics trajectory  ##
c     ##                                                           ##
c     ###############################################################
c
c
c     "mdinit" initializes the velocities and accelerations
c     for a molecular dynamics trajectory, including restarts
c
c
#include "tinker_macro.h"
      subroutine mdinit(dt)
      use atmtyp
      use atomsMirror
      use bath
      use bound
      use colvars
      use couple
      use cutoff
      use deriv
      use domdec
      use energi
      use files
      use keys
      use freeze
      use group
      use inform
      use iounit
      use langevin
      use mamd
      use mdstate
      use mdstuf
      use mdstuf1 ,only: gpuAllocMdstuf1Data
      use molcul
      use moldyn
      use mpole
      use neigh
      use plumed
      use polpot
      use potent
      use polar
      use random_mod
      use tinMemory ,only: mipk
      use units 
      use uprior
      use utils
#ifdef _OPENACC
      use utilcu  ,only: cu_update_vir_switch
#endif
      use utilgpu ,only: prmem_requestm,rec_queue,rec_stream,mem_set
      use usage
      use virial
      implicit none
      integer i,j,idyn,iglob
      integer next
      integer lext,freeunit
      integer correc
      integer(mipk) siz_
      real(r_p) e
      real(r_p) speed
      real(t_p) vec(3)
      real(r_p) dt
      real(r_p), allocatable :: derivs(:,:)
      real(r_p), allocatable :: speedvec(:)
      real(r_p) eps,zero,oe6
      mdyn_rtyp zero_md
      logical exist,s_colvars
      character*7 ext
      character*20 keyword
      character*240 dynfile
      character*240 record
      character*240 string
      parameter(zero=0.0,zero_md=0,oe6=1d-6)

      interface
      subroutine maxwellgpu (mass,temper,nloc,max_result)
      integer  ,intent(in ):: nloc
      real(r_p),intent(in ):: mass(*)
      real(r_p),intent(in ):: temper
      real(r_p),intent(out):: max_result(*)
      end subroutine
      function maxwell (mass,temper)
      real(r_p) maxwell
      real(r_p) mass
      real(r_p) temper
      end function
      end interface
c
c     set default parameters for the dynamics trajectory
c
      integrate = 'VERLET'
      bmnmix    = 8
      nfree     = 0
      dorest    = .true.
      irest     = 1
      velsave   = .false.
      frcsave   = .false.
      uindsave  = .false.
      polpred   = 'ASPC'
#if (defined(SINGLE) || defined(MIXED))
      iprint =merge(5000,1000,n.lt.10000.or.(use_charge.and.n.lt.50000))
      eps    =  0.000001_ti_p
#else
      iprint = 100
      eps    =  0.00000001_re_p
#endif
c
c      set default for neighbor list update,
c
      if (.not.isothermal.and..not .isobaric) then  !Microcanonical (NVE)
c        reference = 2\AA buffer allows 30fs integration in double precision
c        reference = 0.7\AA buffer allows 10.5fs integration in mixed or single precision
         ineigup= max( 1,int(((real(lbuffer,r_p)*0.015_re_p)/dt)+1d-3) )
         call fetchkey('POLAR-EPS',poleps,oe6)
      else
c        reference = 2\AA buffer allows 40fs integration in double precision
c        reference = 0.7\AA buffer allows 14fs integration in mixed or single precision
         ineigup= max( 1,int(((real(lbuffer,r_p)*0.02_re_p)/dt)+1d-3) )
      end if
c
c     set default values for temperature and pressure control
c
      thermostat = 'BUSSI'
      tautemp    = 0.2_re_p
      collide    = 0.1_re_p
      barostat   = 'BERENDSEN'
      anisotrop  = .false.
      taupres    = 2.0_re_p
      compress   = 0.000046_re_p
      vbar       = 0.0_ti_p
      qbar       = 0.0_ti_p
      gbar       = 0.0_ti_p
      eta        = 0.0_re_p
      voltrial   = 20
      volmove    = 100.0_re_p
      volscale   = 'MOLECULAR'
c      volscale = 'ATOMIC'
      gamma      = 1.0_ti_p
! this variable seems to be useless
!!$acc update device(gamma)
      gammapiston = 20.0_re_p
      masspiston  = 100000.0_re_p
      virsave     = 0.0_re_p
      viramdD     = 0.0_re_p
!$acc update device(eta)
!$acc update device(vir,viramdD)
c
c     check for keywords containing any altered parameters
c
      do i = 1, nkey
         next = 1
         record = keyline(i)
         call gettext (record,keyword,next)
         call upcase (keyword)
         string = record(next:240)
         if (keyword(1:11) .eq. 'INTEGRATOR ') then
            call getword (record,integrate,next)
            call upcase (integrate)
         else if (keyword(1:14) .eq. 'BEEMAN-MIXING ') then
            read (string,*,err=10,end=10)  bmnmix
c        else if (keyword(1:16) .eq. 'DEGREES-FREEDOM ') then
c           read (string,*,err=10,end=10)  nfree
         else if (keyword(1:15) .eq. 'REMOVE-INERTIA ') then
            read (string,*,err=10,end=10)  irest
         else if (keyword(1:14) .eq. 'SAVE-VELOCITY ') then
            velsave = .true.
         else if (keyword(1:11) .eq. 'SAVE-FORCE ') then
            frcsave = .true.
         else if (keyword(1:13) .eq. 'SAVE-INDUCED ') then
            uindsave = .true.
         else if (keyword(1:11) .eq. 'THERMOSTAT ') then
            call getword (record,thermostat,next)
            call upcase (thermostat)
         else if (keyword(1:16) .eq. 'TAU-TEMPERATURE ') then
            read (string,*,err=10,end=10)  tautemp
         else if (keyword(1:10) .eq. 'COLLISION ') then
            read (string,*,err=10,end=10)  collide
         else if (keyword(1:9) .eq. 'BAROSTAT ') then
            call getword (record,barostat,next)
            call upcase (barostat)
         else if (keyword(1:15) .eq. 'ANISO-PRESSURE ') then
            anisotrop = .true.
         else if (keyword(1:13) .eq. 'TAU-PRESSURE ') then
            read (string,*,err=10,end=10)  taupres
         else if (keyword(1:9) .eq. 'COMPRESS ') then
            read (string,*,err=10,end=10)  compress
         else if (keyword(1:13) .eq. 'VOLUME-TRIAL ') then
            read (string,*,err=10,end=10)  voltrial
         else if (keyword(1:12) .eq. 'VOLUME-MOVE ') then
            read (string,*,err=10,end=10)  volmove
         else if (keyword(1:13) .eq. 'VOLUME-SCALE ') then
            call getword (record,volscale,next)
            call upcase (volscale)
         else if (keyword(1:9) .eq. 'PRINTOUT ') then
            read (string,*,err=10,end=10)  iprint
            if (iprint.eq.1) iprint=100
         else if (keyword(1:14) .eq. 'NLUPDATE ') then
            read (string,*,err=10,end=10) idyn
            if (idyn.gt.ineigup) then
 09     format(/,' WARNING !!! Nb-list update interval(',I0,') is'
     &  ,' too high compared to the buffer size(',F4.2,'Ang)',/
     &  ,' WARNING   - Your dynamic may results unstable !',/
     &  ,' PROPOSAL  - Please set nlupdate value in keyfile'
     &  ,' at least under (',I0,') or comment the instruction !',/)
               write(*,09) idyn,lbuffer,ineigup
            endif
            ineigup = idyn
            auto_lst = .false.
         else if (keyword(1:9) .eq. 'FRICTION ') then
            read (string,*,err=10,end=10) gamma
         else if (keyword(1:15) .eq. 'FRICTIONPISTON ') then
            read (string,*,err=10,end=10) gammapiston
         else if (keyword(1:12) .eq. 'MASSPISTON ') then
            read (string,*,err=10,end=10) masspiston
         else if (keyword(1:12) .eq. 'VIRIALTERM ') then
            use_virial=.true.
         else if (keyword(1:14) .eq. 'TRACK-MDSTATE ') then
            track_mds=.true.
         else if (keyword(1:7) .eq. 'PLUMED ') then
            lplumed = .true.
            call getword(record,pl_input ,next)
            call getword(record,pl_output,next)
         end if
   10    continue
      end do
c
c     enforce the use of monte-carlo barostat with the TCG family of solvers
c
      if ((isobaric).and.(polalg.eq.3)) then
        barostat = 'MONTECARLO' 
        if (rank.eq.0) write(iout,*)'enforcing the use of Monte Carlo ',
     $    'Barostat with TCG'
      end if
c
c     enforce the use of baoabpiston integrator with Langevin Piston barostat
c
      if (isobaric.and.barostat.eq.'LANGEVIN') then
        use_piston = .TRUE.
        call initialize_langevin_piston()
      end if
c
c     default time steps for respa and respa1 integrators
c
      if ((integrate.eq.'RESPA').or.(integrate.eq.'BAOABRESPA')) then
        dshort = 0.001
      else if ((integrate.eq.'RESPA1').or.(integrate.eq.'BAOABRESPA1'))
     $  then
        dinter = 0.002
        dshort = 0.00025
      end if

c
c     keywords for respa and respa1 integrators
c
      do i = 1, nkey
         next = 1
         record = keyline(i)
         call gettext (record,keyword,next)
         call upcase (keyword)
         string = record(next:240)
         if (keyword(1:7) .eq. 'DSHORT ') then
            read (string,*,err=20,end=20) dshort
         else if (keyword(1:7) .eq. 'DINTER ') then
            read (string,*,err=20,end=20) dinter
         end if
   20    continue
      end do
c
      if ((integrate.eq.'RESPA').or.(integrate.eq.'BAOABRESPA')) then
        nalt = int(dt/(dshort+eps)) + 1
        dshort = real(nalt,r_p)
      else if ((integrate.eq.'RESPA1').or.(integrate.eq.'BAOABRESPA1'))
     $  then
        nalt   = int(dt/(dinter+eps)) + 1
        nalt2  = int(dinter/(dshort+eps)) + 1
        dinter = real(nalt,r_p)
        dshort = real(nalt2,r_p)
      end if
c
c     make sure all atoms or groups have a nonzero mass
c
      correc=0
      do i = 1, n
         if (use(i) .and. mass(i).le.0.0_re_p) then
            correc = correc+1
            mass(i) = 1.0_re_p
            totmass = totmass + 1.0_re_p
            write (iout,30)  i
   30       format (/,' MDINIT  --  Warning, Mass of Atom',i6,
     &                 ' Set to 1.0 for Dynamics')
         end if
      end do
      if (correc.gt.0) then
!$acc update device(mass)
      end if
c
c     enforce use of velocity Verlet with Andersen thermostat
c
      if (thermostat .eq. 'ANDERSEN') then
         if (integrate .eq. 'BEEMAN')  integrate = 'VERLET'
      end if
c
c     check for use of Monte Carlo barostat with constraints
c
      if (barostat.eq.'MONTECARLO' .and. volscale.eq.'ATOMIC') then
         if (use_rattle) then
            write (iout,40)
   40       format (/,' MDINIT  --  Atom-based Monte Carlo',
     &                 ' Barostat Incompatible with RATTLE')
            call fatal
         end if
      end if
c
c     Plumed feature initialisation
c
      if (lplumed) call plumed_init(dt)
c
c     nblist initialization for respa-n integrators
c
      if ((integrate.eq.'RESPA1').or.(integrate.eq.'BAOABRESPA1')) 
     $  then
        use_shortmlist = use_mlist
        use_shortclist = use_clist
        use_shortvlist = use_vlist
        use_shortdlist = use_dlist
      end if
c    
c     initialization for Langevin dynamics
c
      if ((integrate .eq. 'BBK').or.(integrate.eq.'BAOAB').or.
     $ (integrate.eq.'BAOABRESPA').or.(integrate.eq.'BAOABRESPA1').or.
     $ (integrate.eq.'BAOABPISTON'))
     $   then
         if (.not.(isothermal)) then
            if (rank.eq.0) then
             write(*,*) 'Langevin integrators only available with NVT',
     $ ' or NPT ensembles'
            end if
           __TINKER_FATAL__
         end if
         thermostat = 'LANGEVIN'
         if (allocated(Rn)) then
!$acc exit data delete(Rn) async
            deallocate (Rn)
         end if
         allocate (Rn(3,nloc))
!$acc enter data create(Rn) async
         do i = 1, nloc
           do j = 1, 3
             Rn(j,i) = normal()
           end do
         end do
!$acc update device(Rn) async
         if (track_mds) call init_rand_engine
         dorest = .false.
         if (barostat.eq.'LANGEVIN'.and.integrate.eq.'BAOABRESPA1') then
 39      format(/," --- Tinker-HP : Alert! "
     &   ,/,6x,'Langevin Barostat cannot be used with BAOABRESPA1 '
     &   ,'integrator')
            write(0,39); __TINKER_FATAL__
         end if
      else if (barostat.eq.'LANGEVIN') then
 41   format(/," --- Tinker-HP : Alert! "
     &   ,/,6x,'Langevin Barostat can only be use with Langevin '
     &   ,'integrators like BAOABRESPA')
         write(0,41); __TINKER_FATAL__
      end if
c
c     Initiate Track of MD_state
c     ! Do not move that call upstream
c
      if (app_id.eq.dynamic_a) call mds_init
c
c     Colvars Feature Initialization
c
      call colvars_init(dt)
c
c     lambda dynamic initialization
c
      if (use_lambdadyn.or.use_osrw) then
         if (use_colvars) then
            call def_lambdadyn_init
         else
 42   format(/," --- Tinker-HP : ",
     &,"cannot perform lambda dynamic without colvar",/,6x
     &,"PROPOSAL : Either remove -lambdadyn- keyword or activate "
     &,"colvar feature")
            write(0,42)
            !use_lambdadyn = .false.
            __TINKER_FATAL__
         end if
      end if
c
c     check wether or not to compute virial
c
      if (isobaric.and.barostat.eq.'BERENDSEN'.or.use_piston) 
     &   use_virial=.true.
#ifdef _OPENACC
      call cu_update_vir_switch(use_virial)
      if (use_virial.and.use_polar.and.
     &   (integrate.eq.'RESPA1'.or.integrate.eq.'BAOABRESPA1'))
     &   then
         call detach_mpolar_pointer
         use_mpolar_ker = .false.
      end if
#endif
c
c     decide whether to remove center of mass motion
c
      if (irest.eq.0.or.nuse.ne.n)  dorest = .false.
      if (isothermal.and.thermostat.eq.'ANDERSEN') dorest = .false.
      if (use_smd_velconst.or.use_smd_forconst.or.
     &    use_amd_dih.or.use_amd_ene.or.use_amd_wat1) dorest = .false.
      !FIXME remain case where integrate .eq. BAOAB* for dorest
c
c     set the number of degrees of freedom for the system
c
      nfree = 3 * nuse
      if (dorest) then
         if (use_bounds) then
            nfree = nfree - 3
         else
            nfree = nfree - 6
         end if
      end if
      if (use_rattle) then
         nfree = nfree - nrat
         do i = 1, nratx
            nfree = nfree - kratx(i)
         end do
      end if
c
c     check for a nonzero number of degrees of freedom
c
      if (nfree .lt. 0)  nfree = 0
      if (debug) then
         write (iout,50)  nfree
   50    format (/,' Number of Degrees of Freedom for Dynamics :',i10)
      end if
      if (nfree .eq. 0) then
         write (iout,60)
   60    format (/,' MDINIT  --  No Degrees of Freedom for Dynamics')
         call fatal
      end if
c
      if (tinkerdebug.gt.0.and.rank.eq.0) call info_dyn
      call up_fuse_bonded  ! Update fuse_bonded
c
c     Reinterpret force buffer shape (3,nloc) --> (nloc,3)
c
      if (fdebs_l.and.use_bond.and.fuse_bonded.and..not.use_strtor
     &   .and..not.use_geom.and..not.use_angang.and..not.use_opdist
     &   .and..not.use_mlpot
     &   .and..not.lplumed.and..not.use_colvars) then
         tdes_l=.true.
         if (tinkerdebug.gt.0.and.rank.eq.0) then
            print*
            print*,'--- Reshape force to (n,3) ---'
         end if
      end if

      ! Create device Data for mdstuf1
      call gpuAllocMdstuf1Data

      !Disable COLVARS until end of routine
        s_colvars = use_colvars
      use_colvars = .false.
c
c     try to restart using prior velocities and accelerations
c
      if (ms(1)%lddat) then
         dynfile = ms(1)%dumpdyn
         exist   = .true.
      else
         dynfile = filename(1:leng)//'.dyn'
         inquire (file=dynfile,exist=exist)
      end if

      if (exist) then
 32   format(/," --- Tinker-HP: loading restart file for ",A,
     &         " system --- ")
         if (verbose.and.rank.eq.0) then
            if (ms(1)%lddat) then
               write(*,32) trim(dynfile)
            else
               write(*,32) filename(1:leng)
            end if
         end if
         idyn = freeunit ()
         open (unit=idyn,file=dynfile,status='old')
         rewind (unit=idyn)
         call readdyn (idyn)
         close (unit=idyn)
c
c     Do the domain decomposition
c
         call ddpme3d
         call reinitnl(0)
         call reassignpme(.false.)
         call mechanicstep(0)
         call allocstep
         call nblist(0)

         if (isobaric.and.barostat.eq.'LANGEVIN') then
            use_piston = .TRUE.
            call initialize_langevin_piston()
         end if
c
c     set velocities and fast/slow accelerations for RESPA method
c
      else if ((integrate.eq.'RESPA').or.
     $   (integrate.eq.'BAOABRESPA')) then

 33   format (/," --- Tinker-HP: No Restart file was found for ",A
     $       ," system",/,16x,"Dynamic Initialization")
         if (verbose.and.rank.eq.0) write(*,33) filename(1:leng)
c
c     Do the domain decomposition
c
         call ddpme3d
         call reinitnl(0)
         call reassignpme(.false.)
         call mechanicstep(0)
         call nblist(0)
         allocate (derivs(3,nbloc))
!$acc data create(derivs,e)
!$acc&     present(glob,mass,v,a,samplevec) async
c
         siz_=3*nbloc
         call mem_set(derivs,zero,siz_,rec_stream)
         call allocsteprespa(.false.)
         call gradslow (e,derivs)
         call comm_forces(derivs,cNBond)
         if (ftot_l) then
            call get_ftot (derivs,nbloc)
            siz_ = dr_stride3
            call mem_set( de_tot,zero_md,siz_,rec_stream)
         end if

         if(deb_Force) call info_forces(cNBond)
         if(deb_Energy)call info_energy(rank)
#ifdef _OPENACC
         if (.not.host_rand_platform) then
            allocate(speedvec(nloc))
!$acc data create(speedvec) async
            call rand_unitgpu(samplevec(1),nloc)
            call maxwellgpu(mass,kelvin,nloc,speedvec)
!$acc parallel loop collapse(2) async
            do i = 1, nloc
               do j = 1, 3
                  iglob = glob(i)
                  if (use(iglob)) then
                     v(j,iglob) = speedvec(i)
     &                          * real(samplevec(3*(i-1)+j),r_p)
                     a(j,iglob) = -convert * derivs(j,i) / mass(iglob)
                  else
                     v(j,iglob)    = 0.0_re_p
                     a(j,iglob)    = 0.0_re_p
                     aalt(j,iglob) = 0.0_re_p
                  end if
               end do
            end do
!$acc end data
            deallocate(speedvec)
         end if
#endif
         if (host_rand_platform) then
!$acc update host(v,a,derivs) async
!$acc wait
            do i = 1, nloc
               iglob = glob(i)
               if (use(iglob)) then
                  speed = maxwell (mass(iglob),kelvin)
                  call ranvec (vec)
                  do j = 1, 3
                     v(j,iglob) = speed * real(vec(j),r_p)
                     a(j,iglob) = -convert * derivs(j,i) / mass(iglob)
                  end do
               else
                  do j = 1, 3
                     v(j,iglob)    = 0.0_re_p
                     a(j,iglob)    = 0.0_re_p
                     aalt(j,iglob) = 0.0_re_p
                  end do
               end if
            end do
!$acc update device(v,a,aalt) async
         end if
         siz_=3*nbloc
         call mem_set(derivs,zero,siz_,rec_stream)
         call allocsteprespa(.true.)
         call gradfast (e,derivs)
         call comm_forces(derivs,cBond)
         if (ftot_l) then
            call get_ftot (derivs,nbloc)
            siz_ = dr_stride3
            call mem_set( de_tot,zero_md,siz_,rec_stream)
         end if

         !Debug Info
         if(deb_Force) call info_forces(cBond)
         if(deb_Energy)call info_energy(rank)

!$acc parallel loop collapse(2) async
         do i = 1, nloc
            do j = 1, 3
               iglob = glob(i)
               if (use(iglob)) then
                  aalt(j,iglob) = -convert * derivs(j,i) / mass(iglob)
               else
                  v(j,iglob)    = 0.0_re_p
                  a(j,iglob)    = 0.0_re_p
                  aalt(j,iglob) = 0.0_re_p
               end if
            end do
         end do
!$acc end data
         deallocate (derivs)
         if (nuse .eq. n)  call mdrestgpu (0)
c
c     set velocities and fast/inter/slow accelerations for RESPA-n method
c
      else if ((integrate.eq.'RESPA1').or.(integrate.eq.'BAOABRESPA1'))
     $ then

         if (verbose.and.rank.eq.0) write(*,33) filename(1:leng)
c
c     Do the domain decomposition
c
         call ddpme3d
         call reinitnl(0)
         call reassignpme(.false.)
         call mechanicstep(0)
         call detach_mpolar_pointer
         call nblist(0)
         allocate (derivs(3,nbloc))
!$acc data create(derivs,e) async
!$acc&     present(aalt2,mass,aalt,glob,v,a)
         siz_=3*nbloc
         call mem_set(derivs,zero,siz_,rec_stream)
         call allocsteprespa(.false.)

         call gradfast(e,derivs)
         call comm_forces(derivs,cBond)
         if (ftot_l) call get_ftot (derivs,nbloc)

         !Debug info
         if(deb_Force) call info_forces(cBond)
!$acc parallel loop collapse(2) async
         do i = 1, nloc
            do j = 1, 3
               iglob = glob(i)
               if (use(iglob)) then
                  aalt2(j,iglob) = -convert *
     $               derivs(j,i) / mass(iglob)
               else
                  aalt2(j,iglob) = 0.0_re_p
               end if
            end do
         end do

         call set_to_zero1m(derivs,3*nbloc,rec_queue)
         call gradint(e,derivs)
         call comm_forces(derivs,cSNBond)
         if (ftot_l) call get_ftot (derivs,nbloc)

         !Debug info
         if(deb_Force) call info_forces(cSNBond)

!$acc parallel loop collapse(2) async
         do i = 1, nloc
            do j = 1, 3
               iglob = glob(i)
               if (use(iglob)) then
                  aalt(j,iglob) = -convert *
     $                derivs(j,i) / mass(iglob)
               else
                  aalt(j,iglob) = 0.0_re_p
               end if
            end do
         end do

         call set_to_zero1m(derivs,3*nbloc,rec_queue)
         call gradslow(e,derivs)
         call comm_forces(derivs,cNBond)
         if (ftot_l) then
            call get_ftot (derivs,nbloc)
            siz_ = dr_stride3
            call mem_set( de_tot,zero_md,siz_,rec_stream)
         end if

         if(deb_Force) call info_forces(cNBond)
#ifdef _OPENACC
         if (.not.host_rand_platform) then
            allocate(speedvec(nloc))
!$acc data create(speedvec) async
            call rand_unitgpu(samplevec(1),nloc)
            call maxwellgpu(mass,kelvin,nloc,speedvec)
!$acc parallel loop collapse(2) async
            do i = 1, nloc
               do j = 1, 3
                  iglob = glob(i)
                  if (use(iglob)) then
                     v(j,iglob) = speedvec(i)
     &                          * real(samplevec(3*(i-1)+j),r_p)
                     a(j,iglob) = -convert * derivs(j,i) / mass(iglob)
                  else
                     v(j,iglob)    = 0.0_re_p
                     a(j,iglob)    = 0.0_re_p
                  end if
               end do
            end do
!$acc end data
            deallocate(speedvec)
         end if
#endif
         if (host_rand_platform) then
!$acc update host(v,a,derivs) async
!$acc wait
         do i = 1, nloc
            iglob = glob(i)
            if (use(iglob)) then
               speed = maxwell (mass(iglob),kelvin)
               call ranvec (vec)
               do j = 1, 3
                  v(j,iglob) = speed * real(vec(j),r_p)
                  a(j,iglob) = -convert * derivs(j,i) / mass(iglob)
               end do
            else
               do j = 1, 3
                  v(j,iglob) = 0.0_re_p
                  a(j,iglob) = 0.0_re_p
               end do
            end if
         end do
!$acc update device(v,a) async
         end if

!$acc end data
         deallocate (derivs)
         if (nuse .eq. n)  call mdrestgpu (0)

      else
         if (verbose.and.rank.eq.0) write(*,33) filename(1:leng)
c
c     Do the domain decomposition
c
         call ddpme3d
         call reinitnl(0)
         call reassignpme(.false.)
         call mechanicstep(0)
         call nblist(0)
c
c     set velocities and accelerations for cartesian dynamics
c
         allocate (derivs(3,nbloc))
!$acc data create(e,derivs)
!$acc&     present(glob,mass,v,a,samplevec)
c
         siz_=3*nbloc
         call mem_set(derivs,zero,siz_,rec_stream)
         call allocstep
         call gradient (e,derivs)
         call comm_forces(derivs,cNBond)
         if (ftot_l) then
            call get_ftot (derivs,nbloc)
            siz_ = dr_stride3
            call mem_set( de_tot,zero_md,siz_,rec_stream)
         end if

         ! Debug informations
         if(deb_Energy) call info_energy(rank)
         if(deb_Force)  call info_forces(cDef)
         if (nproc.eq.1.and.tinkerdebug.eq.64) call prtEForces(derivs,e)
c
#ifdef _OPENACC
         if (.not.host_rand_platform) then
            allocate(speedvec(nloc))
!$acc data create(speedvec) async
            call rand_unitgpu(samplevec(1),nloc)
            call maxwellgpu(mass,kelvin,nloc,speedvec)
!$acc parallel loop collapse(2) async
            do i = 1, nloc
               do j = 1, 3
                  iglob = glob(i)
                  if (use(iglob)) then
                     v(j,iglob) = speedvec(i) 
     &                          * real(samplevec(3*(i-1)+j),r_p)
                     a(j,iglob) = -convert * derivs(j,i) / mass(iglob)
                     aalt(j,iglob) = a(j,iglob)
                  else
                     v(j,iglob)    = 0.0_re_p
                     a(j,iglob)    = 0.0_re_p
                     aalt(j,iglob) = 0.0_re_p
                  end if
               end do
            end do
!$acc end data
            deallocate(speedvec)
         end if
#endif
         if (host_rand_platform) then
!$acc wait
!$acc update host(glob,derivs,a)
            do i = 1, nloc
               iglob = glob(i)
               if (use(iglob)) then
                  speed = maxwell (mass(iglob),kelvin)
                  call ranvec (vec)
                  do j = 1, 3
                     v(j,iglob) = speed * real(vec(j),r_p)
                     a(j,iglob) = -convert * derivs(j,i) / mass(iglob)
                     aalt(j,iglob) = a(j,iglob)
                  end do
               else
                  do j = 1, 3
                     v(j,iglob)    = 0.0_re_p
                     a(j,iglob)    = 0.0_re_p
                     aalt(j,iglob) = 0.0_re_p
                  end do
               end if
            end do
!$acc update device(v,a,aalt)
         end if
!$acc end data
         deallocate (derivs)
         if (nuse .eq. n)  call mdrestgpu (0)
      end if
c
      if (.not.exist) then
         if (track_mds) call init_rand_engine
         if (track_mds) call reset_curand_seed
      end if
c
c     check for any prior dynamics coordinate sets
c
      i = 0
      exist = .true.
      do while (exist)
         i = i + 1
         lext = 3
         call numeral (i,ext,lext)
         dynfile = filename(1:leng)//'.'//ext(1:lext)
         inquire (file=dynfile,exist=exist)
         if (.not.exist .and. i.lt.100) then
            lext = 2
            call numeral (i,ext,lext)
            dynfile = filename(1:leng)//'.'//ext(1:lext)
            inquire (file=dynfile,exist=exist)
         end if
         if (.not.exist .and. i.lt.10) then
            lext = 1
            call numeral (i,ext,lext)
            dynfile = filename(1:leng)//'.'//ext(1:lext)
            inquire (file=dynfile,exist=exist)
         end if
      end do
      nprior = i - 1
c
c     Re-Enable COLVARS if necessary
c
      use_colvars = s_colvars
      end
c
      subroutine info_atoms
      use atoms ,only: n
      use angang,only: nangang
      use angle ,only: nangle
      use bitor ,only: nbitor
      use bond  ,only: nbond
      use bound ,only: use_polymer
      use tors  ,only: ntors
      implicit none
 
 543  format (A15,I12)

      print 543, "n",n
      print 543, "nangle",nangle
      print 543, "ntors",ntors
      print 543, "nbitor",nbitor
      print 543, "nangang",nangang
      end subroutine

      ! Update fuse_bonded flag
      subroutine up_fuse_bonded
      use bound
      use group
      use inform
      use keys   ,only: fetchkey
      use potent
      use virial
      use sizes  ,only: tinkerdebug
      implicit none
      logical auth

#ifdef _OPENACC
      call fetchkey('FUSE-BONDED',auth,.true.)
      if (tinkerdebug.gt.0.and..not.auth)
     &   print*, ' KEY! disable fuse bonded'

      if (auth.and..not.deb_Energy.and..not.use_polymer.and..not.
     &    use_group.and.
     &   (use_bond.or.use_urey.or.use_opbend.or.use_strbnd.or.use_angle
     &.or.use_tors.or.use_pitors.or.use_tortor
     &.or.use_improp.or.use_imptor)) then
         fuse_bonded=.true.
      else
         fuse_bonded=.false.
      end if
#endif
      end subroutine
