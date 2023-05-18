#!/bin/bash
#set -x

#This script will Compare the chksum data of two folders
#Built to assist in the removal of duplicate directories
#It will find the folder with less files, assumed to be the one planned for removal
#Then it will give a report on the relative dates of cloned files

#collect path one and two from bash
PATHONE=$1
PATHTWO=$2

#removes any potensial old data
rm -f /tmp/p1chsm.dat
rm -f /tmp/p2chsm.dat

#collect chsm data of both paths
find "$PATHONE" -type f -exec cksum {} \; >> /tmp/p1chsm.dat
find "$PATHTWO" -type f -exec cksum {} \; >> /tmp/p2chsm.dat



#compares chsms to find path has more items
#stores path name to files
if(($(wc -l < /tmp/p1chsm.dat) > $(wc -l < /tmp/p2chsm.dat))) # using < in wc to avoid filename output
then  
	LARGECHSMDATA=$(echo /tmp/p1chsm.dat)
        SMALLCHSMDATA=$(echo /tmp/p2chsm.dat)
        LARGECHSMPATH=$PATHONE
        SMALLCHSMPATH=$PATHTWO
else # Technically runs if they contain the same amount of files.
	LARGECHSMDATA=$(echo /tmp/p2chsm.dat)
        SMALLCHSMDATA=$(echo /tmp/p1chsm.dat)
        LARGECHSMPATH=$PATHTWO
        SMALLCHSMPATH=$PATHONE 
        
fi

#informs user that the folders contain the same amount of items
if(($(wc -l < $LARGECHSMDATA) == $(wc -l < $SMALLCHSMDATA)))
then
echo 
echo Both Folders are the same size with $(wc -l < $LARGECHSMDATA ) items

else
echo 
echo $LARGECHSMPATH is the bigger path with $(wc -l < $LARGECHSMDATA) items
echo $SMALLCHSMPATH is the smaller path with $(wc -l < $SMALLCHSMDATA) tiems

fi

#compares chsm data
#might need to improve this script for time complexity
awk '{ print $1 }' $LARGECHSMDATA |  xargs -I {} sed -i.bak '/'{}'/d' $SMALLCHSMDATA

#cleans up report data
echo "" > /tmp/newfiles.txt
echo "" > /tmp/oldfiles.txt
echo "" > /tmp/notpresent.txt
echo "" > /tmp/notpresent.tmp

MODIFYLINE=$(stat library | grep -n Modify | cut -d : -f 1)

# loop that tests modify dates
lineN=1

while [ $lineN -le $(wc -l < $SMALLCHSMDATA) ];
do
#Extracts the file path
        smallfile=$(awk -v awkvar="$lineN" '{$1=""; $2=""; if(NR==awkvar)print $0}' $SMALLCHSMDATA)
        largefile=$(echo $smallfile | sed "s|$SMALLCHSMPATH|"$LARGECHSMPATH"/|")

	
#stores modify date of each dir
        smalldate=$(stat "$(echo $smallfile)" | awk -v mline="$MODIFYLINE" '{if(NR==mline)print$2,$3}')
      
	#if the file isn't present in larger directory skips run
	#prevents reporting it as a newer file
        if ! stat "$(echo $largefile)" &> /dev/null
        then 
        	((lineN++))
        	continue
        else
        	largedate=$(stat "$(echo $largefile)" | awk -v mline="$MODIFYLINE" '{if(NR==mline)print$2,$3}') 
        fi
        
        
	if (($(date --date="$smalldate" '+%s') < $(date --date="$largedate" '+%s'))) 
	then
                echo $smallfile >> /tmp/oldfiles.txt
        fi
	if (($(date --date="$smalldate" '+%s') > $(date --date="$largedate" '+%s'))) 
	then
                echo $smallfile >> /tmp/newfiles.txt
        fi
	((lineN++))
done

#formats data 
awk '{$1="";$2=""; print $0}' $SMALLCHSMDATA >> /tmp/notpresent.tmp
cut -c 3- /tmp/notpresent.tmp >> /tmp/notpresent.txt



#reporting 

echo 
echo -e "\e[4mThis report is for the files in $SMALLCHSMPATH\e[0m"
echo
echo [files with different chksums from $LARGECHSMPATH]
cat /tmp/notpresent.txt
echo
echo [files with newer versions in $SMALLCHSMPATH]
cat /tmp/newfiles.txt
echo
echo [files with older versions in $SMALLCHSMPATH]
cat /tmp/oldfiles.txt
echo

#cleaning up files
rm -f /tmp/notpresent.tmp
rm -f /tmp/notpresent.txt
rm -f /tmp/oldfiles.txt
rm -f /tmp/newfiles.txt
rm -f /tmp/p1chsm.dat
rm -f /tmp/p2chsm.dat
rm -f /tmp/p1chsm.dat.bak
rm -f /tmp/p2chsm.dat.bak



