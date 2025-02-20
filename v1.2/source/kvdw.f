c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     ###############################################################
c     ##                                                           ##
c     ##  subroutine kvdw  --  van der Waals parameter assignment  ##
c     ##                                                           ##
c     ###############################################################
c
c
c     "kvdw" assigns the parameters to be used in computing the
c     van der Waals interactions and processes any new or changed
c     values for these parameters
c
c
      subroutine kvdw(init,istep)
      use atmlst
      use atmtyp
      use atoms
      use couple
      use cutoff
      use domdec
      use fields
      use keys
      use inform
      use iounit
      use khbond
      use kvdwpr
      use kvdws
      use math
      use merck
      use neigh
      use potent
      use vdw
      use vdwpot
      implicit none
      integer istep,modnl,ierr
      integer i,k,it
      integer ia,ib,next
      integer size,number
      integer iglob,vdwcount,iproc
      real*8 rd,ep,rdn,gik
      real*8, allocatable :: srad(:)
      real*8, allocatable :: srad4(:)
      real*8, allocatable :: seps(:)
      real*8, allocatable :: seps4(:)
      real*8 d
      logical header
      character*4 pa,pb
      character*8 blank,pt
      character*20 keyword
      character*240 record
      character*240 string
      logical init
c
      blank = '        '
      if (init) then
c
c       process keywords containing van der Waals parameters
c
        header = .true.
        do i = 1, nkey
           next = 1
           record = keyline(i)
           call gettext (record,keyword,next)
           call upcase (keyword)
           if (keyword(1:4) .eq. 'VDW ') then
              call getnumb (record,k,next)
              if (k.ge.1 .and. k.le.maxclass) then
                 rd = rad(k)
                 ep = eps(k)
                 rdn = reduct(k)
                 string = record(next:240)
                 read (string,*,err=10,end=10)  rd,ep,rdn
   10            continue
                 if (header .and. .not.silent) then
                    header = .false.
                    if (vdwindex .eq. 'CLASS') then
                     if (rank.eq.0) write (iout,20)
   20                format (/,' Additional van der Waals Parameters :',
     &                      //,5x,'Atom Class',10x,'Size',6x,
     &                            'Epsilon',5x,'Reduction',/)
                    else
                     if (rank.eq.0) write (iout,30)
   30                format (/,' Additional van der Waals Parameters :',
     &                         //,5x,'Atom Type',11x,'Size',6x,
     &                            'Epsilon',5x,'Reduction',/)
                    end if
                 end if
                 rad(k) = rd
                 eps(k) = ep
                 reduct(k) = rdn
                 if (.not. silent) then
                    if (rank.eq.0) write (iout,40)  k,rd,ep,rdn
   40               format (4x,i6,8x,2f12.4,f12.3)
                 end if
              else if (k .gt. maxclass) then
                 if (rank.eq.0) write (iout,50)  maxclass
   50            format (/,' KVDW  --  Only Atom Classes through',i4,
     &                      ' are Allowed')
                 abort = .true.
              end if
           end if
        end do
c
c       process keywords containing 1-4 van der Waals parameters
c
        header = .true.
        do i = 1, nkey
           next = 1
           record = keyline(i)
           call gettext (record,keyword,next)
           call upcase (keyword)
           if (keyword(1:6) .eq. 'VDW14 ') then
              call getnumb (record,k,next)
              if (k.ge.1 .and. k.le.maxclass) then
                 rd = rad4(k)
                 ep = eps4(k)
                 string = record(next:240)
                 read (string,*,err=60,end=60)  rd,ep
   60            continue
                 if (header .and. .not.silent) then
                    header = .false.
                    if (vdwindex .eq. 'CLASS') then
                       if (rank.eq.0) write (iout,70)
   70                  format (/,' Additional 1-4 van der Waals',
     &                            ' Parameters :',
     &                         //,5x,'Atom Class',10x,'Size',6x,
     &                            'Epsilon',/)
                    else
                       if (rank.eq.0) write (iout,80)
   80                  format (/,' Additional 1-4 van der Waals',
     &                            ' Parameters :',
     &                         //,5x,'Atom Type',11x,'Size',6x,
     &                            'Epsilon',/)
                    end if
                 end if
                 rad4(k) = rd
                 eps4(k) = ep
                 if (.not. silent) then
                    if (rank.eq.0) write (iout,90)  k,rd,ep
   90               format (4x,i6,8x,2f12.4)
                 end if
              else if (k .gt. maxclass) then
                 if (rank.eq.0) write (iout,100)  maxclass
  100            format (/,' KVDW  --  Only Atom Classes through',i4,
     &                      ' are Allowed')
                 abort = .true.
              end if
           end if
        end do
