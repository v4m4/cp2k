#!/usr/bin/env python
# -*- coding: utf-8 -*-

# author: Ole Schuett

import sys
import re
re_start    = re.compile(r"(=|CALL)\s+cp_dbcsr")

re_err     = re.compile(r",\s*error(\s*=\s*error)?[) ]")
re_err2    = re.compile(r",\s*error(\s*=\s*error)?")
re_err3    = re.compile(r"^\s*error(\s*=\s*error)?\s*\)\s*$")

EXCEPTIONS = ["cp_dbcsr_heevd", "cp_dbcsr_sm_fm_multiply", "cp_dbcsr_write_sparse_matrix",
              "cp_dbcsr_syevd", "cp_dbcsr_cholesky_invert", "cp_dbcsr_cholesky_decompose",
               "cp_dbcsr_copy_columns_hack", "cp_dbcsr_plus_fm_fm_t", 
               "cp_dbcsr_alloc_block_from_nbl", "cp_dbcsr_sm_fm_multiply",
               "cp_dbcsr_dist2d_to_dist", "cp_dbcsr_from_fm", "cp_dbcsr_cholesky_restore",]

#===============================================================================
def main():
    fn = sys.argv[1]
    print "Working on ", fn

    content = open(fn).read()
    output = ""

    cont = False
    for line in content.split("\n"):
        if(re_start.search(line) or cont):
            if(any([(e in line) for e in EXCEPTIONS])):
                print "Skipping: ", line
                cont = False
            elif(re_err.search(line)):
                print "OLD: ",line
                line = re_err2.sub("", line)
                print "NEW: ",line
                cont = False

            elif(cont and re_err3.match(line)):
                print "Found: ", line
                m = re.match(r"(^.*)(,\s*?\s*?&\s*?)\n$", output, re.DOTALL)
                output = m.group(1)
                line = ")"
                cont = False

            else:
                cont = line.strip().endswith("&")

        output += line + "\n"

    f = open(fn, "w")
    f.write(output)

#===============================================================================
main()

#EOF
