#
# 
#     Sorbonne University
#     Washington University in Saint Louis
#     University of Texas at Austin
# 

# 
# Compilation of Programs Tinker-HP's programs
# 

#
# Declare all the programs
#

bin_PROGRAMS =
bin_PROGRAMS += analyze
bin_PROGRAMS += dynamic
bin_PROGRAMS += minimize
bin_PROGRAMS += testgrad

#############################################
#
# Add your New main Here
#
# bin_PROGRAMMS +=  yourmain
#
#############################################

#
# Declare their sources and the dependencies
#

analyze_SOURCES       = analyze.f
analyze_DEPENDENCIES  = libtinkermod.a libtinkercalc.a

dynamic_SOURCES       = dynamic.f
dynamic_DEPENDENCIES  = libtinkermod.a libtinkercalc.a

minimize_SOURCES      = minimize.f
minimize_DEPENDENCIES = libtinkermod.a libtinkercalc.a

testgrad_SOURCES      = testgrad.f
testgrad_DEPENDENCIES = libtinkermod.a libtinkercalc.a

#############################################
#
# Add the sources of your new main Here
#
# yourmain_SOURCES      = yourmain.f
# yourmain_DEPENDENCIES = libtinkermod.a libtinkercalc.a
#
#############################################

#
# Declare the libraries they need
# 

#
# These libraries come from tinker 
#

LDADD  = libtinkercalc.a libtinkermod.a

#
# These libraries are external and defined by configure
#

LDADD += $(LIB2DECOMP_LIB) $(FFTW_LIBS) $(BLAS)

#
# Declare the Tinker libraries needed by the programs
#
# libtinkermod.a contains all the modules
# libtinkercal.a contains all the calculation routines
#

noinst_LIBRARIES = libtinkermod.a libtinkercalc.a

#
# states that libtinkercal.a depends upon libtinkermod.a
#
#
libtinkercalc_a_DEPENDENCIES = libtinkermod.a

#
# Declare the sources for the modules. They are compiled in this order
# That's why MOD_sizes.f in the first
#

BUILT_SOURCES=depend.mk

depend.mk: 
	-$(PYTHON) ./Tinker_deps.py *.f > $@

