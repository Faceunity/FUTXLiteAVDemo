# Download CNamaSdk
cd $(dirname $0)

cha
if [ ! -e "SDK/ImSDK.framework" ]; then
URL="https://pod-1252463788.cos.ap-guangzhou.myqcloud.com/mlvbspec/ImSDK/ImSDK.framework.zip"
echo "Downloading IM SDK from $URL"
curl "$URL" --output SDK/ImSDK.zip
cd SDK
unzip -q ImSDK.zip
rm -rf ImSDK.zip
rm -rf __MACOSX
fi