c
c       process keywords containing specific pair vdw parameters
c
        header = .true.
        do i = 1, nkey
           next = 1
           record = keyline(i)
           call gettext (record,keyword,next)
           call upcase (keyword)
           if (keyword(1:6) .eq. 'VDWPR ') then
              ia = 0
              ib = 0
              rd = 0.0d0
              ep = 0.0d0
              string = record(next:240)
              read (string,*,err=150,end=150)  ia,ib,rd,ep
              if (header .and. .not.silent) then
                 header = .false.
                 if (vdwindex .eq. 'CLASS') then
                    if (rank.eq.0) write (iout,110)
  110               format (/,' Additional van der Waals Parameters',
     &                         ' for Specific Pairs :',
     &                      //,5x,'Atom Classes',6x,'Size Sum',
     &                         4x,'Epsilon',/)
                 else
                    if (rank.eq.0) write (iout,120)
  120               format (/,' Additional van der Waals Parameters',
     &                         ' for Specific Pairs :',
     &                      //,5x,'Atom Types',8x,'Size Sum',
     &                         4x,'Epsilon',/)
                 end if
              end if
              if (.not. silent) then
                 if (rank.eq.0) write (iout,130)  ia,ib,rd,ep
  130            format (6x,2i4,4x,2f12.4)
              end if
              size = 4
              call numeral (ia,pa,size)
              call numeral (ib,pb,size)
              if (ia .le. ib) then
                 pt = pa//pb
              else
                 pt = pb//pa
              end if
              do k = 1, maxnvp
                 if (kvpr(k).eq.blank .or. kvpr(k).eq.pt) then
                    kvpr(k) = pt
                    radpr(k) = rd
                    epspr(k) = ep
                    goto 150
                 end if
              end do
              if (rank.eq.0) write (iout,140)
  140         format (/,' KVDW  --  Too many Special VDW Pair',
     &                   ' Parameters')
              abort = .true.
  150         continue
           end if
        end do
c
c       process keywords containing hydrogen bonding vdw parameters
c
        header = .true.
        do i = 1, nkey
           next = 1
           record = keyline(i)
           call gettext (record,keyword,next)
           call upcase (keyword)
           if (keyword(1:6) .eq. 'HBOND ') then
              ia = 0
              ib = 0
              rd = 0.0d0
              ep = 0.0d0
              string = record(next:240)
              read (string,*,err=200,end=200)  ia,ib,rd,ep
              if (header .and. .not.silent) then
                 header = .false.
                 if (vdwindex .eq. 'CLASS') then
                    if (rank.eq.0) write (iout,160)
  160               format (/,' Additional van der Waals Hydrogen',
     &                         ' Bonding Parameters :',
     &                      //,5x,'Atom Classes',6x,'Size Sum',
     &                         4x,'Epsilon',/)
                 else
                    if (rank.eq.0) write (iout,170)
  170               format (/,' Additional van der Waals Hydrogen',
     &                         ' Bonding Parameters :',
     &                      //,5x,'Atom Types',8x,'Size Sum',
     &                         4x,'Epsilon',/)
                 end if
              end if
              if (.not. silent) then
                 if (rank.eq.0) write (iout,180)  ia,ib,rd,ep
  180            format (6x,2i4,4x,2f12.4)
              end if
              size = 4
              call numeral (ia,pa,size)
              call numeral (ib,pb,size)
              if (ia .le. ib) then
                 pt = pa//pb
              else
                 pt = pb//pa
              end if
              do k = 1, maxnvp
                 if (khb(k).eq.blank .or. khb(k).eq.pt) then
                    khb(k) = pt
                    radhb(k) = rd
                    epshb(k) = ep
                    goto 200
                 end if
              end do
              if (rank.eq.0) write (iout,190)
  190         format (/,' KVDW  --  Too many Hydrogen Bonding Pair',
     &                   ' Parameters')
              abort = .true.
  200         continue
           end if
        end do
c
c     deallocate global pointers if necessary
c
        call dealloc_shared_vdw
