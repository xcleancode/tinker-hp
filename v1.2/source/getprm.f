c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     #############################################################
c     ##                                                         ##
c     ##  subroutine getprm  --  get force field parameter file  ##
c     ##                                                         ##
c     #############################################################
c
c
c     "getprm" finds the potential energy parameter file
c     and then opens and reads the parameters
c
c
      subroutine getprm
      use files
      use keys
      use iounit
      use params
      implicit none
      integer i,iprm,next,length
      integer freeunit
      logical exist,useprm
      character*4 none
      character*20 keyword
      character*240 prmfile
      character*240 record
      character*240 string
      character*240 paramdir
c
c
c     set the default name for the parameter file
c
      useprm = .true.
      prmfile = filename(1:leng)//'.prm'
c
c     search the keyword list for the parameter filename
c
      do i = 1, nkey
         next = 1
         record = keyline(i)
         call gettext (record,keyword,next)
         call upcase (keyword)
         if (keyword(1:11) .eq. 'PARAMETERS ') then
            string = record(next:240)
            next = 1
            call getstring (string,prmfile,next)
            if (next .eq. 1)  call gettext (string,prmfile,next)
         end if
      end do
c     Try to read $TINKER_PARAMS from environment
c     get_environment_variable is fortran intrinsic
      call get_environment_variable ('TINKER_PARAMS', paramdir,length)
c     if lenght is 0, the TINKER_PARAMS variable is not set
      if (length.ne.0) prmfile = trim(paramdir)//'/'//prmfile
c
c     check existence of default or specified parameter file
c
      call suffix (prmfile,'prm','old')
      inquire (file=prmfile,exist=exist)
c
c     test for user specified absence of a parameter file
c
      if (.not. exist) then
         none = prmfile(1:4)
         call upcase (none)
         if (none .eq. 'NONE') then
            exist = .true.
            useprm = .false.
         end if
      end if
c
c     try to get a parameter filename from the command line
c
      if (.not. exist) then
         call nextarg (prmfile,exist)
         if (exist) then
            call suffix (prmfile,'prm','old')
            inquire (file=prmfile,exist=exist)
         end if
      end if
c
c     if necessary, ask for the parameter filename
c
      do while (.not. exist)
         write (iout,10)
   10    format (/,' Enter Potential Parameter File Name :  ',$)
         read (input,20)  prmfile
   20    format (a240)
         next = 1
         call getword (prmfile,none,next)
         call upcase (none)
         if (none.eq.'NONE' .and. next.eq.5) then
            exist = .true.
            useprm = .false.
         else
            call suffix (prmfile,'prm','old')
            inquire (file=prmfile,exist=exist)
         end if
      end do
c
c     initialize force field control and parameter values
c
      call initprm
c
c     read the parameter file and store it for latter use
c
      nprm = 0
      if (useprm) then
         iprm = freeunit ()
         open (unit=iprm,file=prmfile,status='old')
         rewind (unit=iprm)
         do while (.true.)
            read (iprm,30,err=50,end=50)  record
   30       format (a240)
            nprm = nprm + 1
            prmline(nprm) = record
            if (nprm .ge. maxprm) then
               write (iout,40)
   40          format (/,' GETPRM  --  Parameter File Too Large;',
     &                    ' Increase MAXPRM')
               call fatal
            end if
         end do
   50    continue
         close (unit=iprm)
      end if
c
c     get control and parameter values from the parameter file
c
      if (useprm)  call readprm
      return
      end
