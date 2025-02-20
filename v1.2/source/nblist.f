c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     ###############################################################
c     ##                                                           ##
c     ##  subroutine nblist  --  maintain pairwise neighbor lists  ##
c     ##                                                           ##
c     ###############################################################
c
c
c     "nblist" constructs and maintains nonbonded pair neighbor lists
c     for vdw and electrostatic interactions
c
c
      subroutine nblist(istep)
      use sizes
      use domdec
      use cutoff
      use neigh
      use potent
      use mpi
      implicit none
      integer istep,modnl
c
c
c     check number of steps between nl updates
c
      modnl = mod(istep,ineigup)
      if (modnl.ne.0) return

      if ((use_clist).or.(use_mlist)) then
        if (allocated(nelst)) deallocate (nelst)
        allocate (nelst(nlocnl))
        if (allocated(elst)) deallocate (elst)
        allocate (elst(maxelst,nlocnl))
        nelst = 0
        elst = 0
      end if
      if ((use_shortclist).or.(use_shortmlist)) then
        if (allocated(nshortelst)) deallocate (nshortelst)
        allocate (nshortelst(nlocnl))
        if (allocated(shortelst)) deallocate (shortelst)
        allocate (shortelst(maxelst,nlocnl))
        nshortelst = 0
        shortelst = 0
      end if
      if ((use_vlist).or.(use_dlist)) then
        if (allocated(nvlst)) deallocate (nvlst)
        allocate (nvlst(nlocnl))
        if (allocated(vlst)) deallocate (vlst)
        allocate (vlst(maxvlst,nlocnl))
        nvlst = 0
        vlst = 0
      end if
      if ((use_shortvlist).or.(use_shortdlist)) then
        if (allocated(nshortvlst)) deallocate (nshortvlst)
        allocate (nshortvlst(nlocnl))
        if (allocated(shortvlst)) deallocate (shortvlst)
        allocate (shortvlst(maxvlst,nlocnl))
        nshortvlst = 0
        shortvlst = 0
      end if
      if ((use_pmecore).and.(rank.gt.ndir-1)) return
c
c
c     build the cells at the beginning and assign the particules to them
c
      call build_cell_list
c
      if (use_shortclist) then
        call clistcell2
      else if (use_clist) then
        call clistcell
      end if
      if (use_shortvlist) then
        call vlistcell2
      else if (use_vlist) then
        call vlistcell
      end if
      if (use_shortdlist) then
        call dlistcell2
      else if (use_dlist) then
        call dlistcell
      end if
      if (use_shortmlist) then
        call mlistcell2
      else if (use_mlist) then
        call mlistcell
      end if
c
      return
      end