c
c     allocate global pointers
c
        call alloc_shared_vdw
        if (hostrank.ne.0) goto 1000
c
c       use atom class or type as index into vdw parameters
c
        k = 0
        do i = 1, n
           jvdw(i) = class(i)
           if (vdwindex .eq. 'TYPE')  jvdw(i) = type(i)
           k = max(k,jvdw(i))
        end do
        if (k .gt. maxclass) then
           if (rank.eq.0) write (iout,210)
  210      format (/,' KVDW  --  Unable to Index VDW Parameters;',
     &                ' Increase MAXCLASS')
           abort = .true.
        end if
c
c       count the number of vdw types and their frequencies
c
        nvt = 0
        do i = 1, n
           it = jvdw(i)
           do k = 1, nvt
              if (ivt(k) .eq. it) then
                 jvt(k) = jvt(k) + 1
                 goto 220
              end if
           end do
           nvt = nvt + 1
           ivt(nvt) = it
           jvt(nvt) = 1
  220      continue
        end do
c
c       perform dynamic allocation of some local arrays
c
        allocate (srad(maxtyp))
        allocate (srad4(maxtyp))
        allocate (seps(maxtyp))
        allocate (seps4(maxtyp))
c
c       get the vdw radii and well depths for each atom type
c
        do i = 1, maxtyp
           if (rad4(i) .eq. 0.0d0)  rad4(i) = rad(i)
           if (eps4(i) .eq. 0.0d0)  eps4(i) = eps(i)
           if (radtyp .eq. 'SIGMA') then
              rad(i) = twosix * rad(i)
              rad4(i) = twosix * rad4(i)
           end if
           if (radsiz .eq. 'DIAMETER') then
              rad(i) = 0.5d0 * rad(i)
              rad4(i) = 0.5d0 * rad4(i)
           end if
           srad(i) = sqrt(rad(i))
           eps(i) = abs(eps(i))
           seps(i) = sqrt(eps(i))
           srad4(i) = sqrt(rad4(i))
           eps4(i) = abs(eps4(i))
           seps4(i) = sqrt(eps4(i))
        end do
c
c       use combination rules to set pairwise vdw radii sums
c
        do i = 1, maxclass
           do k = i, maxclass
              if (radrule(1:6) .eq. 'MMFF94') then
                 if (i .ne. k) then
                    if (DA(i).eq.'D' .or. DA(k).eq.'D') then
                       rd = 0.5d0 * (rad(i)+rad(k))
                    else
                       gik = (rad(i)-rad(k))/(rad(i)+rad(k))
                       rd = 0.5d0 * (rad(i)+rad(k))
     &                      * (1.0d0+0.2d0*(1.0d0-exp(-12.0d0*gik*gik)))
                    end if
                 else
                    rd = rad(i)
                 end if
              else if (rad(i).eq.0.0d0 .and. rad(k).eq.0.0d0) then
                 rd = 0.0d0
              else if (radrule(1:10) .eq. 'ARITHMETIC') then
                 rd = rad(i) + rad(k)
              else if (radrule(1:9) .eq. 'GEOMETRIC') then
                 rd = 2.0d0 * (srad(i) * srad(k))
              else if (radrule(1:10) .eq. 'CUBIC-MEAN') then
                 rd = 2.0d0*(rad(i)**3+rad(k)**3)/(rad(i)**2+rad(k)**2)
              else
                 rd = rad(i) + rad(k)
              end if
              radmin(i,k) = rd
              radmin(k,i) = rd
           end do
        end do
c
c       use combination rules to set pairwise well depths
c
        do i = 1, maxclass
           do k = i, maxclass
              if (epsrule(1:6) .eq. 'MMFF94') then
                 ep = 181.16d0*G(i)*G(k)*alph(i)*alph(k)
     &                   / ((sqrt(alph(i)/Nn(i))+sqrt(alph(k)/Nn(k)))
     &                                *radmin(i,k)**6)
                 if (i .eq. k)  eps(i) = ep
              else if (eps(i).eq.0.0d0 .and. eps(k).eq.0.0d0) then
                 ep = 0.0d0
              else if (epsrule(1:10) .eq. 'ARITHMETIC') then
                 ep = 0.5d0 * (eps(i) + eps(k))
              else if (epsrule(1:9) .eq. 'GEOMETRIC') then
                 ep = seps(i) * seps(k)
              else if (epsrule(1:8) .eq. 'HARMONIC') then
                 ep = 2.0d0 * (eps(i)*eps(k)) / (eps(i)+eps(k))
              else if (epsrule(1:3) .eq. 'HHG') then
                 ep = 4.0d0 * (eps(i)*eps(k)) / (seps(i)+seps(k))**2
              else if (epsrule(1:3) .eq. 'W-H') then
                 ep = 2.0d0 * (seps(i)*seps(k)) * (rad(i)*rad(k))**3
     &                   / (rad(i)**6+rad(k)**6)
              else
                 ep = seps(i) * seps(k)
              end if
              epsilon(i,k) = ep
              epsilon(k,i) = ep
           end do
        end do
