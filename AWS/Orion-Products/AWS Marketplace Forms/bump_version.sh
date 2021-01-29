#!/bin/sh
while getopts p: flag
do
	case "${flag}" in
		p) product=${OPTARG};;
	esac
done

if [ ! -z "$product" ] 
	then
		ls | grep $product | awk 'match($0, "Orion-2020_2-([A-Z]+)v([0-9]+).xlsx", o) { printf "git mv Orion-2020_2-%sv%s.xlsx Orion-2020_2-%sv%s.xlsx\n", o[1], o[2], o[1], o[2]+1 }'
	else
		ls | awk 'match($0, "Orion-2020_2-([A-Z]+)v([0-9]+).xlsx", o) { printf "git mv Orion-2020_2-%sv%s.xlsx Orion-2020_2-%sv%s.xlsx\n", o[1], o[2], o[1], o[2]+1 }'
fi
