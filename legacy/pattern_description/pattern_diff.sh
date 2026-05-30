#!/bin/sh -f
#===================================================================================================#
#  Author :  thuythanhnguyen                                                                  #
#===================================================================================================#

if [ $# -ne 5 ]; then
    echo "====================================================================="
    echo "- Wrong syntax"
    echo "- How to use:"
    echo "  + <script_name> <TM_LIST> <old_testcase> <new_testcase> <excel_name>"
    echo "====================================================================="
else

    tm_list=$1
    opt=$2

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


    if ($opt == "comp") then
       old=$3
       new=$4
       file_name="$5.xlsx"
       create_list.csh ${tm_list}   ${old} ${new}
       ./gen_pattern_description_comp.pl  ${file_name} ${old} ${new}     
    else
       old="./"
       new=$3
       file_name="$4.xlsx"
       create_list.csh ${tm_list}   ${old} ${new}
       ./gen_pattern_description_no_comp.pl ${file_name} ${old} ${new}
    fi
    #diff_to_excel.pl  ${file_name} ${old} ${new}     

    #===============================================================================================#

    sleep 1
fi

# Remove redundant file if available
#rm -f ".COMMON"
#rm -f ".LIST_ALL"
#rm -f ".TM_EXE"
rm -f ".tem_tinh"
rm -f ".vimdiff"