c
c       use combination rules to set pairwise 1-4 vdw radii sums
c
        do i = 1, maxclass
           do k = i, maxclass
              if (radrule(1:6) .eq. 'MMFF94') then
                 if (i .ne. k) then
                    if (DA(i).eq.'D' .or. DA(k).eq.'D') then
                       rd = 0.5d0 * (rad(i)+rad(k))
                    else
                       gik = (rad(i)-rad(k))/(rad(i)+rad(k))
                       rd = 0.5d0 * (rad(i)+rad(k))
     &                     * (1.0d0+0.2d0*(1.0d0-exp(-12.0d0*gik*gik)))
                    end if
                 else
                    rd = rad(i)
                 end if
              else if (rad4(i).eq.0.0d0 .and. rad4(k).eq.0.0d0) then
                 rd = 0.0d0
              else if (radrule(1:10) .eq. 'ARITHMETIC') then
                 rd = rad4(i) + rad4(k)
              else if (radrule(1:9) .eq. 'GEOMETRIC') then
                 rd = 2.0d0 * (srad4(i) * srad4(k))
              else if (radrule(1:10) .eq. 'CUBIC-MEAN') then
                 rd = 2.0d0 * (rad4(i)**3+rad4(k)**3)
     &                           / (rad4(i)**2+rad4(k)**2)
              else
                 rd = rad4(i) + rad4(k)
              end if
              radmin4(i,k) = rd
              radmin4(k,i) = rd
           end do
        end do
c
c       use combination rules to set pairwise 1-4 well depths
c
        do i = 1, maxclass
           do k = i, maxclass
              if (epsrule(1:6) .eq. 'MMFF94') then
                 ep = 181.16d0*G(i)*G(k)*alph(i)*alph(k)
     &                   / ((sqrt(alph(i)/Nn(i))+sqrt(alph(k)/Nn(k)))
     &                                *radmin(i,k)**6)
                 if (i .eq. k)  eps4(i) = ep
              else if (eps4(i).eq.0.0d0 .and. eps4(k).eq.0.0d0) then
                 ep = 0.0d0
              else if (epsrule(1:10) .eq. 'ARITHMETIC') then
                 ep = 0.5d0 * (eps4(i) + eps4(k))
              else if (epsrule(1:9) .eq. 'GEOMETRIC') then
                 ep = seps4(i) * seps4(k)
              else if (epsrule(1:8) .eq. 'HARMONIC') then
                 ep = 2.0d0 * (eps4(i)*eps4(k)) / (eps4(i)+eps4(k))
              else if (epsrule(1:3) .eq. 'HHG') then
                 ep = 4.0d0 * (eps4(i)*eps4(k)) / (seps4(i)+seps4(k))**2
              else if (epsrule(1:3) .eq. 'W-H') then
                 ep = 2.0d0 * (seps4(i)*seps4(k)) * (rad4(i)*rad4(k))**3
     &                   / (rad4(i)**6+rad4(k)**6)
              else
                 ep = seps4(i) * seps4(k)
              end if
              epsilon4(i,k) = ep
              epsilon4(k,i) = ep
           end do
        end do
c
c       perform deallocation of some local arrays
c
        deallocate (srad)
        deallocate (srad4)
        deallocate (seps)
        deallocate (seps4)