c
c
c    "mlistcell" performs a complete rebuild of the
c     electrostatic neighbor lists for multipoles using linked cells method
c
      subroutine mlistcell
      use sizes
      use atmlst
      use atoms
      use boxes
      use cutoff
      use domdec
      use iounit
      use mpole
      use neigh
      use mpi
      implicit none
      integer iglob
      integer i,icell,j,k,nneigloc
      integer ineig,iipole,kkpole
      integer kcell,kglob
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2
      real*8, allocatable :: pos(:,:),r2vec(:)
      real*8 boxedge2
      logical docompute
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in multipole neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('Multipole cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (mbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) mpolecut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     perform a complete list build
c
      do i = 1, npolelocnl
        iipole = poleglobnl(i)
        iglob  = ipole(iipole)
        icell = repartcell(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        xi = x(iglob)
        yi = y(iglob)
        zi = z(iglob)
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          kkpole = pollist(kglob)
c
c   skip atom if it is not in the multipole list
c
          if (kkpole.eq.0) cycle
          if (kglob.le.iglob) cycle
          xk = x(kglob)
          yk = y(kglob)
          zk = z(kglob)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. mbuf2) then
             j = j + 1
             kkpole = pollist(kglob)
             elst(j,i) = kkpole
          end if
        end do
        nelst(i) = j
c
c     check to see if the neighbor list is too long
c
        if (nelst(i) .ge. maxelst) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' MBUILD  --  Too many Neighbors;',
     &                  ' Increase MAXELST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    "mlistcell2" performs a complete rebuild of the
c     short range and regular electrostatic neighbor lists for 
c     multipoles using linked cells method
c
      subroutine mlistcell2
      use sizes
      use atmlst
      use atoms
      use boxes
      use cutoff
      use domdec
      use iounit
      use mpole
      use neigh
      use mpi
      implicit none
      integer iglob
      integer i,icell,j,j1,k,nneigloc
      integer ineig,iipole,kkpole
      integer kcell,kglob
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2
      real*8 mbufbeg2
      real*8 boxedge2
      real*8, allocatable :: pos(:,:),r2vec(:)
      logical docompute
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in multipole neigbor list: max cutoff + ',
     $   'buffer should be less than half one edge of the box')
 1010 format('Multipole cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (mbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) mpolecut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     starting distances for long range real space interactions
c
      mbufbeg2 = (mpoleshortcut-lbuffer-shortheal)**2
c
c     perform a complete list build
c
      do i = 1, npolelocnl
        iipole = poleglobnl(i)
        iglob  = ipole(iipole)
        icell = repartcell(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        xi = x(iglob)
        yi = y(iglob)
        zi = z(iglob)
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          kkpole = pollist(kglob)
c
c   skip atom if it is not in the multipole list
c
          if (kkpole.eq.0) cycle
          if (kglob.le.iglob) cycle
          xk = x(kglob)
          yk = y(kglob)
          zk = z(kglob)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        j1 = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. mshortbuf2) then
             j1 = j1 + 1
             kkpole = pollist(kglob)
             shortelst(j1,i) = kkpole
          end if
          if (r2.le.mbuf2) then
             j = j + 1
             kkpole = pollist(kglob)
             elst(j,i) = kkpole
          end if
        end do
        nelst(i) = j
        nshortelst(i) = j1
c
c     check to see if the neighbor list is too long
c
        if (nelst(i) .ge. maxelst) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' MBUILD  --  Too many Neighbors;',
     &                  ' Increase MAXELST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    subroutine initmpipme : build the arrays to communicate direct and reciprocal fields
c    during the calculation of the induced dipoles
c
c
      subroutine initmpipme
      use atmlst
      use domdec
      use mpole
      use pme
      use mpi
      implicit none
      integer ierr,iipole
      integer i,iproc,tag,iglob
      integer count1
      integer status(MPI_STATUS_SIZE)
      integer, allocatable :: req(:),req2(:),count(:)
      allocate (req(nproc*nproc))
      allocate (req2(nproc*nproc))
      allocate (count(nproc))
c
      count = 0 
c
c     deal with Direct-Recip communications
c
      if (allocated(buf1)) deallocate (buf1)
      allocate (buf1(nblocrecdir))
c      buf1 = 0
      if (allocated(buf2)) deallocate (buf2)
      allocate (buf2(nblocrecdir))
c      buf2 = 0
      if (allocated(buflen1)) deallocate (buflen1)
      allocate (buflen1(nproc))
      buflen1 = 0
      if (allocated(buflen2)) deallocate (buflen2)
      allocate (buflen2(nproc))
      buflen2 = 0
      if (allocated(bufbeg1)) deallocate (bufbeg1)
      allocate (bufbeg1(nproc))
      bufbeg1 = 0
      if (allocated(bufbeg2)) deallocate (bufbeg2)
      allocate (bufbeg2(nproc))
      bufbeg2 = 0
c
      do i = 1, npolerecloc
        iipole = polerecglob(i)
        iglob = ipole(iipole)
        if (repart(iglob).ne.rank) then
          buflen2(repart(iglob)+1) = buflen2(repart(iglob)+1)+1
        end if
      end do
      count1 = 0
      do iproc = 1, nrecdir_recep1
        if (precdir_recep1(iproc).ne.rank) then
          if (buflen2(precdir_recep1(iproc)+1).ne.0) then
            bufbeg2(precdir_recep1(iproc)+1) = count1 + 1
          else
            bufbeg2(precdir_recep1(iproc)+1) = 1
          end if
          count1 = count1 + buflen2(precdir_recep1(iproc)+1)
        end if
      end do
c
      do i = 1, npolerecloc
        iipole = polerecglob(i)
        iglob = ipole(iipole)
        if (repart(iglob).ne.rank) then
          buf2(bufbeg2(repart(iglob)+1)+count(repart(iglob)+1))=
     $      iipole
          count(repart(iglob)+1) = count(repart(iglob)+1) + 1
        end if
      end do
c
c     send and receive sizes of the buffers
c
       do i = 1, nrecdir_send1
         if (precdir_send1(i).ne.rank) then
          tag = nproc*rank + precdir_send1(i) + 1
          call MPI_IRECV(buflen1(precdir_send1(i)+1),1,MPI_INT,
     $   precdir_send1(i),tag,COMM_TINKER,req(tag),ierr)
        end if
      end do
      do i = 1, nrecdir_recep1
        if (precdir_recep1(i).ne.rank) then
          tag = nproc*precdir_recep1(i) + rank + 1
          call MPI_ISEND(buflen2(precdir_recep1(i)+1),1,MPI_INT,
     $     precdir_recep1(i),tag,COMM_TINKER,req(tag),ierr)
        end if
      end do
c
      do i = 1, nrecdir_send1
        if (precdir_send1(i).ne.rank) then
          tag = nproc*rank + precdir_send1(i) + 1
          call MPI_WAIT(req(tag),status,ierr)
        end if
      end do
      do i = 1, nrecdir_recep1
        if (precdir_recep1(i).ne.rank) then
          tag = nproc*precdir_recep1(i) + rank + 1
          call MPI_WAIT(req(tag),status,ierr)
        end if
      end do
      count1 = 0
      do iproc = 1, nrecdir_send1
        if (precdir_send1(iproc).ne.rank) then
          if (buflen1(precdir_send1(iproc)+1).ne.0) then
            bufbeg1(precdir_send1(iproc)+1) = count1 + 1
          else
            bufbeg1(precdir_send1(iproc)+1) = 1
          end if
          count1 = count1 + buflen1(precdir_send1(iproc)+1)
        end if
      end do
c
c     send and receive list of corresponding indexes
c
      do i = 1, nrecdir_send1
        if (precdir_send1(i).ne.rank) then
          tag = nproc*rank + precdir_send1(i) + 1
          call MPI_IRECV(buf1(bufbeg1(precdir_send1(i)+1)),
     $     buflen1(precdir_send1(i)+1),
     $     MPI_INT,precdir_send1(i),tag,COMM_TINKER,req2(tag),ierr)
        end if
      end do
      do i = 1, nrecdir_recep1
        if (precdir_recep1(i).ne.rank) then
          tag = nproc*precdir_recep1(i) + rank + 1
          call MPI_ISEND(buf2(bufbeg2(precdir_recep1(i)+1)),
     $     buflen2(precdir_recep1(i)+1),MPI_INT,precdir_recep1(i),tag,
     $     COMM_TINKER,req2(tag),ierr)
        end if
      end do
c
      do i = 1, nrecdir_send1
        if (precdir_send1(i).ne.rank) then
          tag = nproc*rank + precdir_send1(i) + 1
          call MPI_WAIT(req2(tag),status,ierr)
        end if
      end do
      do i = 1, nrecdir_recep1
        if (precdir_recep1(i).ne.rank) then
          tag = nproc*precdir_recep1(i) + rank + 1
          call MPI_WAIT(req2(tag),status,ierr)
        end if
      end do
c
      deallocate (req)
      deallocate (req2)
      deallocate (count)
      return
      end
c
c     subroutine reinitnl : get the number of particules whose nl has to be computed
c     and the associated indexes
c
      subroutine reinitnl(istep)
      use atoms
      use domdec
      use neigh
      implicit none
      real*8 d,mbuf,vbuf,torquebuf,bigbuf
      integer iproc,i,iglob,modnl
      integer iloc,istep
c
      mbuf = sqrt(mbuf2)
      vbuf = sqrt(vbuf2) + 2.0d0
      torquebuf = mbuf + lbuffer
      if (torquebuf.gt.(vbuf)) then
        bigbuf = torquebuf
      else
        bigbuf = vbuf
      end if
c
      modnl = mod(istep,ineigup)
      if (modnl.ne.0) return
c
      if (.not.allocated(ineignl)) allocate (ineignl(n))
      ineignl = 0
c
      nlocnl = nloc
      ineignl(1:nloc) = glob(1:nloc)
c
      do iproc = 1, nbig_recep
        do i = 1, domlen(pbig_recep(iproc)+1)
          iloc = bufbeg(pbig_recep(iproc)+1)+i-1
          iglob = glob(iloc)
          call distprocpart(iglob,rank,d,.true.)
          if (d.le.(bigbuf/2)) then
            nlocnl = nlocnl + 1
            ineignl(nlocnl) = iglob
c            locnl(iglob) = nlocnl
          end if
        end do
      end do
      return
      end
c
c
c     subroutine build_cell_list : build the cells in order to build the non bonded neighbor
c     lists with the cell-list method
c
      subroutine build_cell_list
      use atoms
      use bound
      use domdec
      use neigh
      use mpi
      implicit none
      integer i,proc,icell,j,k,p,q,r,iglob
      integer count,iloc
      integer temp_x,temp_y,temp_z
      integer nx_cell,ny_cell,nz_cell
      integer numneig,tempcell
      real*8 xmin,xmax,ymin,ymax,zmin,zmax
      real*8 lenx,leny,lenz
      real*8 mbuf,vbuf,bigbuf
      real*8 lenx_cell,leny_cell,lenz_cell
      real*8 xr,yr,zr
      real*8 eps1,eps2
      real*8, allocatable :: xbegcelltemp(:),ybegcelltemp(:)
      real*8, allocatable :: zbegcelltemp(:)
      real*8, allocatable :: xendcelltemp(:),yendcelltemp(:)
      real*8, allocatable :: zendcelltemp(:)
      integer, allocatable :: filledcell(:),indcelltemp(:)

c
      eps1 = 1.0d-10
      eps2 = 1.0d-8
      mbuf = sqrt(mbuf2)
      vbuf = sqrt(vbuf2)+2.0
      if ((mbuf+lbuffer).gt.vbuf) then
        bigbuf = (mbuf+lbuffer)/3
      else
        bigbuf = vbuf/3
      end if
c
c
c     divide the searching domain in cells of size the multipole cutoff
c
      xmin = xbegproc(rank+1)
      xmax = xendproc(rank+1)
      ymin = ybegproc(rank+1)
      ymax = yendproc(rank+1)
      zmin = zbegproc(rank+1)
      zmax = zendproc(rank+1)
      do i = 1, nbig_recep
        proc = pbig_recep(i)
        if (xbegproc(proc+1).le.xmin) xmin = xbegproc(proc+1)
        if (xendproc(proc+1).ge.xmax) xmax = xendproc(proc+1)
        if (ybegproc(proc+1).le.ymin) ymin = ybegproc(proc+1)
        if (yendproc(proc+1).ge.ymax) ymax = yendproc(proc+1)
        if (zbegproc(proc+1).le.zmin) zmin = zbegproc(proc+1)
        if (zendproc(proc+1).ge.zmax) zmax = zendproc(proc+1)
      end do
c
      lenx = abs(xmax-xmin)
      nx_cell = max(1,int(lenx/(bigbuf)))
      lenx_cell = lenx/nx_cell
      leny = abs(ymax-ymin)
      ny_cell = max(1,int(leny/(bigbuf)))
      leny_cell = leny/ny_cell
      lenz = abs(zmax-zmin)
      nz_cell = max(1,int(lenz/(bigbuf)))
      lenz_cell = lenz/nz_cell
      ncell_tot = nx_cell*ny_cell*nz_cell
c
      allocate (xbegcelltemp(nx_cell))
      allocate (xendcelltemp(nx_cell))
      allocate (ybegcelltemp(ny_cell))
      allocate (yendcelltemp(ny_cell))
      allocate (zbegcelltemp(nz_cell))
      allocate (zendcelltemp(nz_cell))
      if (allocated(xbegcell)) deallocate (xbegcell)
      allocate (xbegcell(ncell_tot))
      if (allocated(ybegcell)) deallocate (ybegcell)
      allocate (ybegcell(ncell_tot))
      if (allocated(zbegcell)) deallocate (zbegcell)
      allocate (zbegcell(ncell_tot))
      if (allocated(xendcell)) deallocate (xendcell)
      allocate (xendcell(ncell_tot))
      if (allocated(yendcell)) deallocate (yendcell)
      allocate (yendcell(ncell_tot))
      if (allocated(zendcell)) deallocate (zendcell)
      allocate (zendcell(ncell_tot))
      if (allocated(neigcell)) deallocate (neigcell)
      allocate (neigcell(400,ncell_tot))
      if (allocated(numneigcell)) deallocate (numneigcell)
      allocate (numneigcell(ncell_tot))
      allocate (filledcell(ncell_tot))
c
      do i = 0, nx_cell-1
        xbegcelltemp(i+1) = xmin + i*lenx_cell
        xendcelltemp(i+1) = xmin + (i+1)*lenx_cell
      end do
      do i = 0, ny_cell-1
        ybegcelltemp(i+1) = ymin + i*leny_cell
        yendcelltemp(i+1) = ymin + (i+1)*leny_cell
      end do
      do i = 0, nz_cell-1
        zbegcelltemp(i+1) = zmin + i*lenz_cell
        zendcelltemp(i+1) = zmin + (i+1)*lenz_cell
      end do
c
c     assign cell
c
      do k = 1, nz_cell
        do j = 1, ny_cell
          do i = 1, nx_cell
              icell = (k-1)*ny_cell*nx_cell+(j-1)*nx_cell+i
              xbegcell(icell) = xbegcelltemp(i)
              xendcell(icell) = xendcelltemp(i)
              ybegcell(icell) = ybegcelltemp(j)
              yendcell(icell) = yendcelltemp(j)
              zbegcell(icell) = zbegcelltemp(k)
              zendcell(icell) = zendcelltemp(k)
              numneig = 0
              filledcell = 0
              filledcell(icell) = 1
c
c              do p = -1,1
c                do q = -1,1
c                  do r = -1,1
              do p = -3,3
                do q = -3,3
                  do r = -3,3
                    if ((p.eq.0).and.(q.eq.0).and.(r.eq.0)) goto 10
c
                    temp_x = p+i
                    temp_y = q+j-1
                    temp_z = r+k-1
c                    if ((i.eq.1).and.(p.eq.-1)) temp_x = nx_cell
c                    if ((i.eq.nx_cell).and.(p.eq.1)) temp_x = 1
c                    if ((j.eq.1).and.(q.eq.-1)) temp_y = ny_cell-1
c                    if ((j.eq.ny_cell).and.(q.eq.1)) temp_y = 0
c                    if ((k.eq.1).and.(r.eq.-1)) temp_z = nz_cell-1
c                    if ((k.eq.nz_cell).and.(r.eq.1)) temp_z = 0

                    if ((i.eq.1).and.(p.eq.-3)) temp_x = nx_cell-2
                    if ((i.eq.1).and.(p.eq.-2)) temp_x = nx_cell-1
                    if ((i.eq.1).and.(p.eq.-1)) temp_x = nx_cell
                    if ((i.eq.2).and.(p.eq.-3)) temp_x = nx_cell-1
                    if ((i.eq.2).and.(p.eq.-2)) temp_x = nx_cell
                    if ((i.eq.3).and.(p.eq.-3)) temp_x = nx_cell

                    if ((i.eq.nx_cell).and.(p.eq.1)) temp_x = 1
                    if ((i.eq.nx_cell).and.(p.eq.2)) temp_x = 2
                    if ((i.eq.nx_cell).and.(p.eq.3)) temp_x = 3
                    if ((i.eq.nx_cell-1).and.(p.eq.2)) temp_x = 1
                    if ((i.eq.nx_cell-1).and.(p.eq.3)) temp_x = 2
                    if ((i.eq.nx_cell-2).and.(p.eq.3)) temp_x = 1

                    if ((j.eq.1).and.(q.eq.-3)) temp_y = ny_cell-3
                    if ((j.eq.1).and.(q.eq.-2)) temp_y = ny_cell-2
                    if ((j.eq.1).and.(q.eq.-1)) temp_y = ny_cell-1
                    if ((j.eq.2).and.(q.eq.-3)) temp_y = ny_cell-2
                    if ((j.eq.2).and.(q.eq.-2)) temp_y = ny_cell-1
                    if ((j.eq.3).and.(q.eq.-3)) temp_y = ny_cell-1

                    if ((j.eq.ny_cell).and.(q.eq.1)) temp_y = 0
                    if ((j.eq.ny_cell).and.(q.eq.2)) temp_y = 1
                    if ((j.eq.ny_cell).and.(q.eq.3)) temp_y = 2
                    if ((j.eq.ny_cell-1).and.(q.eq.2)) temp_y = 0
                    if ((j.eq.ny_cell-1).and.(q.eq.3)) temp_y = 1
                    if ((j.eq.ny_cell-2).and.(q.eq.3)) temp_y = 0

                    if ((k.eq.1).and.(r.eq.-3)) temp_z = nz_cell-3
                    if ((k.eq.1).and.(r.eq.-2)) temp_z = nz_cell-2
                    if ((k.eq.1).and.(r.eq.-1)) temp_z = nz_cell-1
                    if ((k.eq.2).and.(r.eq.-3)) temp_z = nz_cell-2
                    if ((k.eq.2).and.(r.eq.-2)) temp_z = nz_cell-1
                    if ((k.eq.3).and.(r.eq.-3)) temp_z = nz_cell-1
                    if ((k.eq.nz_cell).and.(r.eq.1)) temp_z = 0
                    if ((k.eq.nz_cell).and.(r.eq.2)) temp_z = 1
                    if ((k.eq.nz_cell).and.(r.eq.3)) temp_z = 2
                    if ((k.eq.nz_cell-1).and.(r.eq.2)) temp_z = 0
                    if ((k.eq.nz_cell-1).and.(r.eq.3)) temp_z = 1
                    if ((k.eq.nz_cell-2).and.(r.eq.3)) temp_z = 0

                    tempcell = temp_z*ny_cell*nx_cell+temp_y*nx_cell+
     $                temp_x
                    if (filledcell(tempcell).eq.1) goto 10
                    filledcell(tempcell) = 1
                    numneig = numneig+1
                    neigcell(numneig,icell) = tempcell
 10               continue
                  end do
                end do
              end do
              numneigcell(icell) = numneig
          end do
        end do
      end do
      deallocate (filledcell)
      deallocate (xbegcelltemp)
      deallocate (xendcelltemp)
      deallocate (ybegcelltemp)
      deallocate (yendcelltemp)
      deallocate (zbegcelltemp)
      deallocate (zendcelltemp)
c
c     assign the atoms to the cells
c
      if (allocated(cell_len)) deallocate (cell_len)
      allocate (cell_len(ncell_tot))
      if (allocated(indcell)) deallocate (indcell)
      allocate (indcell(n))
      if (allocated(bufbegcell)) deallocate (bufbegcell)
      allocate (bufbegcell(ncell_tot))
      if (allocated(repartcell)) deallocate (repartcell)
      allocate (repartcell(n))
      allocate (indcelltemp(n))
      cell_len = 0
      indcelltemp = 0
c
      do i = 1, nlocnl
        iglob = ineignl(i)
        xr = x(iglob)
        yr = y(iglob)
        zr = z(iglob)
c        if (use_bounds) call image(xr,yr,zr)
        call image(xr,yr,zr)
        if (abs(xr-xmax).lt.eps1) xr = xr-eps2
        if (abs(yr-ymax).lt.eps1) yr = yr-eps2
        if (abs(zr-zmax).lt.eps1) zr = zr-eps2
        do icell = 1, ncell_tot
          if ((zr.ge.zbegcell(icell)).and.
     $     (zr.lt.zendcell(icell)).and.(yr.ge.ybegcell(icell))
     $    .and.(yr.lt.yendcell(icell)).and.(xr.ge.xbegcell(icell))
     $    .and.(xr.lt.xendcell(icell))) then
            repartcell(iglob) = icell
            cell_len(icell) = cell_len(icell) + 1
            indcelltemp(iglob) = cell_len(icell)
          end if
        end do
      end do
c
      bufbegcell(1) = 1
      count = cell_len(1)
      do icell = 2, ncell_tot
        if (cell_len(icell).ne.0) then
          bufbegcell(icell) = count + 1
        else
          bufbegcell(icell) = 1
        end if
        count = count + cell_len(icell)
      end do
c
      do i = 1, nlocnl
        iglob = ineignl(i)
        icell = repartcell(iglob)
        iloc  = bufbegcell(icell) + indcelltemp(iglob) - 1
        indcell(iloc) = iglob
      end do
      deallocate (indcelltemp)
      return
      end
c
c    "clistcell" performs a complete rebuild of the
c     electrostatic neighbor lists for charges using linked cells method
c
      subroutine clistcell
      use sizes
      use atmlst
      use atoms
      use boxes
      use charge
      use cutoff
      use domdec
      use iounit
      use neigh
      use mpi
      implicit none
      integer iglob
      integer i,icell,j,k,nneigloc
      integer ineig,iichg,kkchg
      integer kcell,kglob
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2
      real*8 boxedge2
      real*8, allocatable :: pos(:,:),r2vec(:)
      logical docompute
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in chargee neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('Charge cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (cbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) chgcut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     perform a complete list build
c
      do i = 1, nionlocnl
        iichg = chgglobnl(i)
        iglob  = iion(iichg)
        icell = repartcell(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        xi = x(iglob)
        yi = y(iglob)
        zi = z(iglob)
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          kkchg = chglist(kglob)
          if (kkchg.eq.0) cycle
          if (kglob.le.iglob) cycle
          xk = x(kglob)
          yk = y(kglob)
          zk = z(kglob)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. cbuf2) then
             j = j + 1
             kkchg = chglist(kglob)
             elst(j,i) = kkchg
          end if
        end do
        nelst(i) = j
c
c     check to see if the neighbor list is too long
c
        if (nelst(i) .ge. maxelst) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' MBUILD  --  Too many Neighbors;',
     &                  ' Increase MAXELST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    "clistcell2" performs a complete rebuild of the
c     electrostatic short range and regular neighbor lists for charges 
c     using linked cells method
c
      subroutine clistcell2
      use sizes
      use atmlst
      use atoms
      use boxes
      use charge
      use cutoff
      use domdec
      use iounit
      use neigh
      use mpi
      implicit none
      integer iglob
      integer i,icell,j,j1,k,nneigloc
      integer ineig,iichg,kkchg
      integer kcell,kglob
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2
      real*8 cbufbeg2,boxedge2
      real*8, allocatable :: pos(:,:),r2vec(:)
      logical docompute
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in charge neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('Multipole cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (cbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) chgcut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     starting distances for long range real space interactions
c
      cbufbeg2 = (chgshortcut-lbuffer-shortheal)**2
c
c     perform a complete list build
c
      do i = 1, nionlocnl
        iichg = chgglobnl(i)
        iglob  = iion(iichg)
        icell = repartcell(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        xi = x(iglob)
        yi = y(iglob)
        zi = z(iglob)
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          kkchg = chglist(kglob)
          if (kkchg.eq.0) cycle
          if (kglob.le.iglob) cycle
          xk = x(kglob)
          yk = y(kglob)
          zk = z(kglob)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        j1 = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. cshortbuf2) then
             j1 = j1 + 1
             kkchg = chglist(kglob)
             shortelst(j1,i) = kkchg
          end if
          if ((r2 .le. cbuf2).and.(r2.ge.cbufbeg2)) then
             j = j + 1
             kkchg = chglist(kglob)
             elst(j,i) = kkchg
          end if
        end do
        nelst(i) = j
        nshortelst(i) = j1
c
c     check to see if the neighbor list is too long
c
        if ((nelst(i) .ge. maxelst).or.(nshortelst(i).ge.maxelst)) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' MBUILD  --  Too many Neighbors;',
     &                  ' Increase MAXELST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    "vlistcell" performs a complete rebuild of the
c     vdw neighbor lists for charges using linked cells method
c
      subroutine vlistcell
      use atmlst
      use atoms
      use boxes
      use bound
      use cutoff
      use domdec
      use iounit
      use kvdws
      use neigh
      use vdw
      use mpi
      implicit none
      integer iglob,iloc
      integer i,ii,icell,j,k,nneigloc
      integer ineig,iivdw,iv
      integer kcell,kglob,kbis
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2,rdn
      real*8 xr,yr,zr
      real*8, allocatable :: pos(:,:),r2vec(:)
      real*8, allocatable :: xred(:)
      real*8, allocatable :: yred(:)
      real*8, allocatable :: zred(:)
      real*8 boxedge2
      logical docompute
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in VDW neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('VDW cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (vbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) vdwcut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (xred(nbloc))
      allocate (yred(nbloc))
      allocate (zred(nbloc))
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     apply reduction factors to find coordinates for each site
c
      do ii = 1, nvdwbloc
         iivdw = vdwglob(ii)
         iglob = ivdw(iivdw)
         i = loc(iglob)
         iv = ired(iglob)
         rdn = kred(iglob)
         xr = x(iglob) - x(iv)
         yr = y(iglob) - y(iv)
         zr = z(iglob) - z(iv)
         if (use_polymer) call image(xr,yr,zr)
         xred(i) = rdn*xr + x(iv)
         yred(i) = rdn*yr + y(iv)
         zred(i) = rdn*zr + z(iv)
      end do
c
c     perform a complete list build
c
      do i = 1, nvdwlocnl
        iivdw = vdwglobnl(i)
        iglob  = ivdw(iivdw)
        icell = repartcell(iglob)
        iloc = loc(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        xi = xred(iloc)
        yi = yred(iloc)
        zi = zred(iloc)
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          if (kglob.le.iglob) cycle
          if (rad(jvdw(kglob)).eq.0) cycle
          kbis = loc(kglob)
          xk = xred(kbis)
          yk = yred(kbis)
          zk = zred(kbis)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. vbuf2) then
             j = j + 1
             vlst(j,i) = kglob
          end if
        end do
        nvlst(i) = j
c
c     check to see if the neighbor list is too long
c
        if (nvlst(i) .ge. maxvlst) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' VBUILD  --  Too many Neighbors;',
     &                  ' Increase MAXVLST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (xred)
      deallocate (yred)
      deallocate (zred)
c
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    "vlistcell2" performs a complete rebuild of the
c     short range and regular vdw neighbor lists for charges 
c      using linked cells method
c
      subroutine vlistcell2
      use atmlst
      use atoms
      use boxes
      use bound
      use cutoff
      use domdec
      use iounit
      use kvdws
      use neigh
      use vdw
      use mpi
      implicit none
      integer iglob,iloc
      integer i,ii,icell,j,j1,k,nneigloc
      integer ineig,iivdw,iv
      integer kcell,kglob,kbis
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2,rdn
      real*8 xr,yr,zr
      real*8 boxedge2
      real*8, allocatable :: pos(:,:),r2vec(:)
      real*8, allocatable :: xred(:)
      real*8, allocatable :: yred(:)
      real*8, allocatable :: zred(:)
      logical docompute
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in VDW neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('VDW cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (vbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) vdwcut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (xred(nbloc))
      allocate (yred(nbloc))
      allocate (zred(nbloc))
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     starting distances for long range real space interactions
c
c
c     apply reduction factors to find coordinates for each site
c
      do ii = 1, nvdwbloc
         iivdw = vdwglob(ii)
         iglob = ivdw(iivdw)
         i = loc(iglob)
         iv = ired(iglob)
         rdn = kred(iglob)
         xr = x(iglob) - x(iv)
         yr = y(iglob) - y(iv)
         zr = z(iglob) - z(iv)
         if (use_polymer) call image(xr,yr,zr)
         xred(i) = rdn*xr + x(iv)
         yred(i) = rdn*yr + y(iv)
         zred(i) = rdn*zr + z(iv)
      end do
c
c     perform a complete list build
c
      do i = 1, nvdwlocnl
        iivdw = vdwglobnl(i)
        iglob  = ivdw(iivdw)
        icell = repartcell(iglob)
        iloc = loc(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        xi = xred(iloc)
        yi = yred(iloc)
        zi = zred(iloc)
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          if (kglob.le.iglob) cycle
          if (rad(jvdw(kglob)).eq.0) cycle
          kbis = loc(kglob)
          xk = xred(kbis)
          yk = yred(kbis)
          zk = zred(kbis)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        j1 = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. vshortbuf2) then
             j1 = j1 + 1
             shortvlst(j1,i) = kglob
          end if
          if (r2.le.vbuf2) then
             j = j + 1
             vlst(j,i) = kglob
          end if
        end do
        nvlst(i) = j
        nshortvlst(i) = j1
c
c     check to see if the neighbor list is too long
c
        if ((nvlst(i).ge.maxvlst).or.(nshortvlst(i).ge.maxvlst)) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' VBUILD  --  Too many Neighbors;',
     &                  ' Increase MAXVLST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (xred)
      deallocate (yred)
      deallocate (zred)
c
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    "dlistcell" performs a complete rebuild of the
c     dispersion neighbor lists using linked cells method
c
      subroutine dlistcell
      use atmlst
      use atoms
      use boxes
      use cutoff
      use disp
      use domdec
      use iounit
      use kvdws
      use neigh
      use vdw
      use mpi
      implicit none
      integer iglob,iloc
      integer i,icell,j,k,nneigloc
      integer ineig,iidisp
      integer kcell,kglob
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2
      real*8, allocatable :: pos(:,:),r2vec(:)
      logical docompute
      real*8 boxedge2
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in dispersion neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('Dispersion cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (dbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) dispcut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     perform a complete list build
c
      do i = 1, ndisplocnl
        iidisp = dispglobnl(i)
        iglob  = idisp(iidisp)
        icell = repartcell(iglob)
        iloc = loc(iglob)
        xi = x(iglob)
        yi = y(iglob)
        zi = z(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          if (kglob.le.iglob) cycle
          xk = x(kglob)
          yk = y(kglob)
          zk = z(kglob)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. dbuf2) then
             j = j + 1
             vlst(j,i) = displist(kglob)
          end if
        end do
        nvlst(i) = j
c
c     check to see if the neighbor list is too long
c
        if (nvlst(i) .ge. maxvlst) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' DLISTCELL  --  Too many Neighbors;',
     &                  ' Increase MAXVLST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
c
c    "dlistcell2" performs a complete rebuild of the
c     dispersion neighbor lists using linked cells method
c
      subroutine dlistcell2
      use atmlst
      use atoms
      use boxes
      use cutoff
      use disp
      use domdec
      use iounit
      use kvdws
      use neigh
      use vdw
      use mpi
      implicit none
      integer iglob,iloc
      integer i,icell,j,j1,k,nneigloc
      integer ineig,iidisp
      integer kcell,kglob
      integer ncell_loc
      integer, allocatable :: index(:),indcell_loc(:)
      real*8 xi,yi,zi,xk,yk,zk,r2
      real*8, allocatable :: pos(:,:),r2vec(:)
      logical docompute
      real*8 boxedge2
c
c     check size of the box and cutoff for minimum image convention
c
 1000 format('Error in dispersion neigbor list: max cutoff ',
     $   'buffer should be less than half one edge of the box')
 1010 format('Dispersion cutoff = ',F14.3)
 1020 format('List buffer      = ',F14.3)
      boxedge2 = min(xbox2,ybox2,zbox2)
      if (dbuf2.gt.boxedge2*boxedge2) then
        if (rank.eq.0) then
          write(iout,1000) 
          write(iout,1010) dispcut
          write(iout,1020) lbuffer
        end if
        call fatal
      end if
c
      allocate (index(nbloc))
      allocate (indcell_loc(nbloc))
      allocate(pos(3,nbloc))
      allocate(r2vec(nbloc))
c
c     perform a complete list build
c
      do i = 1, ndisplocnl
        iidisp = dispglobnl(i)
        iglob  = idisp(iidisp)
        icell = repartcell(iglob)
        iloc = loc(iglob)
        xi = x(iglob)
        yi = y(iglob)
        zi = z(iglob)
c
c       align data of the local cell and the neighboring ones
c
        ncell_loc = cell_len(icell)
        indcell_loc(1:ncell_loc) = 
     $  indcell(bufbegcell(icell):(bufbegcell(icell)+cell_len(icell)-1))
        do ineig = 1, numneigcell(icell)
          kcell = neigcell(ineig,icell)
          indcell_loc(ncell_loc+1:(ncell_loc+cell_len(kcell))) = 
     $  indcell(bufbegcell(kcell):(bufbegcell(kcell)+cell_len(kcell)-1))
          ncell_loc = ncell_loc + cell_len(kcell)
        end do
c
c       do the neighbor search
c
        nneigloc = 0 
        do k = 1, ncell_loc
          kglob = indcell_loc(k)
          if (kglob.le.iglob) cycle
          xk = x(kglob)
          yk = y(kglob)
          zk = z(kglob)
          pos(1,nneigloc+1) = xi - xk
          pos(2,nneigloc+1) = yi - yk
          pos(3,nneigloc+1) = zi - zk
          call midpointimage(xi,yi,zi,xk,yk,zk,pos(1,nneigloc+1),
     $       pos(2,nneigloc+1),pos(3,nneigloc+1),docompute)
          if (docompute) then
            nneigloc = nneigloc + 1
            index(nneigloc) = kglob
          end if
        end do
c
c       compute the distances and build the list accordingly
c
        r2vec(1:nneigloc) = pos(1,1:nneigloc)*pos(1,1:nneigloc) + 
     $      pos(2,1:nneigloc)*pos(2,1:nneigloc) + 
     $      pos(3,1:nneigloc)*pos(3,1:nneigloc)
        
        j = 0
        j1 = 0
        do k = 1, nneigloc
          r2 = r2vec(k)
          kglob = index(k)
          if (r2 .le. dshortbuf2) then
             j1 = j1 + 1
             shortvlst(j1,i) = displist(kglob)
          end if
          if (r2 .le. dbuf2) then
             j = j + 1
             vlst(j,i) = displist(kglob)
          end if
        end do
        nvlst(i) = j
        nshortvlst(i) = j1
c
c     check to see if the neighbor list is too long
c
        if (nvlst(i) .ge. maxvlst) then
           if (rank.eq.0) then
             write (iout,10)
   10        format (/,' DLISTCELL  --  Too many Neighbors;',
     &                  ' Increase MAXVLST')
             call fatal
           end if
        end if
      end do
c     
      deallocate (pos)
      deallocate (index)
      deallocate (indcell_loc)
      deallocate (r2vec)
      return
      end
