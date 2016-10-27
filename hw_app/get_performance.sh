#!/bin/bash

# Specify command to invoke your application below
TEST_CMD="./helloSPLlb"

# Make sure processors are set to performance instead of ondemand

# Make sure performance is available
NEW_GOV=false

if [ `grep -q performance /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors`]
then
    NEW_GOV=true
    # Save old freq settings
    declare -a CUR_GOVERNERS
    cpus=`ls -d /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor|wc -l `
    
    # store old values first
    for cpuf in `seq 0 $cpus`
    do
        CUR_GOVERNER[$cpuf]=`cat /sys/devices/system/cpu/cpu$cpuf/cpufreq/scaling_governor`
    done

    # Turn on turbo     
    for cpuf in `seq 0 $cpus`
    do
        echo performance >/sys/devices/system/cpu/cpu$cpuf/cpufreq/scaling_governor
    done
fi

ITERATIONS=1

# DO NOT EDIT the following
#===============================================================================================================

# CSR Addresses
PERF1C=0x27c
PERF1=0x28c

# Reset  
RESET_COUNTERS=0x10000000;
OUT_OF_RESET=0x00000000;

# cache controller port 0
P0_RDHIT=0x00000000;
P0_WRHIT=0x00000001;
P0_RDMIS=0x00000002;
P0_WRMIS=0x00000003;
P0_EVICT=0x0000000a;

# cahce controller port 1
P1_RDHIT=0x80000000;
P1_WRHIT=0x80000001;
P1_RDMIS=0x80000002;
P1_WRMIS=0x80000003;
P1_EVICT=0x8000000a;

VENDOR=0x8086
DEVICE=0xbcbc

for ((i=0; i<$ITERATIONS; i++))
do
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$RESET_COUNTERS
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$OUT_OF_RESET

        $TEST_CMD

        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P0_RDHIT                                   >> /dev/null
        p0rdh_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P0_WRHIT                                   >> /dev/null
        p0wrh_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P0_RDMIS                                   >> /dev/null
        p0rdm_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P0_WRMIS                                   >> /dev/null
        p0wrm_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P0_EVICT                                   >> /dev/null
        p0evict_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`    >> /dev/null

        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P1_RDHIT                                   >> /dev/null
        p1rdh_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P1_WRHIT                                   >> /dev/null
        p1wrh_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P1_RDMIS                                   >> /dev/null
        p1rdm_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P1_WRMIS                                   >> /dev/null
        p1wrm_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`      >> /dev/null
        setpci -d $VENDOR:$DEVICE $PERF1C.L=$P1_EVICT                                   >> /dev/null
        p1evict_end_value=`echo  "  $((16#$(setpci -d $VENDOR:$DEVICE $PERF1.L) ))"`    >> /dev/null

        echo "CACHE CHANNEL 0 "
        echo "P0 READ HIT  : $p0rdh_end_value"
        echo "P0 WRITE HIT : $p0wrh_end_value"
        echo "P0 READ MISS : $p0rdm_end_value"
        echo "P0 WRITE MISS: $p0wrm_end_value"
        echo "P0 EVICTIONS : $p0evict_end_value"

        echo "CACHE CHANNEL 1"
        echo "P1 READ HIT  : $p1rdh_end_value"
        echo "P1 WRITE HIT : $p1wrh_end_value"
        echo "P1 READ MISS : $p1rdm_end_value"
        echo "P1 WRITE MISS: $p1wrm_end_value"
        echo "P1 EVICTIONS : $p1evict_end_value"

        echo "TOTAL PERFORMANCE"
        echo "P0+P1 READ HIT   : $(expr $p1rdh_end_value + $p0rdh_end_value)"
        echo "P0+P1 WRITE HIT  : $(expr $p1wrh_end_value + $p0wrh_end_value)"
        echo "P0+P1 READ MISS  : $(expr $p1rdm_end_value + $p0rdm_end_value)"
        echo "P0+P1 WRITE MISS : $(expr $p1wrm_end_value + $p0wrm_end_value)"
        echo "P0+P1 EVICTIONS  : $(expr $p1evict_end_value + $p0evict_end_value)"

done

# restore governors
if [ NEW_GOV ]
then
    for cpuf in `seq 0 $cpus`
    do
        echo $i{CUR_GOVERNER[$cpuf]} >/sys/devices/system/cpu/cpu$cpuf/cpufreq/scaling_governor
    done
fi