c
c       use reduced values for MMFF donor-acceptor pairs
c
        if (forcefield .eq. 'MMFF94') then
           do i = 1, maxclass
              do k = i, maxclass
                 if ((da(i).eq.'D' .and. da(k).eq.'A') .or.
     &               (da(i).eq.'A' .and. da(k).eq.'D')) then
                    epsilon(i,k) = epsilon(i,k) * 0.5d0
                    epsilon(k,i) = epsilon(k,i) * 0.5d0
                    radmin(i,k) = radmin(i,k) * 0.8d0
                    radmin(k,i) = radmin(k,i) * 0.8d0
                    epsilon4(i,k) = epsilon4(i,k) * 0.5d0
                    epsilon4(k,i) = epsilon4(k,i) * 0.5d0
                    radmin4(i,k) = radmin4(i,k) * 0.8d0
                    radmin4(k,i) = radmin4(k,i) * 0.8d0
                 end if
              end do
           end do
        end if
 1000   call MPI_BARRIER(hostcomm,ierr)
c
c       vdw reduction factor information for each individual atom
c
        do i = 1, n
           kred(i) = reduct(jvdw(i))
           if (n12(i).ne.1 .or. kred(i).eq.0.0d0) then
              ired(i) = i
           else
              ired(i) = i12(1,i)
           end if
        end do
c
c
c       radii and well depths for special atom class pairs
c
        do i = 1, maxnvp
           if (kvpr(i) .eq. blank)  goto 230
           ia = number(kvpr(i)(1:4))
           ib = number(kvpr(i)(5:8))
           if (rad(ia) .eq. 0.0d0)  rad(ia) = 0.001d0
           if (rad(ib) .eq. 0.0d0)  rad(ib) = 0.001d0
           if (radtyp .eq. 'SIGMA')  radpr(i) = twosix * radpr(i)
           radmin(ia,ib) = radpr(i)
           radmin(ib,ia) = radpr(i)
           epsilon(ia,ib) = abs(epspr(i))
           epsilon(ib,ia) = abs(epspr(i))
           radmin4(ia,ib) = radpr(i)
           radmin4(ib,ia) = radpr(i)
           epsilon4(ia,ib) = abs(epspr(i))
           epsilon4(ib,ia) = abs(epspr(i))
        end do
  230   continue
c
c       radii and well depths for hydrogen bonding pairs
c
        if (vdwtyp .eq. 'MM3-HBOND') then
           do i = 1, maxclass
              do k = 1, maxclass
                 radhbnd(k,i) = 0.0d0
                 epshbnd(k,i) = 0.0d0
              end do
           end do
           do i = 1, maxnhb
              if (khb(i) .eq. blank)  goto 240
              ia = number(khb(i)(1:4))
              ib = number(khb(i)(5:8))
              if (rad(ia) .eq. 0.0d0)  rad(ia) = 0.001d0
              if (rad(ib) .eq. 0.0d0)  rad(ib) = 0.001d0
              if (radtyp .eq. 'SIGMA')  radhb(i) = twosix * radhb(i)
              radhbnd(ia,ib) = radhb(i)
              radhbnd(ib,ia) = radhb(i)
              epshbnd(ia,ib) = abs(epshb(i))
              epshbnd(ib,ia) = abs(epshb(i))
           end do
  240      continue
        end if
c
c       set coefficients for Gaussian fit to eps=1 and radmin=1
c
        if (vdwtyp .eq. 'GAUSSIAN') then
           if (gausstyp .eq. 'LJ-4') then
              ngauss = 4
              igauss(1,1) = 846706.7d0
              igauss(2,1) = 15.464405d0 * twosix**2
              igauss(1,2) = 2713.651d0
              igauss(2,2) = 7.346875d0 * twosix**2
              igauss(1,3) = -9.699172d0
              igauss(2,3) = 1.8503725d0 * twosix**2
              igauss(1,4) = -0.7154420d0
              igauss(2,4) = 0.639621d0 * twosix**2
           else if (gausstyp .eq. 'LJ-2') then
              ngauss = 2
              igauss(1,1) = 14487.1d0
              igauss(2,1) = 9.05148d0 * twosix**2
              igauss(1,2) = -5.55338d0
              igauss(2,2) = 1.22536d0 * twosix**2
           else if (gausstyp .eq. 'MM3-2') then
              ngauss = 2
              igauss(1,1) = 2438.886d0
              igauss(2,1) = 9.342616d0
              igauss(1,2) = -6.197368d0
              igauss(2,2) = 1.564486d0
           else if (gausstyp .eq. 'MM2-2') then
              ngauss = 2
              igauss(1,1) = 3423.562d0
              igauss(2,1) = 9.692821d0
              igauss(1,2) = -6.503760d0
              igauss(2,2) = 1.585344d0
           else if (gausstyp .eq. 'IN-PLACE') then
              ngauss = 2
              igauss(1,1) = 500.0d0
              igauss(2,1) = 6.143d0
              igauss(1,2) = -18.831d0
              igauss(2,2) = 2.209d0
           end if
        end if
