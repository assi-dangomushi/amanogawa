#!/bin/bash

# raspi xover install script
# version 0.1
# 2021/07/17

mkdir ~/amanogawaAudioLabo
mkdir ~/coef

## アップデート
sudo apt update
sudo apt -y dist-upgrade 
sudo apt -y autoremove

sudo apt -y install git libfftw3-dev sox mpd nim

## /etc/mpd.conf 編集
sedscript='
s/^log_file/#log_file/
/^#group/ a\
group   "audio"
s/^#follow_outside_symlinks/follow_outside_symlinks/
s/^#follow_inside_symlinks/follow_inside_symlinks/
s/^bind_to_address/#bind_to_address/
/^audio_output/,/^}/ s/^/#/

/^## Example "pipe" output:/ a\
audio_output {\
 type "pipe"\
 name "amaiir_hdmi"\
 command "amaiir /home/pi/amaiir.conf > /tmp/hdmipipe"\
 format "96000:32:2"\
}\
#audio_output {\
# type "pipe"\
# name "amafir_hdmi"\
# command "taskset -c 1 amafir2 /home/pi/coef > /tmp/hdmipipe"\
# format "96000:32:2"\
#}

/^# Normalization automatic volume adjustments/  i\
samplerate_converter            "soxr very high"\
'

f="/etc/mpd.conf"
a=$(grep 'amafir' "$f")
if [ "$a" = "" ]; then
  sudo sed -i.bak -e "${sedscript}" "$f"
fi

## playlists にラジオを登録
#sudo cp playlists/* /var/lib/mpd/playlists/
echo "http://174.36.206.197:8000" | sudo tee /var/lib/mpd/playlists/VeniceClassic.m3u
echo "http://185.33.21.111:80/ajazz_128" | sudo tee /var/lib/mpd/playlists/AdoreJazzRadio.m3u

## usbメモリをmusic下にリンク
sudo mkdir  /var/lib/mpd/music/usb
sudo ln -s  /media/usb0 /var/lib/mpd/music/usb/usb0
sudo ln -s  /media/usb1 /var/lib/mpd/music/usb/usb1


## サンプルプログラムmake 一般ユーザーで可
#sed -e "$ i CFLAGS+= -O2 -march=native" /opt/vc/src/hello_pi/libs/ilclient/Makefile
f="/opt/vc/src/hello_pi/libs/ilclient/Makefile"
a=$(grep '\-O2 \-march=native' "$f")
if [ "$a" = "" ]; then
  sed -i.bak -e "$ a CFLAGS+= -O2 -march=native"  "$f"
fi

cd /opt/vc/src/hello_pi/libs/ilclient
make

cd -

## hdmi_play2.bin インストール
cd ~/amanogawaAudioLabo/
git clone https://github.com/assi-dangomushi/hdmi_play.git
cd hdmi_play
make
strip hdmi_play2.bin
sudo cp ./hdmi_play2.bin /usr/bin/

cd ~/amainit

## amafir2 インストール
cd ~/amanogawaAudioLabo/ 
git clone https://github.com/assi-dangomushi/amafir.git
cd amafir
make
strip amafir2
sudo cp ./amafir2 /usr/bin/


## amaiir インストール
cd ~/amanogawaAudioLabo/ 
git clone https://github.com/assi-dangomushi/amaiir.git
cd amaiir
nim c -d:release amaiir.nim
strip amaiir
sudo cp ./amaiir /usr/bin/
cp sample.conf /home/pi/amaiir.conf

## /etc/rc.local 修正
sedscript=$(cat << EOS
/^exit 0/ i\
mkfifo /tmp/hdmipipe\n\
chgrp audio /tmp/hdmipipe\n\
chmod 660 /tmp/hdmipipe\n\
chrt -f 99 taskset -c 0 hdmi_play2.bin 96000 < /tmp/hdmipipe &\n\
echo "" > /tmp/hdmipipe\n\
\n\
\n
EOS
)

f="/etc/rc.local"
a=$(grep 'hdmi_play' "$f")
if [ "$a" = "" ]; then
  sudo sed -i.bak -e "${sedscript}" "$f"
fi

## config.txt 修正
sedscript="\
s/^#hdmi_force_hotplug=1/hdmi_force_hotplug=1/
s/^dtparam=audio=on/#dtparam=audio=on/
$ a #amanogawa
"

f="/boot/config.txt"
a=$(grep 'amanogawa' "$f")
if [ "$a" = "" ]; then
  sudo sed -i.bak -e "${sedscript}" "$f"
fi

sudo reboot

