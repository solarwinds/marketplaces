#!/bin/sh

while getopts :hd:p:k: flag
do
	case "${flag}" in
		p) password=${OPTARG};;
        d) dbpassword=${OPTARG};;
        k) keyname=${OPTARG};;
        h)
            echo "Usage:"
            echo "    -h                      Display this help message."
            echo "    -d                      Set DB password."
            echo "    -p                      Set Orion password."
            echo "    -k                      Set key name."
            exit 0
            ;;
	esac
done

sed -e "s/{PASSWORD}/${password}/" .taskcat.yml.template | sed -e "s/{DBPASSWORD}/${dbpassword}/" | sed -e "s/{KEY}/${keyname}/" > .taskcat.yml