c
c     remove zero-sized atoms from the list of local vdw sites
c
        nvdw = 0
        do i = 1, n
           if (rad(jvdw(i)) .ne. 0.0d0) then
              nbvdw(i) = nvdw
              nvdw = nvdw + 1
              ivdw(nvdw) = i
           end if
        end do
c
c       turn off the van der Waals potential if it is not used
c
        if (nvdw .eq. 0)  then
          use_vdw = .false.
          use_vlist = .false.
        end if
        if (.not.(use_vdw)) return
        if (allocated(vdwlocnl)) deallocate(vdwlocnl)
        allocate (vdwlocnl(nvdw))
      end if
c
      if (allocated(vdwglob)) deallocate(vdwglob)
      allocate (vdwglob(nbloc))
c
c     remove zero-sized atoms from the list of vdw sites
c
      nvdwloc = 0
      do i = 1, nloc
         iglob = glob(i)
         vdwcount = nbvdw(iglob)
         if (rad(jvdw(iglob)) .ne. 0.0d0) then
            nvdwloc = nvdwloc + 1
            vdwglob(nvdwloc) = vdwcount + 1
         end if
      end do
c
      nvdwbloc = nvdwloc
      do iproc = 1, n_recep2
        do i = 1, domlen(p_recep2(iproc)+1)
          iglob = glob(bufbeg(p_recep2(iproc)+1)+i-1)
          vdwcount = nbvdw(iglob)
          if (rad(jvdw(iglob)) .ne. 0.0d0) then
            nvdwbloc = nvdwbloc + 1
            vdwglob(nvdwbloc) = vdwcount + 1
          end if
        end do
      end do
c
      modnl = mod(istep,ineigup)
      if (istep.eq.-1) return
      if (modnl.ne.0) return
      if (allocated(vdwglobnl)) deallocate(vdwglobnl)
      allocate (vdwglobnl(nlocnl))
c
      nvdwlocnl = 0
      do i = 1, nlocnl
        iglob = ineignl(i)
        vdwcount = nbvdw(iglob)
        if (rad(jvdw(iglob)) .ne. 0.0d0) then
          call distprocpart(iglob,rank,d,.true.)
          if (repart(iglob).eq.rank) d = 0.0d0
            if (d*d.le.(vbuf2/4)) then
              nvdwlocnl = nvdwlocnl + 1
              vdwglobnl(nvdwlocnl) = vdwcount + 1
              vdwlocnl(vdwcount+1) = nvdwlocnl
            end if
        end if
      end do
c
      return
      end
c
c     subroutine dealloc_shared_vdw : deallocate shared memory pointers for vdw
c     parameter arrays
c
      subroutine dealloc_shared_vdw
      USE, INTRINSIC :: ISO_C_BINDING, ONLY : C_PTR, C_F_POINTER
      use vdw
      use mpi
      implicit none
      INTEGER(KIND=MPI_ADDRESS_KIND) :: windowsize
      INTEGER :: disp_unit,ierr
      TYPE(C_PTR) :: baseptr
c
      if (associated(jvdw)) then
        CALL MPI_Win_shared_query(winjvdw, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winjvdw,ierr)
      end if
      if (associated(ivdw)) then
        CALL MPI_Win_shared_query(winivdw, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winivdw,ierr)
      end if
      if (associated(ired)) then
        CALL MPI_Win_shared_query(winired, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winired,ierr)
      end if
      if (associated(kred)) then
        CALL MPI_Win_shared_query(winkred, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winkred,ierr)
      end if
      if (associated(ivt)) then
        CALL MPI_Win_shared_query(winivt, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winivt,ierr)
      end if
      if (associated(jvt)) then
        CALL MPI_Win_shared_query(winjvt, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winjvt,ierr)
      end if
      if (associated(radmin)) then
        CALL MPI_Win_shared_query(winradmin, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winradmin,ierr)
      end if
      if (associated(epsilon)) then
        CALL MPI_Win_shared_query(winepsilon, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winepsilon,ierr)
      end if
      if (associated(radmin4)) then
        CALL MPI_Win_shared_query(winradmin4, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winradmin4,ierr)
      end if
      if (associated(epsilon4)) then
        CALL MPI_Win_shared_query(winepsilon4, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winepsilon4,ierr)
      end if
      if (associated(radhbnd)) then
        CALL MPI_Win_shared_query(winradhbnd, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winradhbnd,ierr)
      end if
      if (associated(epshbnd)) then
        CALL MPI_Win_shared_query(winepshbnd, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winepshbnd,ierr)
      end if
      if (associated(nbvdw)) then
        CALL MPI_Win_shared_query(winnbvdw, 0, windowsize, disp_unit,
     $  baseptr, ierr)
        CALL MPI_Win_free(winnbvdw,ierr)
      end if
      return
      end
