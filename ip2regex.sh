#!/bin/sh
# IP2Regex - Converts ip range to regex
# Copyright (C) 2025 https://github.com/SlashUsrVin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

#SAMPLE INPUT: 192.168.1.0 192.168.1.255
#SAMPLE OUTPUT: (192)\.(168)\.(1)\.([0-9]|[2-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])

#Round down number to the nearest 10
round_down_10 () {
    num="$1"
    len_num="${#num}"
    pos10=$(( len_num - 1 ))

    if [ "$pos10" -lt 1 ]; then
        pos10="1"
    fi

    if [ "$len_num" -lt 2 ]; then
        rrd="0"
    else
        rrd=$(echo "$num" | cut -c1-${pos10})
        rrd=$(echo "${rrd}0")
    fi

    echo "$rrd"
}

#Round down number to the nearest 100
round_down_100 () {
    num="$1"
    len_num="${#num}"
    pos100=$(( len_num - 2 ))

    if [ "$pos100" -lt 1 ]; then
        pos100="1"
    fi

    if [ "$len_num" -lt 3 ]; then
        rrd="0"
    else
        rrd=$(echo "$num" | cut -c1-${pos100})
        rrd=$(echo "${rrd}00")
    fi

    echo "$rrd"
}

#Remove redundancy. i.e [0-0] gets updated to just 0, [1-1] gets updated to just 1, etc.
regx_cleanup () {
    in="$1"
    i="0"
    out="$in"

    while [ "$i" -lt 10 ]; do
        out=$(echo "$out" | sed "s/\[${i}\-${i}\]/${i}/g")
        i=$(( i + 1 ))
    done

    echo "$out"
}

