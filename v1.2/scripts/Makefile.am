bin_SCRIPTS =
bin_SCRIPTS += tinkerhp
CLEANFILES=$(bin_SCRIPTS)
LINK_TO = tinkerhp

install-exec-hook:
	-(cd ${bindir} ; $(LN_S) -f $(LINK_TO) analyze  )
	-(cd ${bindir} ; $(LN_S) -f $(LINK_TO) bar      )
	-(cd ${bindir} ; $(LN_S) -f $(LINK_TO) dynamic  )
	-(cd ${bindir} ; $(LN_S) -f $(LINK_TO) dynamic_rep  )
	-(cd ${bindir} ; $(LN_S) -f $(LINK_TO) minimize )
	-(cd ${bindir} ; $(LN_S) -f $(LINK_TO) testgrad )

uninstall-binSCRIPTS:
	-(cd ${bindir} ; /bin/rm -f analyze bar dynamic dynamic_rep minimize testgrad tinkerhp )