c
c     subroutine alloc_shared_vdw : allocate shared memory pointers for vdw
c     parameter arrays
c
      subroutine alloc_shared_vdw
      USE, INTRINSIC :: ISO_C_BINDING, ONLY : C_PTR, C_F_POINTER
      use sizes
      use atoms
      use domdec
      use vdw
      use mpi
      implicit none
      INTEGER(KIND=MPI_ADDRESS_KIND) :: windowsize
      INTEGER :: disp_unit,ierr
      TYPE(C_PTR) :: baseptr
      integer :: arrayshape(1),arrayshape2(2)
c
c     jvdw
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winjvdw, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winjvdw, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,jvdw,arrayshape)
c
c     ivdw
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winivdw, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winivdw, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,ivdw,arrayshape)
c
c     ired
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winired, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winired, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,ired,arrayshape)
c
c     kred
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winkred, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winkred, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,kred,arrayshape)
c
c     ivt
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winivt, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winivt, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,ivt,arrayshape)
c
c     jvt
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winjvt, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winjvt, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,jvt,arrayshape)
c
c     radmin
c
      arrayshape2=(/maxclass,maxclass/)
      if (hostrank == 0) then
        windowsize = int(maxclass*maxclass,MPI_ADDRESS_KIND)*
     $ 8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winradmin, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winradmin, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,radmin,arrayshape2)
c
c     epsilon
c
      arrayshape2=(/maxclass,maxclass/)
      if (hostrank == 0) then
        windowsize = int(maxclass*maxclass,MPI_ADDRESS_KIND)*
     $ 8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winepsilon, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winepsilon, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,epsilon,arrayshape2)
c
c     radmin4
c
      arrayshape2=(/maxclass,maxclass/)
      if (hostrank == 0) then
        windowsize = int(maxclass*maxclass,MPI_ADDRESS_KIND)*
     $  8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winradmin4, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winradmin4, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,radmin4,arrayshape2)
c
c     epsilon4
c
      arrayshape2=(/maxclass,maxclass/)
      if (hostrank == 0) then
        windowsize = int(maxclass*maxclass,MPI_ADDRESS_KIND)*
     $  8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winepsilon4, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winepsilon4, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,epsilon4,arrayshape2)
c
c     radhbnd
c
      arrayshape2=(/maxclass,maxclass/)
      if (hostrank == 0) then
        windowsize = int(maxclass*maxclass,MPI_ADDRESS_KIND)*
     $  8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winradhbnd, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winradhbnd, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,radhbnd,arrayshape2)
c
c     epshbnd
c
      arrayshape2=(/maxclass,maxclass/)
      if (hostrank == 0) then
        windowsize = int(maxclass*maxclass,MPI_ADDRESS_KIND)*
     $  8_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winepshbnd, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winepshbnd, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,epshbnd,arrayshape2)
c
c     nbvdw
c
      arrayshape=(/n/)
      if (hostrank == 0) then
        windowsize = int(n,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND
      else
        windowsize = 0_MPI_ADDRESS_KIND
      end if
      disp_unit = 1
c
c    allocation
c
      CALL MPI_Win_allocate_shared(windowsize, disp_unit, MPI_INFO_NULL,
     $  hostcomm, baseptr, winnbvdw, ierr)
      if (hostrank /= 0) then
        CALL MPI_Win_shared_query(winnbvdw, 0, windowsize, disp_unit,
     $  baseptr, ierr)
      end if
c
c    association with fortran pointer
c
      CALL C_F_POINTER(baseptr,nbvdw,arrayshape)
      return
      end