libtinkermod_a_SOURCES = 
libtinkermod_a_SOURCES += MOD_sizes.f
libtinkermod_a_SOURCES += MOD_action.f
libtinkermod_a_SOURCES += MOD_analyz.f
libtinkermod_a_SOURCES += MOD_angang.f
libtinkermod_a_SOURCES += MOD_angle.f
libtinkermod_a_SOURCES += MOD_angpot.f
libtinkermod_a_SOURCES += MOD_argue.f
libtinkermod_a_SOURCES += MOD_ascii.f
libtinkermod_a_SOURCES += MOD_atmlst.f
libtinkermod_a_SOURCES += MOD_atoms.f
libtinkermod_a_SOURCES += MOD_atmtyp.f
libtinkermod_a_SOURCES += MOD_bath.f
libtinkermod_a_SOURCES += MOD_bitor.f
libtinkermod_a_SOURCES += MOD_bndpot.f
libtinkermod_a_SOURCES += MOD_bond.f
libtinkermod_a_SOURCES += MOD_bound.f
libtinkermod_a_SOURCES += MOD_boxes.f
libtinkermod_a_SOURCES += MOD_cell.f
libtinkermod_a_SOURCES += MOD_charge.f
libtinkermod_a_SOURCES += MOD_chgpot.f
libtinkermod_a_SOURCES += MOD_chunks.f
libtinkermod_a_SOURCES += MOD_couple.f
libtinkermod_a_SOURCES += MOD_cutoff.f
libtinkermod_a_SOURCES += MOD_deriv.f
libtinkermod_a_SOURCES += MOD_divcon.f
libtinkermod_a_SOURCES += MOD_domdec.f
libtinkermod_a_SOURCES += MOD_energi.f
libtinkermod_a_SOURCES += MOD_ewald.f
libtinkermod_a_SOURCES += MOD_fft.f
libtinkermod_a_SOURCES += MOD_fields.f
libtinkermod_a_SOURCES += MOD_files.f
libtinkermod_a_SOURCES += MOD_freeze.f
libtinkermod_a_SOURCES += MOD_group.f
libtinkermod_a_SOURCES += MOD_improp.f
libtinkermod_a_SOURCES += MOD_imptor.f
libtinkermod_a_SOURCES += MOD_inform.f
libtinkermod_a_SOURCES += MOD_inter.f
libtinkermod_a_SOURCES += MOD_iounit.f
libtinkermod_a_SOURCES += MOD_kanang.f
libtinkermod_a_SOURCES += MOD_kangs.f
libtinkermod_a_SOURCES += MOD_katoms.f
libtinkermod_a_SOURCES += MOD_kbonds.f
libtinkermod_a_SOURCES += MOD_kchrge.f
libtinkermod_a_SOURCES += MOD_keys.f
libtinkermod_a_SOURCES += MOD_khbond.f
libtinkermod_a_SOURCES += MOD_kiprop.f
libtinkermod_a_SOURCES += MOD_kgeoms.f
libtinkermod_a_SOURCES += MOD_kitors.f
libtinkermod_a_SOURCES += MOD_kmulti.f
libtinkermod_a_SOURCES += MOD_kopbnd.f
libtinkermod_a_SOURCES += MOD_kopdst.f
libtinkermod_a_SOURCES += MOD_kpitor.f
libtinkermod_a_SOURCES += MOD_kpolr.f
libtinkermod_a_SOURCES += MOD_kstbnd.f
libtinkermod_a_SOURCES += MOD_ksttor.f
libtinkermod_a_SOURCES += MOD_ktorsn.f
libtinkermod_a_SOURCES += MOD_ktrtor.f
libtinkermod_a_SOURCES += MOD_kurybr.f
libtinkermod_a_SOURCES += MOD_kvdwpr.f
libtinkermod_a_SOURCES += MOD_kvdws.f
libtinkermod_a_SOURCES += MOD_langevin.f
libtinkermod_a_SOURCES += MOD_linmin.f
libtinkermod_a_SOURCES += MOD_math.f
libtinkermod_a_SOURCES += MOD_merck.f
libtinkermod_a_SOURCES += MOD_mpole.f
libtinkermod_a_SOURCES += MOD_mdstuf.f
libtinkermod_a_SOURCES += MOD_minima.f
libtinkermod_a_SOURCES += MOD_molcul.f
libtinkermod_a_SOURCES += MOD_moldyn.f
libtinkermod_a_SOURCES += MOD_mplpot.f
libtinkermod_a_SOURCES += MOD_mutant.f
libtinkermod_a_SOURCES += MOD_neigh.f
libtinkermod_a_SOURCES += MOD_opbend.f
libtinkermod_a_SOURCES += MOD_opdist.f
libtinkermod_a_SOURCES += MOD_output.f
libtinkermod_a_SOURCES += MOD_params.f
libtinkermod_a_SOURCES += MOD_pitors.f
libtinkermod_a_SOURCES += MOD_pme.f
libtinkermod_a_SOURCES += MOD_polar.f
libtinkermod_a_SOURCES += MOD_polgrp.f
libtinkermod_a_SOURCES += MOD_polpot.f
libtinkermod_a_SOURCES += MOD_potent.f
libtinkermod_a_SOURCES += MOD_precis.f
libtinkermod_a_SOURCES += MOD_ptable.f
libtinkermod_a_SOURCES += MOD_resdue.f
libtinkermod_a_SOURCES += MOD_ring.f
libtinkermod_a_SOURCES += MOD_scales.f
libtinkermod_a_SOURCES += MOD_shunt.f
libtinkermod_a_SOURCES += MOD_strbnd.f
libtinkermod_a_SOURCES += MOD_strtor.f
libtinkermod_a_SOURCES += MOD_timestat.f
libtinkermod_a_SOURCES += MOD_titles.f
libtinkermod_a_SOURCES += MOD_torpot.f
libtinkermod_a_SOURCES += MOD_tors.f
libtinkermod_a_SOURCES += MOD_tortor.f
libtinkermod_a_SOURCES += MOD_units.f
libtinkermod_a_SOURCES += MOD_uprior.f
libtinkermod_a_SOURCES += MOD_urey.f
libtinkermod_a_SOURCES += MOD_urypot.f
libtinkermod_a_SOURCES += MOD_usage.f
libtinkermod_a_SOURCES += MOD_virial.f
libtinkermod_a_SOURCES += MOD_vdw.f
libtinkermod_a_SOURCES += MOD_vdwpot.f
libtinkermod_a_SOURCES += MOD_vec.f
libtinkermod_a_SOURCES += MOD_utilvec.f
libtinkermod_a_SOURCES += MOD_vec_elec.f
libtinkermod_a_SOURCES += MOD_vec_vdw.f
libtinkermod_a_SOURCES += MOD_vec_mpole.f
libtinkermod_a_SOURCES += MOD_vec_polar.f
libtinkermod_a_SOURCES += MOD_vec_charge.f
libtinkermod_a_SOURCES += MOD_vec_list.f

