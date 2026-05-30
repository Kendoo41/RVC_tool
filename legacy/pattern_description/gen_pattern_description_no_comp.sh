#!/bin/sh -f
#===================================================================================================#
#  Author :  thuythanhnguyen                                                                        #
#===================================================================================================#

if [ $# -ne 3 ]; then
    echo "====================================================================="
    echo "- Wrong syntax"
    echo "- How to use:"
    echo "  + <script_name> <TM_LIST> <old_testcase> <new_testcase> <excel_name>"
    echo "====================================================================="
else

    tm_list=$1
    file_name="$3.xlsx"
    #old=$2
    new=$2

    # Remove redundant file if available
    #===============================================================================================#
    echo "======================================="
    echo "1. Clean up data "
    rm -f ".COMMON"
    rm -f ".LIST_ALL"
    rm -f ".TM_EXE"
    rm -f ".tem_tinh"
    rm -f ".vimdiff"

    # Main function                                                                                 #
    #===============================================================================================#
    echo "2. Prepare data "

    create_list.csh ${tm_list}   ./ ${new}
    gen_pattern_description_no_comp.pl  ${file_name} ./ ${new} 

    #===============================================================================================#

    sleep 1
fi

# Remove redundant file if available
#rm -f ".COMMON"
#rm -f ".LIST_ALL"
#rm -f ".TM_EXE"
rm -f ".tem_tinh"
rm -f ".vimdiff"