#Converts IP range to Regular Expression
#SAMPLE INPUT: 192.168.1.0 192.168.1.255
#SAMPLE OUTPUT: (192)\.(168)\.(1)\.([0-9]|[2-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])
regx_num_rng () {
    rng_S="$1" 
    rng_E="$2"
    ret_rgx=""

    len_S="${#rng_S}"
    len_E="${#rng_E}"

    rng_diff=$(( rng_E - rng_S ))

    #round down to the nearest 10th
    rd_10_S=$(round_down_10 "$rng_S")
    rd_10_E=$(round_down_10 "$rng_E")
    rd_10_diff=$(( rd_10_E - rd_10_S ))

    #round down to the nearest 100th
    rd_100_S=$(round_down_100 "$rng_S")
    rd_100_E=$(round_down_100 "$rng_E")
    rd_100_diff=$(( rd_100_E - rd_100_S ))    

    #Identify parts to build
    #Check regex_table.txt
    if [ "$rng_diff" -ge 20 ] || [ "$rd_10_diff" -gt 0 ]; then
        p9="1"
    else
        p9="0"
    fi

    if [ "$rng_S" -le 99 ] && [ "$rng_E" -gt 99 ] && [ "$rd_10_S" -ne 90 ]; then
        p99="1"
    else
        p99="0"
    fi 

    if [ "$rng_S" -le 199 ] && [ "$rng_E" -gt 199 ] && [ "$rd_10_S" -ne 190 ]; then
        p199="1"
    else
        p199="0"
    fi

    pr10th_val=$(( rd_10_E - 10 ))

    if  [ "$pr10th_val" -ne 90 ] && [ "$pr10th_val" -ne 190 ] && [ "$pr10th_val" -ne "$rd_10_S" ] && [ "$rd_10_diff" -gt 0 ]; then
        pr10th="1"
    else
        pr10th="0"
    fi

    #Find constant for PART9 literal
    case "$len_S" in 
        1)
            cons_S=""
            ;;
        *)
            cut_to=$(( len_S - 1 ))
            if [ "$cut_to" -lt 1 ]; then
                cut_to="1"
            fi            
            cons_S=$(echo "$rng_S" | cut -c1-${cut_to})
            ;;
    esac

    #Find ones starting range 
    p9_1s_rng_S=$(echo "$rng_S" | cut -c${len_S})

    #Find constant for FIN9 literal
    case "$len_E" in 
        1)
            cons_E=""
            ;;
        *)
            cut_to=$(( len_E - 1 ))
            if [ "$cut_to" -lt 1 ]; then
                cut_to="1"
            fi               
            cons_E=$(echo "$rng_E" | cut -c1-${cut_to})
            ;;
    esac

    #Find ones ending range 
    f9_1s_rng_E=$(echo "$rng_E" | cut -c${len_E})
    
    #Find ones starting range for FIN9
    if [ "$p9" -eq 1 ]    || \
       [ "$p99" -eq 1 ]   || \
       [ "$p199" -eq 1 ] || \
       [ "$pr10th" -eq 1 ]; then
        f9_1s_rng_S="0"
    else
        f9_1s_rng_S=$(echo "$rng_S" | cut -c${len_S})
        
    fi
    
    #Find ones ending range for PART9
    if  [ "$rd_10_diff" -lt 10 ]; then 
        p9_1s_rng_E="$f9_1s_rng_E"
    else
        #PART9 ending range is always 9 unless rd_10_diff is less than 10
        p9_1s_rng_E="9"
    fi
    
    #Build Regular Expression
    #This is how range 1-255 is built
    # <PART9>      <PART99>         <PART199>        <PRIOR-10TH>      <FIN9>
    #  1-9          10-99            100-199           200-249         250-255
    # [1-9]   |   [1-9][0-9]   |   1[0-9][0-9]   |   2[0-4][0-9]   |   25[0-5]    
    
    #PART9
    if [ "$p9" -eq 1 ]; then
        ret_rgx="${cons_S}[${p9_1s_rng_S}-${p9_1s_rng_E}]"
    fi

    #PART99
    if [ "$p99" -eq 1 ]; then
        if [ -z "$cons_S" ]; then
            #Start at the next 10s. If range starts at < 20, P99 range start is 20: 1[0-9]|[2-9][0-9]
            p99_10s_rng_S="1" 
        else
            #Start at the next 10s. If range starts at 21, P99 range start is 30: 2[1-9]|[3-9][0-9]
            p99_10s_rng_S=$(( cons_S + 1 ))  
        fi
        
        ret_rgx="$ret_rgx|[${p99_10s_rng_S}-9][0-9]"
    fi

    #PART199
    if [ "$p199" -eq 1 ]; then
        second10s=$(( rd_10_S + 10 ))
        #i.e if starting range is 142. rd_10 is 140, second10s is 150. 
        #Therefore, PART9 is 14[2-9] and PART199 is 150-199
        #14[2-9]|1[5-9][0-9]

        cons_199_S="1" 
        
        if [ "$p99" -eq 1 ]; then
            p199_10s_rng_S="0" 
        else
            p199_10s_rng_S=$(echo "$second10s" | cut -c2)
        fi
        
        ret_rgx="$ret_rgx|${cons_199_S}[${p199_10s_rng_S}-9][0-9]"
    fi

    #PRIOR-10TH
    if [ "$pr10th" -eq 1 ]; then
        prev10s=$(( rd_10_E - 10 ))
        #i.e if ending range is 222. rd_10 is 220, prev10s is 210. 
        #Therefore, PRIOR-10TH is 210-219 and FIN9 is 220-222
        #21[0-9]|22[0-2]

        if [ "$p99" -eq 1 ] || [ "$p199" -eq 1 ] || [ "$rd_10_S" -eq 90 ]; then
            pr10th_10s_S="0"  
        else
            second10s=$(( ${cons_S:-0} + 1 ))

            case "$len_S" in
                1)
                    pr10th_10s_S="1"  
                    ;;
                2)
                    pr10th_10s_S=$(echo "$second10s" | cut -c1)
                    ;;
                3)
                    pr10th_10s_S=$(echo "$second10s" | cut -c2)
                    ;;
            esac
        fi 

        if [ "$len_E" -lt 3 ]; then
            cons_pr10=""
            pr10th_10s_E=$(echo "$prev10s" | cut -c1)
        else
            cons_pr10=$(echo "$prev10s" | cut -c1)
            pr10th_10s_E=$(echo "$prev10s" | cut -c2)
        fi
        
        ret_rgx="$ret_rgx|${cons_pr10}[${pr10th_10s_S}-${pr10th_10s_E}][0-9]"
    fi

    #FIN9
    if [ ! -z "$ret_rgx" ]; then
        ret_rgx="${ret_rgx}|"
    fi
    ret_rgx="${ret_rgx}${cons_E}[${f9_1s_rng_S}-${f9_1s_rng_E}]"

    ret_rgx=$(regx_cleanup "$ret_rgx")

    echo "$ret_rgx"
}

####################################################
# MAIN 
####################################################

ip_start="$1"
ip_end="$2"

if [ -z "$ip_end" ]; then
    ip_end="$ip_start"
fi

#Split IP starting range to 4 parts
set -- $(echo "$ip_start" | awk -F. '{print $1, $2, $3, $4}')
s1="$1"
s2="$2"
s3="$3"
s4="$4"
#Split IP ending range to 4 parts
set -- $(echo "$ip_end" | awk -F. '{print $1, $2, $3, $4}')
e1="$1"
e2="$2"
e3="$3"
e4="$4"

if [ "$s1" -eq "$e1" ]; then
    o1="$s1"
else
    o1=$(regx_num_rng "$s1" "$e1")
fi

if [ "$s2" -eq "$e2" ]; then
    o2="$s2"
else
    o2=$(regx_num_rng "$s2" "$e2")
fi

if [ "$s3" -eq "$e3" ]; then
    o3="$s3"
else
    o3=$(regx_num_rng "$s3" "$e3")
fi

if [ "$s4" -eq "$e4" ]; then
    o4="$s4"
else
    o4=$(regx_num_rng "$s4" "$e4")
fi

echo "($o1)\.($o2)\.($o3)\.($o4)"