#############################################
#
# Add your new routines here
#
# libtinkermod_a_SOURCES += MOD_xxxx.f
#
#############################################

#
# Declare the sources for the calculation routines
#
 
libtinkercalc_a_SOURCES =
libtinkercalc_a_SOURCES += active.f
libtinkercalc_a_SOURCES += analysis.f
libtinkercalc_a_SOURCES += analyze.f
libtinkercalc_a_SOURCES += angles.f
libtinkercalc_a_SOURCES += attach.f
libtinkercalc_a_SOURCES += basefile.f
libtinkercalc_a_SOURCES += beeman.f
libtinkercalc_a_SOURCES += bicubic.f
libtinkercalc_a_SOURCES += baoab.f
libtinkercalc_a_SOURCES += baoabrespa.f
libtinkercalc_a_SOURCES += bbk.f
libtinkercalc_a_SOURCES += bitors.f
libtinkercalc_a_SOURCES += bonds.f
libtinkercalc_a_SOURCES += bounds.f
libtinkercalc_a_SOURCES += calendar.f
libtinkercalc_a_SOURCES += chkpole.f
libtinkercalc_a_SOURCES += chkring.f
libtinkercalc_a_SOURCES += chkxyz.f
libtinkercalc_a_SOURCES += cholesky.f
libtinkercalc_a_SOURCES += cluster.f
libtinkercalc_a_SOURCES += command.f
libtinkercalc_a_SOURCES += commstuff.f
libtinkercalc_a_SOURCES += control.f
libtinkercalc_a_SOURCES += cspline.f
libtinkercalc_a_SOURCES += cutoffs.f
libtinkercalc_a_SOURCES += diis.f
libtinkercalc_a_SOURCES += drivermpi.f
libtinkercalc_a_SOURCES += dynamic.f
libtinkercalc_a_SOURCES += dcinduce_pme.f
libtinkercalc_a_SOURCES += dcinduce_pme2.f
libtinkercalc_a_SOURCES += eangang.f
libtinkercalc_a_SOURCES += eangang1.f
libtinkercalc_a_SOURCES += eangang3.f
libtinkercalc_a_SOURCES += eangle.f
libtinkercalc_a_SOURCES += eangle1.f
libtinkercalc_a_SOURCES += eangle3.f
libtinkercalc_a_SOURCES += ebond.f
libtinkercalc_a_SOURCES += ebond1.f
libtinkercalc_a_SOURCES += ebond3.f
libtinkercalc_a_SOURCES += echarge.f
libtinkercalc_a_SOURCES += echarge1vec.f
libtinkercalc_a_SOURCES += echarge3vec.f
libtinkercalc_a_SOURCES += ecrecip1.f
libtinkercalc_a_SOURCES += efld0_directvec.f
libtinkercalc_a_SOURCES += egeom.f
libtinkercalc_a_SOURCES += egeom1.f
libtinkercalc_a_SOURCES += egeom3.f
libtinkercalc_a_SOURCES += ehal.f
libtinkercalc_a_SOURCES += ehal1vec.f
libtinkercalc_a_SOURCES += ehal3vec.f
libtinkercalc_a_SOURCES += eimprop.f
libtinkercalc_a_SOURCES += eimprop1.f
libtinkercalc_a_SOURCES += eimprop3.f
libtinkercalc_a_SOURCES += eimptor.f
libtinkercalc_a_SOURCES += eimptor1.f
libtinkercalc_a_SOURCES += eimptor3.f
libtinkercalc_a_SOURCES += elj.f
libtinkercalc_a_SOURCES += elj1vec.f
libtinkercalc_a_SOURCES += elj3vec.f
libtinkercalc_a_SOURCES += empole.f
libtinkercalc_a_SOURCES += empole0.f
libtinkercalc_a_SOURCES += empole1vec.f
libtinkercalc_a_SOURCES += empole3vec.f
libtinkercalc_a_SOURCES += emrecip1.f
libtinkercalc_a_SOURCES += energy.f
libtinkercalc_a_SOURCES += eopbend.f
libtinkercalc_a_SOURCES += eopbend1.f
libtinkercalc_a_SOURCES += eopbend3.f
libtinkercalc_a_SOURCES += eopdist.f
libtinkercalc_a_SOURCES += eopdist1.f
libtinkercalc_a_SOURCES += eopdist3.f
libtinkercalc_a_SOURCES += epitors.f
libtinkercalc_a_SOURCES += epitors1.f
libtinkercalc_a_SOURCES += epitors3.f
libtinkercalc_a_SOURCES += epolar.f
libtinkercalc_a_SOURCES += epolarvec.f
libtinkercalc_a_SOURCES += epolar1vec.f
libtinkercalc_a_SOURCES += epolar3vec.f
libtinkercalc_a_SOURCES += eprecip1.f
libtinkercalc_a_SOURCES += erf.f
libtinkercalc_a_SOURCES += estrbnd.f
libtinkercalc_a_SOURCES += estrbnd1.f
libtinkercalc_a_SOURCES += estrbnd3.f
libtinkercalc_a_SOURCES += estrtor.f
libtinkercalc_a_SOURCES += estrtor1.f
libtinkercalc_a_SOURCES += estrtor3.f
libtinkercalc_a_SOURCES += etors.f
libtinkercalc_a_SOURCES += etors1.f
libtinkercalc_a_SOURCES += etors3.f
libtinkercalc_a_SOURCES += etortor.f
libtinkercalc_a_SOURCES += etortor1.f
libtinkercalc_a_SOURCES += etortor3.f
libtinkercalc_a_SOURCES += eurey.f
libtinkercalc_a_SOURCES += eurey1.f
libtinkercalc_a_SOURCES += eurey3.f
libtinkercalc_a_SOURCES += evcorr.f
libtinkercalc_a_SOURCES += extra.f
libtinkercalc_a_SOURCES += extra1.f
libtinkercalc_a_SOURCES += extra3.f
libtinkercalc_a_SOURCES += fatal.f
libtinkercalc_a_SOURCES += fft_mpi.f90
libtinkercalc_a_SOURCES += field.f
libtinkercalc_a_SOURCES += final.f
libtinkercalc_a_SOURCES += freeunit.f
libtinkercalc_a_SOURCES += geometry.f
libtinkercalc_a_SOURCES += getkey.f
libtinkercalc_a_SOURCES += getnumb.f
libtinkercalc_a_SOURCES += getprm.f
libtinkercalc_a_SOURCES += getstring.f
libtinkercalc_a_SOURCES += gettext.f
libtinkercalc_a_SOURCES += getword.f
libtinkercalc_a_SOURCES += getxyz.f
libtinkercalc_a_SOURCES += gradient.f
libtinkercalc_a_SOURCES += hybrid.f
libtinkercalc_a_SOURCES += image.f
libtinkercalc_a_SOURCES += initatom.f
libtinkercalc_a_SOURCES += initial.f
libtinkercalc_a_SOURCES += initprm.f
libtinkercalc_a_SOURCES += initres.f
libtinkercalc_a_SOURCES += invert.f
libtinkercalc_a_SOURCES += kangang.f
libtinkercalc_a_SOURCES += kangle.f
libtinkercalc_a_SOURCES += katom.f
libtinkercalc_a_SOURCES += kbond.f
libtinkercalc_a_SOURCES += kcharge.f
libtinkercalc_a_SOURCES += kewald.f
libtinkercalc_a_SOURCES += kgeom.f
libtinkercalc_a_SOURCES += kimprop.f
libtinkercalc_a_SOURCES += kimptor.f
libtinkercalc_a_SOURCES += kinetic.f
libtinkercalc_a_SOURCES += kmpole.f
libtinkercalc_a_SOURCES += kopbend.f
libtinkercalc_a_SOURCES += kopdist.f
libtinkercalc_a_SOURCES += kpitors.f
libtinkercalc_a_SOURCES += kpolar.f
libtinkercalc_a_SOURCES += kstrbnd.f
libtinkercalc_a_SOURCES += kstrtor.f
libtinkercalc_a_SOURCES += ktors.f
libtinkercalc_a_SOURCES += ktortor.f
libtinkercalc_a_SOURCES += kurey.f
libtinkercalc_a_SOURCES += kvdw.f
libtinkercalc_a_SOURCES += lattice.f
libtinkercalc_a_SOURCES += lbfgs.f
libtinkercalc_a_SOURCES += linalg.f
libtinkercalc_a_SOURCES += maxwell.f
libtinkercalc_a_SOURCES += mdinit.f
libtinkercalc_a_SOURCES += mdrest.f
libtinkercalc_a_SOURCES += mdsave.f
libtinkercalc_a_SOURCES += mdstat.f
libtinkercalc_a_SOURCES += mechanic.f
libtinkercalc_a_SOURCES += minimize.f
libtinkercalc_a_SOURCES += molecule.f
libtinkercalc_a_SOURCES += mpistuff.f
libtinkercalc_a_SOURCES += mutate.f
libtinkercalc_a_SOURCES += nblistvec.f
libtinkercalc_a_SOURCES += newinduce_pmevec.f
libtinkercalc_a_SOURCES += newinduce_pme2vec.f
libtinkercalc_a_SOURCES += nextarg.f
libtinkercalc_a_SOURCES += nexttext.f
libtinkercalc_a_SOURCES += nspline.f
libtinkercalc_a_SOURCES += number.f
libtinkercalc_a_SOURCES += numeral.f
libtinkercalc_a_SOURCES += openend.f
libtinkercalc_a_SOURCES += optsave.f
libtinkercalc_a_SOURCES += pmestuff.f
libtinkercalc_a_SOURCES += precise.f
libtinkercalc_a_SOURCES += pressure.f
libtinkercalc_a_SOURCES += prime.f
libtinkercalc_a_SOURCES += promo.f
libtinkercalc_a_SOURCES += prmkey.f
libtinkercalc_a_SOURCES += prtdyn.f
libtinkercalc_a_SOURCES += prtxyz.f
libtinkercalc_a_SOURCES += random.f
libtinkercalc_a_SOURCES += readdyn.f
libtinkercalc_a_SOURCES += readprm.f
libtinkercalc_a_SOURCES += readxyz.f
libtinkercalc_a_SOURCES += respa.f
libtinkercalc_a_SOURCES += rings.f
libtinkercalc_a_SOURCES += rotpole.f
libtinkercalc_a_SOURCES += search.f
libtinkercalc_a_SOURCES += sort.f
libtinkercalc_a_SOURCES += rattle.f
libtinkercalc_a_SOURCES += shakeup.f
libtinkercalc_a_SOURCES += suffix.f
libtinkercalc_a_SOURCES += switch.f
libtinkercalc_a_SOURCES += temper.f
libtinkercalc_a_SOURCES += testgrad.f
libtinkercalc_a_SOURCES += tmatxb_pmevec.f
libtinkercalc_a_SOURCES += torphase.f
libtinkercalc_a_SOURCES += torque.f
libtinkercalc_a_SOURCES += torquevec2.f
libtinkercalc_a_SOURCES += torsions.f
libtinkercalc_a_SOURCES += trimtext.f
libtinkercalc_a_SOURCES += unitcell.f
libtinkercalc_a_SOURCES += utils.f
libtinkercalc_a_SOURCES += verlet.f
libtinkercalc_a_SOURCES += version.f


#############################################
#
# Add your new routines here
#
# libtinkercalc_a_SOURCES += yourexplicitname.f
#
#############################################

#
#FLAGS to use for the compilation of all sources
#
 
#
# LIB2DECOMP_INC is only used when compiling fft_mpi.f90
# So, this include flag is used only for *.f90 sources
# For *.f sources, that would have been AM_FFLAGS
#
AM_FCFLAGS=$(LIB2DECOMP_INC)
 
#
# local cleaning of *.mod files
#


clean-local :
	-rm -f *.mod depend.mk *_genmod.f90 *.debug

#
# include dependencies (Key substituted by configure)
# It should not be an explicit "include depend.mk"
# because depend.mk is created AFTER automake has done its job
#
@INCLUDE_DEPEND_MK@
#
# End of Makefile.am
#
