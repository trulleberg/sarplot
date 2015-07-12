#! /bin/bash
#
# sartool.bash
# Copyright (C) 2015 Hannes|L3 <hanbel@de.ibm.com>
#
#Path to SAR executable, usefull if you want to plot files from OLDER SAR data
SAR=/usr/bin/sar

#Make sure we have the proper LANG Setting, this prevents AM/PM times!
export LANG=C
export S_TIME_FORMAT=ISO

if [ -e allnodes-CPU.png ] ; 
    then 
        rm *.png
        echo "$(date +%Y-%m-%d.%H:%M:%S) Removed the old pictures"
fi



# Convert binary SAR files to TXT
#for SAFILE in $($FIND -L data/ -name sa0*) ; do
for SAFILE in $(find -L data/  -regex '.*sa[0-9]*') ; do
    if [ -e "$SAFILE" ]; then
        NODENAME=$($SAR -u -f "$SAFILE" |head -n1 |grep -Po '\(\K[^\)]+' |head -n1)
        #DATE=$($SAR -u -f "$SAFILE" |head -n1 |grep -Po '\d{2}/\d{2}/\d{2}' | tr -d "/" |awk 'BEGIN {OFS="-"} {print substr($1,5,2), substr($1,1,2), substr($1,3,2)}')
        DATE=$($SAR -u -f "$SAFILE" |head -n1 |grep -Po '\d{4}-\d{2}-\d{2}')
        #Gather CPU data from the SAR files
        $SAR -t -u -f "$SAFILE" |grep -P '\d{2}:\d{2}:\d{2}' > "$DATE"_"$NODENAME".cpu.stat
        sed -i 's/^/'"$DATE"T'/' "$DATE"_"$NODENAME".cpu.stat
        sed -i 's/$/'" $NODENAME"'/' "$DATE"_"$NODENAME".cpu.stat
        sed -i 's/  */ /g' "$DATE"_"$NODENAME".cpu.stat
        #Gather SWAP data
        $SAR -t -S -f "$SAFILE" |grep -P '\d{2}:\d{2}:\d{2}' > "$DATE"_"$NODENAME".swap.stat
        sed -i 's/^/'"$DATE"T'/' "$DATE"_"$NODENAME".swap.stat
        sed -i 's/$/'" $NODENAME"'/' "$DATE"_"$NODENAME".swap.stat
        sed -i 's/  */ /g' "$DATE"_"$NODENAME".swap.stat
        #Gather memory usage stats
        $SAR -t -r -f "$SAFILE" |grep -P '\d{2}:\d{2}:\d{2}' > "$DATE"_"$NODENAME".memory.stat
        sed -i 's/^/'"$DATE"T'/' "$DATE"_"$NODENAME".memory.stat
        sed -i 's/$/'" $NODENAME"'/' "$DATE"_"$NODENAME".memory.stat
        sed -i 's/  */ /g' "$DATE"_"$NODENAME".memory.stat
        #Gather load usage sats
        $SAR -t -q -f "$SAFILE" |grep -P '\d{2}:\d{2}:\d{2}' > "$DATE"_"$NODENAME".load.stat
        sed -i 's/^/'"$DATE"T'/' "$DATE"_"$NODENAME".load.stat
        sed -i 's/$/'" $NODENAME"'/' "$DATE"_"$NODENAME".load.stat
        sed -i 's/  */ /g' "$DATE"_"$NODENAME".load.stat
        #Gather disk stats
        $SAR -t -d -f "$SAFILE" |grep -P '\d{2}:\d{2}:\d{2}' > "$DATE"_"$NODENAME".disk.stat
        sed -i 's/^/'"$DATE"T'/' "$DATE"_"$NODENAME".disk.stat
        sed -i 's/$/'" $NODENAME"'/' "$DATE"_"$NODENAME".disk.stat
    else
      echo "$(date +%Y-%m-%d.%H:%M:%S) Data folder or SAR files not found"
      exit
    fi
done
sed -i '/LINUX RESTART/d' *.stat

