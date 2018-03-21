#!/usr/local/bin/bash

#logfile=/tmp/batch-encode.log
#exec > $logfile 2>&1
PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/root/bin
renice 19 -p $$

unset regextitle
unset regexwidth
unset regexcodec

if [[ -n "$@" ]]
	then
	#input=$(printf %q "$@")
	input="$@"
	method="commandline"
	elif [[ -n $radarr_moviefile_path ]]
	then
	#input=$(printf %q "$radarr_moviefile_path")
	input="$radarr_moviefile_path"
	method="radarr"
	else
	echo "No input file provided"
	exit 1
fi



dir=$(dirname "$input")
filename=$(basename "$input")
extension="${filename##*.}"
filename="${filename%.*}"
regextitle="^(.+?)[.(\s]*(?:(?:(19\d{2}|20(?:0\d|1[0-9]))).*|(?:(?=bluray|\d+p|brrip|WEBRip)..*)?[.](mkv|avi|mpe?g|mp4|m4v)$)"
regexwidth="\"width\":\s(\d+),"
regexcodec="\"codec_name\":\s\"(.+)\""
#regexcodec="codec_name=(h264)"
export regextitle
export regexwidth
export regexcodec
echo $input
	


if [[ -n "$input" ]] && [ -f "$input" ]; 
	then
	#get movie name and year
	mtitle=`echo "$filename" | perl -ne '/$ENV{'regextitle'}/ && print "$1\n";'| tr . " "`
	myear=`echo "$filename" | perl -ne '/$ENV{'regextitle'}/ && print "$2\n";'| tr . " "`
	
	#detect-size

	        #delineate new log
		logtitle="${mtitle// /_}"
		today=$(date +"%Y_%m_%d_%H%M%S_")
		logfile="/tmp/encode_$today$logtitle-$myear.log"
        	#logfile="/tmp/encode_$today.log"
		echo "-------------------------------------------------" > "$logfile"
        	echo "INFO: BEGIN batch analysis: $(date)" >> "$logfile"
        	echo "-------------------------------------------------" >> "$logfile"

	echo "$mtitle" >> "$logfile"
	echo "$myear" >> "$logfile"
	echo "$input" >> "$logfile"
	
	ffprobe -v quiet -print_format json -show_streams -i "$input" >> "$logfile"
	
	rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
	
	mwidth=`cat $logfile | perl -0777 -ne '/$ENV{'regexwidth'}/ && print "$1\n";'`
	mcodec=`cat $logfile | perl -0777 -ne '/$ENV{'regexcodec'}/ && print "$1\n";'`
	
	#make filename
	if [ -z "$mtitle" ] || [ -z "$myear" ]
		then
		read -p "Movie Title : " mtitle
		read -p "Release Year : " myear
	fi
	echo "Input: "$input
	echo "Title:"$mtitle
	echo "Year: "$myear
	echo "Width: "$mwidth
	echo "Codec: "$mcodec
	echo "Filename: "$filename
	echo "Extension: "$extension
	echo "-------------------------------------"
	#DEBUG-----------------------------------------------------------
	
	#######
	echo "Input: "$input >> "$logfile"
	echo "Title:"$mtitle >> "$logfile"
	echo "Year: "$myear >> "$logfile"
	echo "Width: "$mwidth >> "$logfile"
	echo "Codec: "$mcodec >> "$logfile"
	echo "Filename: "$filename >> "$logfile"
	echo "Extension: "$extension >> "$logfile"
	echo "Method: "$method >> "$logfile"
	echo "Dir: "$dir >> "$logfile"
	echo "Regextitle: "$regextitle >> "$logfile"
	echo "Regexwidth: "$regexwidth >> "$logfile"
	echo "Regexcodec: "$regexcodec >> "$logfile"
	#######
	
	#END DEBUG-------------------------------------------------------
       
	echo "-------------------------------------------------" >> "$logfile"
	echo "INFO: BEGIN encoding: $(date)" >> "$logfile"
	echo "-------------------------------------------------" >> "$logfile"

	
	#1080p, 720p, and SD
	if [ $mwidth -gt 1280 ] && [ $mwidth -le 2140 ]
		then
		echo "1080p"
		maxsize="1080p"
		mfilename="$mtitle ($myear) - 1080p.m4v"
		echo $mfilename
		
		if [ $mcodec = "h264" ] && [ $extension != "mp4" ] && [ $extension != "m4v" ] && [ $extension = "XXX" ]
			then
			convert-video -o "$dir" --use-m4v  "$input"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
			echo "$dir/$filename.m4v"
			mv "$dir/$filename.m4v" "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
			
		elif [ $mcodec = "h264" ] && [ $extension = "XXX" ] 
			then
			cp "$input" "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		else
			transcode-video --m4v --target big --audio-width other=stereo --preset faster --1080p --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
			#size test
			msourcesize=`stat -f %z "$input"`
			mdestsize=`stat -f %z "$dir/$mtitle ($myear) - 1080p.m4v"`
		
			if [ $mdestsize -ge $msourcesize ]
				then
				rm "$dir/$mfilename"
				mfilename="$mtitle ($myear) - 1080p.m4v"
				transcode-video --m4v --target small --audio-width other=stereo --preset faster --1080p --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
				rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
			fi
		fi
		mfilename="$mtitle ($myear) - 720p.m4v"
		transcode-video --m4v --target big --audio-width other=stereo --preset faster --720p --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
		rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		#size test
		msourcesize=`stat -f %z "$dir/$mtitle ($myear) - 1080p.m4v"`
		mdestsize=`stat -f %z "$dir/$mtitle ($myear) - 720p.m4v"`
		
		if [ $mdestsize -ge $msourcesize ]
			then
			rm "$dir/$mfilename"
			mfilename="$mtitle ($myear) - 720p.m4v"
			transcode-video --m4v --target small --audio-width other=stereo --preset faster --720p --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		fi
		
		mfilename="$mtitle ($myear) - SD.m4v"
		transcode-video --m4v --target big --audio-width other=stereo --audio-width other=stereo --preset faster --SD --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
		rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		#size test
		msourcesize=`stat -f %z "$dir/$mtitle ($myear) - 720p.m4v"` 
		mdestsize=`stat -f %z "$dir/$mtitle ($myear) - SD.m4v"`
		if [ $mdestsize -ge $msourcesize ]
			then
			rm "$dir/$mfilename"		
			transcode-video --m4v --target small --audio-width other=stereo --preset faster --SD --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		fi
	fi
	
	#720p and SD
	if [ $mwidth -gt 720 ] && [ $mwidth -le 1280 ]
		then
		echo "720p"
		maxsize="1080p"
		mfilename="$mtitle ($myear) - 720p.m4v"
		echo $mfilename
		
		if [ $mcodec = "h264" ] && [ $extension != "mp4" ] && [ $extension != "m4v" ] && [ $extension = "XXX" ]
			then
			convert-video -o "$dir" --use-m4v  "$input"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
			mv "$dir/$filename.m4v" "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
			
		elif [ $mcodec = "h264" ] && [ $extension = "XXX" ]
			then
			cp "$input" "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		else
			transcode-video --m4v --target big --audio-width other=stereo --preset faster --720p --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename" 
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		fi
		
		mfilename="$mtitle ($myear) - SD.m4v"
		transcode-video --m4v --target big --audio-width other=stereo --preset faster --SD --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
		rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		#size test
		msourcesize=`stat -f %z "$dir/$mtitle ($myear) - 720p.m4v"` 
		mdestsize=`stat -f %z "$dir/$mtitle ($myear) - SD.m4v"` 
		if [ $mdestsize -ge $msourcesize ]
			then
			rm "$dir/$mfilename"		
			transcode-video --m4v --target small --audio-width other=stereo --preset faster --SD --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		fi
	fi
	
	#SD ONLY
	if [ $mwidth -le 720 ]
		then
		echo "SD"
		maxsize="SD"
		mfilename="$mtitle ($myear).m4v"
		echo $mfilename
		
		if [ $mcodec = "h264" ] && [ $extension != "mp4" ] && [ $extension != "m4v" ] && [ $extension = "XXX" ]
			then
				convert-video -o "$dir" --use-m4v  "$input"
				rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
				mv "$dir/$filename.m4v" "$dir/$mfilename"
				rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		elif [ $mcodec = "h264" ] && [ $extension = "XXX" ]
			then
		    cp "$input" "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		else
			transcode-video --m4v --target big --audio-width other=stereo --preset faster --SD --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		fi
	#size test
		msourcesize=`stat -f %z "$input" `
		mdestsize=`stat -f %z "$dir/$mtitle ($myear).m4v"` 
		if [ $mdestsize -ge $msourcesize ]
		then
			rm "$dir/$mfilename"		
			transcode-video --m4v --target small --audio-width other=stereo --preset faster --SD --crop detect --fallback-crop ffmpeg --handbrake-option optimize "$input" -o "$dir/$mfilename"
			rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
		fi
	
	fi
	

        echo "-------------------------------------------------" >> "$logfile"
        echo "INFO: END encoding (or skipped): $(date)" >> "$logfile"
        echo "-------------------------------------------------" >> "$logfile"



	#make folder
	mkdir "/media/Movies/$mtitle"
	echo "/media/Movies/$mtitle"

	#move files
	if [ "$maxsize" = "1080p" ]
		then
		#mv "$dir/$mtitle ($myear) - 1080p.m4v" "/media/Movies/$mtitle"
		cp "$dir/$mtitle ($myear) - 1080p.m4v" "/media/Movies/$mtitle" && rm "$dir/$mtitle ($myear) - 1080p.m4v"
		#mv "$dir/$mtitle ($myear) - 720p.m4v" "/media/Movies/$mtitle"
		cp "$dir/$mtitle ($myear) - 720p.m4v" "/media/Movies/$mtitle" && rm "$dir/$mtitle ($myear) - 720p.m4v"
		#mv "$dir/$mtitle ($myear) - SD.m4v" "/media/Movies/$mtitle"
		cp "$dir/$mtitle ($myear) - SD.m4v" "/media/Movies/$mtitle" && rm "$dir/$mtitle ($myear) - SD.m4v"
		
		#remove original, link back file for Radarr
		if [ $method = "radarr" ] 
		#|| [ $method = "commandline" ]
		then
			rm "$input"
			ln -s "$dir/$mtitle ($myear) - 1080p.m4v" "$input"
		fi
		#rm "$dir/$mtitle ($myear) - 1080p.m4v.log"
		#rm "$dir/$mtitle ($myear) - 720p.m4v.log"
		#rm "$dir/$mtitle ($myear) - SD.m4v.log"
		
	elif [ "$maxsize" = "720p" ]
		then
		#mv "$dir/$mtitle ($myear) - 720p.m4v" "/media/Movies/$mtitle"
		cp "$dir/$mtitle ($myear) - 720p.m4v" "/media/Movies/$mtitle" && rm "$dir/$mtitle ($myear) - 720p.m4v"
		#mv "$dir/$mtitle ($myear) - SD.m4v" "/media/Movies/$mtitle"
		cp "$dir/$mtitle ($myear) - SD.m4v" "/media/Movies/$mtitle" && rm "$dir/$mtitle ($myear) - SD.m4v"
		
		#remove original, link back file for Radarr
		if [ $method = "radarr" ]
		#|| [ $method = "commandline" ]
			then
			rm "$input"
			ln -s "$dir/$mtitle ($myear) - 720p.m4v" "$input"
		fi
		#rm "$dir/$mtitle ($myear) - 720p.m4v.log"
		#rm "$dir/$mtitle ($myear) - SD.m4v.log"
		
	elif  [ "$maxsize" = "SD" ]
		then
		#mv "$dir/$mtitle ($myear).m4v" "/media/Movies/$mtitle"
		cp "$dir/$mtitle ($myear).m4v" "/media/Movies/$mtitle" && rm "$dir/$mtitle ($myear).m4v"
		
		#remove original, link back file for Radarr
		if [ $method = "radarr" ]
		#|| [ $method = "commandline" ]
			then
			rm "$input"
			ln -s "$dir/$mtitle ($myear).m4v" "$input"
		fi
		#rm "$dir/$mtitle ($myear).m4v.log"
						
	fi
	echo "-------------------------------------------------" >> "$logfile"
        echo "INFO: FILES MOVED: $(date)" >> "$logfile"
        echo "-------------------------------------------------" >> "$logfile"

		
	#update Plex
	wget -O- http://plexaddress:port/library/sections/1/refresh?X-Plex-Token=plextoken
        echo "-------------------------------------------------" >> "$logfile"
        echo "INFO: PLEX UPDATE REQUESTED: $(date)" >> "$logfile"
        echo "-------------------------------------------------" >> "$logfile"



	
else
    echo "No input file provided"
        echo "-------------------------------------------------" >> "$logfile"
        echo "ERROR: NO INPUT FILE PROVIDED: $(date)" >> "$logfile"
        echo "-------------------------------------------------" >> "$logfile"

fi 

#FOR TROUBLESHOOTING
#echo $input
#echo $mfilename
#read -n1 -r -p "Press any key to continue..." key








