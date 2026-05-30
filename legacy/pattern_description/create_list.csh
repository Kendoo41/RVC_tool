#!/bin/csh -f
#===============================================================================
#===============================================================================

set TM       = $1
set OLD      = $2
set NEW      = $3
set TM_LIST  = .TM_EXE
set LIST     = .LIST_ALL
set COMMON   = .COMMON
set cnt      = 1
cat ${TM} | sort > ! ${TM_LIST}
rm -f ${LIST}
rm -f ${COMMON}
touch ${LIST}

sed -i 's/^ \+//g'      ${TM_LIST}
sed -i 's/\t \+/ /g'    ${TM_LIST}
sed -i 's/ \+/ /g'      ${TM_LIST}
sed -i '/^#/d'          ${TM_LIST}
sed -i '/^--/d'         ${TM_LIST}
sed -i '/^$/d'          ${TM_LIST}
sed -i 's/ .*//g'       ${TM_LIST}

foreach PAT (`cat ${TM_LIST}`)
    if ( ! -e ${NEW}/${PAT} ) then
        echo "${cnt} - Warning! Pattern is not exist: ${NEW}/${PAT}"
        @ cnt++
        goto NEXT
    endif

#    printf "${PAT}" >> ${LIST}

#    printf "${PAT}.s" >> ${LIST}
    if ( `ls ${NEW}/${PAT} | grep -c '\.s$'` ) then
     printf "${PAT}.s" >> ${LIST}
    else if ( `ls ${NEW}/${PAT} | grep -c '\.asm$'` ) then
     printf "${PAT}.asm" >> ${LIST}
    else if ( `ls ${NEW}/${PAT} | grep -c '\.c$'` ) then
     printf "${PAT}.c" >> ${LIST}
    else if ( `ls ${NEW}/${PAT} | grep -c '\.S$'` ) then
     printf "${PAT}.S" >> ${LIST}
    endif

    if ( `ls ${NEW}/${PAT} | grep -c '\.v$'` ) then
        foreach file ( `ls -1 ${NEW}/${PAT} | grep '\.v$'`)
            printf " ${file}" >> ${LIST}
        end
    endif

    if ( `ls ${NEW}/${PAT} | grep -c '\.sv$'` ) then
        foreach file ( `ls -1 ${NEW}/${PAT} | grep '\.sv$'`)
            printf " ${file}" >> ${LIST}
        end
    endif

    echo "" >> ${LIST}
    NEXT:
end

# if ( -e ${NEW}/common ) then
 if ( `find ${NEW}/common* -type f | wc -l `) then
#     find ${NEW}/common | sed -n 's/.*\(common.*\)/\1/p' | egrep '\.v|\.sv|\.inc|\.ld' > ! ${COMMON}
     find ${NEW}/common* -type f | sed -n 's/.*\(common.*\/\)/\1/p'  > ! ${COMMON}
 endif