echo "$(date +%Y-%m-%d.%H:%M:%S) Found SAR Files and converted them to *.stats files."

for NODE in $(ls *.stat |xargs -n1 head -n1 | awk '{print $NF}' | uniq) ; do
    echo "$(date +%Y-%m-%d.%H:%M:%S) Found stats for Host: $NODE"
    # Create one file for each node per stat! Remove duplicate headers with sed
    grep -h "$NODE" *.cpu.stat |sed '1!{/user/d};'  |sort -g > "$NODE".cpu.stats
    if ! [ $(head -n 1 "$NODE".cpu.stats|grep -q user) ]; then
        SARHEAD=$(grep user "$NODE".cpu.stats)
        sed -i "1 i$SARHEAD" "$NODE".cpu.stats
        sed -i '1!{/user/d}' "$NODE".cpu.stats
    fi
    grep -h "$NODE" *.swap.stat | sed '1!{/kbswpfree/d}' |sort -g > "$NODE".swap.stats
    if ! [ $(head -n 1 "$NODE".swap.stats|grep -q swp) ]; then
        SARHEAD=$(grep kbswpfree "$NODE".swap.stats)
        sed -i "1 i$SARHEAD" "$NODE".swap.stats
        sed -i '1!{/kbswpfree/d}' "$NODE".swap.stats
    fi

    # join the cpu and swap stats
    join --header "$NODE".cpu.stats "$NODE".swap.stats > "$NODE".cpu.swap.stats
    grep -h "$NODE" *.memory.stat|sed '1!{/kbmemfree/d};' | sort -g > "$NODE".memory.stats
    if ! [ $(head -n 1 "$NODE".memory.stats|grep -q kbmemfree) ]; then
        SARHEAD=$(grep kbmemfree "$NODE".memory.stats)
        sed -i "1 i$SARHEAD" "$NODE".memory.stats
        sed -i '1!{/kbmemfree/d}' "$NODE".memory.stats
    fi
    join --header "$NODE".cpu.swap.stats "$NODE".memory.stats > "$NODE".cpu.swap.memory.stats
    grep -h "$NODE" *.load.stat|sed '1!{/runq-sz/d};' | sort -g > "$NODE".load.stats
    if ! [ $(head -n 1 "$NODE".load.stats|grep -q runq) ]; then
        SARHEAD=$(grep runq "$NODE".load.stats)
        sed -i "1 i$SARHEAD" "$NODE".load.stats
        sed -i '1!{/runq/d}' "$NODE".load.stats
    fi
    join --header "$NODE".cpu.swap.memory.stats "$NODE".load.stats > "$NODE".cpu.swap.memory.load.stats
    grep -h "$NODE" *.disk.stat|sed '1!{/DEV/d};' | sort -g | tr -d "_"> "$NODE".disk.stats
    if ! [ $(head -n 1 "$NODE".disk.stats|grep -q DEV) ]; then
        SARHEAD=$(grep DEV "$NODE".disk.stats)
        sed -i "1 i$SARHEAD" "$NODE".disk.stats
        sed -i '1!{/DEV/d}' "$NODE".disk.stats
    fi
    join --header "$NODE".cpu.swap.memory.load.stats "$NODE".disk.stats > "$NODE".all.stats
done

echo "$(date +%Y-%m-%d.%H:%M:%S) Starting to Plot the data"

