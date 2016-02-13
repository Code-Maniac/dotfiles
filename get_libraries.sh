rm -rf ./libs
mkdir ./libs
cd ./libs

while read f;
do
	echo "DOWNLOAD:$f"
	curl -O $f
	echo "\n"
done <../.liblist.txt
