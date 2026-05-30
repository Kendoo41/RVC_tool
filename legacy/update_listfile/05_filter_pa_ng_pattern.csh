#!/bin/csh
set listfile = $1
set module_begin = $2

echo PASS
foreach passfile (`a9 | awk '{print $4}' | awk -F"/" '{print $NF}' | uniq`)
#foreach passfile (`a9 | awk '{print $3}' | awk -F"/" '{print $NF}' | uniq`)
    #set module_begin = `grep -w ${passfile} ${listfile} | awk -F"/" '{print $1}'`
    #if ("${module_begin}" !~ /#* ) then
    sed -i "/\<${passfile}\>/s/^${module_begin}/#PSS ${module_begin}/" ${listfile}
    #endif 
end

echo ""
echo FAIL
foreach ngfile (`ng | awk '{print $4}' | awk -F"/" '{print $NF}' | uniq`)
#foreach ngfile (`ng | awk '{print $3}' | awk -F"/" '{print $NF}' | uniq`)
    #set module_begin = `grep -w ${ngfile} ${listfile} | awk -F"/" '{print $1}'`
    # if ("${module_begin}" !~ /#* ) then
    sed -i "/\<${ngfile}\>/s/^${module_begin}/#NG  ${module_begin}/" ${listfile}
    # endif
end

echo ""
echo NORU
foreach nafile (`na | awk '{print $4}' | awk -F"/" '{print $NF}' | uniq`)
#foreach nafile (`na | awk '{print $3}' | awk -F"/" '{print $NF}' | uniq`)
    #set module_begin = `grep -w ${nafile} ${listfile} | awk -F"/" '{print $1}'`
    # if ("${module_begin}" !~ /#* ) then
    sed -i "/\<${nafile}\>/s/^${module_begin}/#NA  ${module_begin}/" ${listfile}
    #endif
end