gnuplot << EOF
       ##GENERAL Settings
       # line styles
        set linetype 1 lt 1 lc rgb '#1B9E77' # dark teal
        set linetype 2 lt 1 lc rgb '#D95F02' # dark orange
        set linetype 3 lt 1 lc rgb '#7570B3' # dark lilac
        set linetype 4 lt 1 lc rgb '#E7298A' # dark magenta
        set linetype 5 lt 1 lc rgb '#66A61E' # dark lime green
        set linetype 6 lt 1 lc rgb '#E6AB02' # dark banana
        set linetype 7 lt 1 lc rgb '#A6761D' # dark tan
        set linetype 8 lt 1 lc rgb '#666666' # dark gray
       ##Define the Grid
        set style line 102 lc rgb '#808080' lt 0 lw 1
        set grid back ls 102
       ##Define the X&YBorders&Tics
        set style line 101 lc rgb '#808080' lt 1 lw 1
        set border 3 front 
        set tics nomirror out scale 0.75
        set xtic auto
        set ytic auto
        set autoscale
       ##Define the Legend 
        set key box
        set key ins vert left top
       ##Define the separator 
        set datafile separator " "
       ##Define the output format, type and the used font 
        set terminal pngcairo size 1500,1000 enhanced font 'sans,10'

       ##DEFINE the X-Axis
        set xlabel "Time"
        set xdata time
        set format x "%d.%m.%y\n%H:%M"                      #How is the time printed
        set timefmt "%Y-%m-%dT%H:%M:%S"                     #How is the time defined in the source file
        set xrange [ "2015-07-11T20:00:00" : "2015-07-12T16:00:00"  ] writeback  # Define the time/X Range to print (format like in source file, eg 15-05-07T14:10:01)

       ##Export the CPU Graph
        set title "CPU usage over all nodes"
        set ylabel "LOAD (System + Nice + User)"
        set output "allnodes-CPU.png"
    ###    show xrange
        filelist=system("ls *.all.stats")
        plot for [filename in filelist] filename using 1:(\$3+\$4+\$5) title column(9) with lines
        set output

       ##Export the SWAP graph 
        set title "SWAP usage over all nodes"
        set ylabel "% Used "
        set output "allnodes-SWAPusage.png"
        set yrange [0:100]
        filelist=system("ls *.all.stats")
        plot for [filename in filelist] filename using 1:"%swpused" with lines title column(9)
        set output

        

       ##Export the Memory graphs for all nodes
        set title "Memory usage over all nodes in MB"
        set ylabel "MB used"
        set key ins vert
        set key bottom left
        #####set autoscale
        set autoscale y
        set out "allnodes-MEMORY-used.png"
        filelist=system("ls *.all.stats")
        plot for [filename in filelist] filename using 1:(\$17/1024) with lines title column(9)
        set out
        set title "Memory usage over all nodes in %"
        set ylabel "% Used"
        set out "allnodes-MEMORY-used-percent.png"
        plot for [filename in filelist] filename using 1:"%memused" with lines title column(9)
        set out

       ##Multiplot per node
        filelist=system("ls *.all.stats")
        do for [filename in filelist] {
            set output sprintf("%s.png",filename)
            set multiplot title sprintf("%s",filename)

            set size 1,0.48
            set origin 0,0.5
            set key ins vert
            set key left top
            set title "CPU, SWAP and Memory usage in %"
            set ylabel "% Used"
            set yrange [0:100]
            #set autoscale y
            plot filename using 1:(\$3+\$4+\$5) with filledcurve x1 lc rgb "grey" title "cpu usage",\
                 filename using 1:"%user"      with lines title columnheader,\
                 filename using 1:"%nice"       with lines title columnheader,\
                 filename using 1:"%system"     with lines title columnheader,\
                 filename using 1:"%swpused"    with lines title columnheader,\
                 filename using 1:"%memused"    with lines title columnheader,\
                 filename using 1:"%util"       with lines linetype 1 title "%util on disk"

            set title "load"
            set autoscale y
            set ylabel "load"
            set size 1,0.25
            set origin 0,0.25
            plot filename using 1:"ldavg-1"     with lines title columnheader,\
                 filename using 1:"ldavg-5"     with lines title columnheader,\
                 filename using 1:"ldavg-15"    with lines title columnheader

            set title "Local disk usage"
            set autoscale y
            set ylabel "# of Requests /s"
            set size 1,0.25
            set origin 0,0.0
            plot filename using 1:"rdsec/s"    with lines title columnheader,\
                filename using 1:"wrsec/s"    with lines title columnheader

        unset multiplot
        unset output
        }
EOF
echo "$(date +%Y-%m-%d.%H:%M:%S) Finished the Plot, cleaning up"
rm *.stats
rm *.stat
