c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     ################################################################
c     ##                                                            ##
c     ##  subroutine control  --  set information and output types  ##
c     ##                                                            ##
c     ################################################################
c
c
c     "control" gets initial values for parameters that determine
c     the output style and information level provided by TINKER
c
c
      subroutine control
      implicit none
      include 'sizes.i'
      include 'argue.i'
      include 'inform.i'
      include 'keys.i'
      include 'output.i'
      integer i,next
      logical exist
      character*20 keyword
      character*120 record
      character*120 string
c
c
c     set default values for information and output variables
c
      digits = 4
      abort = .false.
      verbose = .false.
      debug = .false.
      holdup = .false.
      archive = .false.
      noversion = .false.
      overwrite = .false.
      cyclesave = .false.
c
c     check for control parameters on the command line
c
      exist = .false.
      do i = 1, narg-1
         string = arg(i)
         call upcase (string)
         if (string(1:2) .eq. '-V') then
            verbose = .true.
         else if (string(1:2) .eq. '-D') then
            debug = .true.
            verbose = .true.
         end if
      end do
c
c     search keywords for various control parameters
c
      do i = 1, nkey
         next = 1
         record = keyline(i)
         call gettext (record,keyword,next)
         call upcase (keyword)
         if (keyword(1:7) .eq. 'DIGITS ') then
            string = record(next:120)
            read (string,*,err=10)  digits
         else if (keyword(1:8) .eq. 'VERBOSE ') then
            verbose = .true.
         else if (keyword(1:6) .eq. 'DEBUG ') then
            debug = .true.
            verbose = .true.
         else if (keyword(1:11) .eq. 'EXIT-PAUSE ') then
            holdup = .true.
         else if (keyword(1:8) .eq. 'ARCHIVE ') then
            archive = .true.
         else if (keyword(1:10) .eq. 'NOVERSION ') then
            noversion = .true.
         else if (keyword(1:10) .eq. 'OVERWRITE ') then
            overwrite = .true.
         else if (keyword(1:11) .eq. 'SAVE-CYCLE ') then
            cyclesave = .true.
         end if
   10    continue
      end do
      return
      end
