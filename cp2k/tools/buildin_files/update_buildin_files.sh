#!/bin/bash


truncate --size=0 BASIS_BUILDIN
cat ../../tests/QS/BASIS_SET      >> BASIS_BUILDIN
cat ../../tests/QS/GTH_BASIS_SETS >> BASIS_BUILDIN
cat ../../tests/QS/BASIS_MOLOPT   >> BASIS_BUILDIN
./txt2f90.py BASIS_BUILDIN buildin_basis_set > ../../src/aobasis/buildin_basis_set.F




#EOF
