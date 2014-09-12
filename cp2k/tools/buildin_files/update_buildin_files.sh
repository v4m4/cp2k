#!/bin/bash

# Regererates all buildin files.
# author: Ole Schuett

truncate --size=0 BUILDIN_BASIS_SET
cat ../../tests/QS/BASIS_SET      >> BUILDIN_BASIS_SET
cat ../../tests/QS/GTH_BASIS_SETS >> BUILDIN_BASIS_SET
cat ../../tests/QS/BASIS_MOLOPT   >> BUILDIN_BASIS_SET
./txt2f90.py BUILDIN_BASIS_SET buildin_basis_set > ../../src/aobasis/buildin_basis_set.F

truncate --size=0 BUILDIN_POTENTIALS
cat ../../tests/QS/GTH_POTENTIALS >> BUILDIN_POTENTIALS
./txt2f90.py BUILDIN_POTENTIALS buildin_potentials > ../../src/buildin_potentials.F

#EOF
