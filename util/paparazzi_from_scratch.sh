#!/bin/sh

# ******************************************************************************
#
# Goal: Get the ARM cross compiler, tools and libraries installed and all 
#       working on 64Bit (Linux) computer system like they should
# Version:  1.6 
# Copyright: 2010 LGPL OpenUAS http://www.openuas.org/
# Date: 20100808 00:41
# Usage: $ sh ./paparazzi_from_scratch.sh 2>&1 | tee buildlog.txt  
#        
# I want to improve this script, what can I do?
#
#  IMPR: with automatic log filename appending date like "date +%y%j%H%M%S"
#  IMPR: Set MAJOR and MINOR GCC verion in make parameter automatically
#  IMPR: Add all commands from this wikipage also to the script, so we have a 
#        full paparazzi from scratch in one script!
#
# Useful links:
# http://fun-tech.se/stm32/gcc/index.php
# http://only.mawhrin.net/~alexey/prg/lpc2103/toolchain/
# http://gcc.gnu.org/install/configure.html
# http://wiki.ubuntuusers.de/GNU_arm-toolchain
# http://gcc.gnu.org/onlinedocs/gcc-4.5.0/gcc/ARM-Options.html#ARM-Options
# http://www.hermann-uwe.de/blog/building-an-arm-cross-toolchain-with-binutils-gcc-newlib-and-gdb-from-source
# http://mcuprogramming.com/forum/arm/gnu-arm-toolchain-installer/
# http://code.google.com/p/hobbycode/source/browse/trunk/gnu-arm-installer
# http://www.ethernut.de/en/documents/cross-toolchain-osx.html
# http://paparazzi.enac.fr/w/index.php?title=User:Roirodriguez
# http://chdk.wikia.com/wiki/Gcc433
# http://chdk.wikia.com/wiki/Compiling_CHDK_under_Linux
#
# http://gcc.gnu.org/faq.html#multiple
# https://wiki.kubuntu.org/CompilerFlags
#
# Older compiler http://ubuntu-virginia.ubuntuforums.org/showthread.php?t=91596
# Replaced O_CREAT for S_IRWXU in the files where you get gcc-3.4.4/gcc/collect2.c
#
# The eBook "Definitive guide to GCC" may come in handy
#
# And if all went well, a command
#  $ arm-elf-gcc -print-multi-lib
#
# Should give the following 
#
# .;
# thumb;@mthumb
# interwork;@mthumb-interwork
# thumb/interwork;@mthumb@mthumb-interwork
#
# ******************************************************************************

# In case you want to recompile, and if you do not want to re-download the files
# to save time and bandwith set CLEANUPDOWNLOADS to N
CLEANUPDOWNLOADS="N"

TARGET=arm-elf  #Or use  TARGET=arm-none-eabi or arm_non_eabi the pararazzi makefile will figure it out
PREFIX=$HOME/arm-elf-paparazzi # Install location of the final toolchain, change this to your liking

# If you have a good reason to compile other versions, ONLY then change the version data below
BINUTILS_VERSION=2.16.1
GCC_VERSION=3.4.4
NEWLIB_VERSION=1.13.0
GDB_VERSION=6.8

#Just in case for some reason you want the latest versions a just values here
# and some more 3.4 in the rest of the script
#TARGET=arm-elf
#PREFIX=$HOME/arm-elf-latest # Install location of the final toolchain, change this to your liking
#BINUTILS_VERSION=2.20.1
#GCC_VERSION=4.4.4
#NEWLIB_VERSION=1.18.0
#GDB_VERSION=7.1

# ******************************************************************************
# * No need to change anything below this line, exept improvements             *
# ******************************************************************************

# On multicore Processor this value can speedup the compilation
if grep -q "processor" /proc/cpuinfo || grep -q "siblings" /proc/cpuinfo
then
  SPEEDUPCOMPILATION="-j "$(($( grep "processor" /proc/cpuinfo | sort -u | wc -l ) * $( grep "siblings" /proc/cpuinfo | tail -1 | cut -d: -f2 )))
else
  SPEEDUPCOMPILATION=""
fi

# Install texinfo tool
sudo apt-get install texinfo

# A GCC v3.4 64Bit install to avoid issues whil compiling the crosscompiler, native compile use would be much better
# Or, get debian packages from here http://www.openuas.org/pub/ubuntu/pool/universe/g/gcc-3.4/ or http://es.archive.ubuntu.com/ubuntu/pool/universe/g/gcc-3.4/
wget -N -c http://archive.ubuntu.com/ubuntu/pool/universe/g/gcc-3.4/gcc-3.4-base_3.4.6-8ubuntu2_i386.deb
wget -N -c http://archive.ubuntu.com/ubuntu/pool/universe/g/gcc-3.4/cpp-3.4_3.4.6-8ubuntu2_i386.deb
wget -N -c http://archive.ubuntu.com/ubuntu/pool/universe/g/gcc-3.4/gcc-3.4_3.4.6-8ubuntu2_i386.deb 
# Must be installed in this order
sudo dpkg -i gcc-3.4-base_3.4.6-8ubuntu2_i386.deb
sudo dpkg -i cpp-3.4_3.4.6-8ubuntu2_i386.deb
sudo dpkg -i gcc-3.4_3.4.6-8ubuntu2_i386.deb
if [ "${CLEANUPDOWNLOADS}" != "N" ]
then
  rm *.deb
fi

BINUTILS=binutils-$BINUTILS_VERSION
GCC=gcc-$GCC_VERSION
NEWLIB=newlib-$NEWLIB_VERSION
GDB=gdb-$GDB_VERSION

mkdir $PREFIX

# ** Now set the gcc and tools to be used in environment
echo 'export PATH='$PREFIX'/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

rm -drf build
mkdir build

# Get and compile the BinUtils
wget -N -c http://ftp.gnu.org/gnu/binutils/$BINUTILS.tar.bz2
tar xfvj $BINUTILS.tar.bz2 
cd build
unset CFLAGS && unset LDFLAGS && unset CPPFLAGS && unset CXXFLAGS &&
CC=gcc-3.4
CXX=g++-3.4
../$BINUTILS/configure -v --target=$TARGET --prefix=$PREFIX --enable-interwork --enable-multilib --enable-shared --with-system-zlib --enable-long-long --enable-nls --without-included-gettext --disable-checking --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=$TARGET
make $SPEEDUPCOMPILATION CC=gcc-3.4 CXX=g++-3.4 
make CC=gcc-3.4 CXX=g++-3.4 install
cd ..
rm -rf build/* $BINUTILS
if [ "${CLEANUPDOWNLOADS}" != "N" ]
then
  rm $BINUTILS.tar.bz2
fi

# ** Get and compile GCC stuff
wget -N -c ftp://ftp.gnu.org/gnu/gcc/$GCC/$GCC.tar.bz2
tar xfvj $GCC.tar.bz2

# Set correct MULTILIB options in GCC config, by patching
ONTHFLYPATCHFILE='gcc_thumb_interwork_settings.patch'
rm -f $ONTHFLYPATCHFILE #Just to make sure
echo '--- t-arm-elf	2003-09-30 12:21:41.000000000 +0200' >> $ONTHFLYPATCHFILE
echo '+++ t-arm-elf	2010-08-07 19:17:47.000000000 +0200' >> $ONTHFLYPATCHFILE
echo '@@ -26,8 +26,8 @@' >> $ONTHFLYPATCHFILE
echo ' # MULTILIB_DIRNAMES   += 32bit 26bit' >> $ONTHFLYPATCHFILE
echo ' # MULTILIB_EXCEPTIONS += *mthumb/*mapcs-26*' >> $ONTHFLYPATCHFILE
echo ' # ' >> $ONTHFLYPATCHFILE
echo '-# MULTILIB_OPTIONS    += mno-thumb-interwork/mthumb-interwork' >> $ONTHFLYPATCHFILE
echo '-# MULTILIB_DIRNAMES   += normal interwork' >> $ONTHFLYPATCHFILE
echo '+MULTILIB_OPTIONS    += mno-thumb-interwork/mthumb-interwork' >> $ONTHFLYPATCHFILE
echo '+MULTILIB_DIRNAMES   += normal interwork' >> $ONTHFLYPATCHFILE
echo ' # MULTILIB_EXCEPTIONS += *mapcs-26/*mthumb-interwork*' >> $ONTHFLYPATCHFILE
echo ' # ' >> $ONTHFLYPATCHFILE
echo ' # MULTILIB_OPTIONS    += fno-leading-underscore/fleading-underscore' >> $ONTHFLYPATCHFILE
patch $GCC/gcc/config/arm/t-arm-elf < $ONTHFLYPATCHFILE
rm -f $ONTHFLYPATCHFILE
cd build

# IMPR "../$GCC/gcc/collect2.c" ajust the line in this file to prevent compiler error for older gcc to "redir_handle = open (redir, O_WRONLY | O_TRUNC | O_CREAT, S_IRWXU);"
unset CFLAGS && unset LDFLAGS && unset CPPFLAGS && unset CXXFLAGS &&
CC=gcc-3.4
CXX=g++-3.4
../$GCC/configure -v --enable-languages=c --prefix=$PREFIX --infodir=$PREFIX"/share/info" --mandir=$PREFIX"/share/man" --enable-interwork --enable-multilib --enable-shared --with-system-zlib --enable-long-long --enable-nls --without-included-gettext --disable-checking --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=$TARGET
make $SPEEDUPCOMPILATION CC=gcc-3.4 CXX=g++-3.4  all
make CC=gcc-3.4 CXX=g++-3.4 install
cd ..
# NOTE: We do not delete GCC temporary build yet, we need it once more later in this script

if [ "${CLEANUPDOWNLOADS}" != "N" ]
then
  rm $GCC.tar.bz2
fi

# Now get and compile NewLib, note that sometimes this server is to busy serving the files,
# try to get the files via an FTP client with good resume if it happens
wget -N -c --waitretry=20 http://www.openuas.org/pub/newlib/$NEWLIB.tar.gz
tar xfvz $NEWLIB.tar.gz
cd build
unset CFLAGS && unset LDFLAGS && unset CPPFLAGS && unset CXXFLAGS &&
CC=gcc-3.4
CXX=g++-3.4
../$NEWLIB/configure -v --target=$TARGET --prefix=$PREFIX --enable-interwork --enable-multilib --enable-shared --with-system-zlib --enable-long-long --enable-nls --without-included-gettext --disable-checking --build=x86_64-linux-gnu --host=x86_64-linux-gnu
make $SPEEDUPCOMPILATION CC=gcc-3.4 CXX=g++-3.4 
make CC=gcc-3.4 CXX=g++-3.4  install
cd ..
rm -rf build/* $NEWLIB 
if [ "${CLEANUPDOWNLOADS}" != "N" ]
then
  rm -rf $NEWLIB.tar.gz
fi

# GCC needs to be build again including the real newlib now
cd build
unset CFLAGS && unset LDFLAGS && unset CPPFLAGS && unset CXXFLAGS &&
CC=gcc-3.4
CXX=g++-3.4
../$GCC/configure -v --target=$TARGET --prefix=$PREFIX --enable-interwork --enable-multilib --enable-languages="c,c++" --with-newlib --enable-shared --with-system-zlib --enable-long-long --enable-nls --without-included-gettext --build=x86_64-linux-gnu --host=x86_64-linux-gnu --infodir=$PREFIX"/share/info" --mandir=$PREFIX"/share/man"

make $SPEEDUPCOMPILATION CC=gcc-3.4 CXX=g++-3.4 all-gcc
make CC=gcc-3.4 CXX=g++-3.4 install-gcc
cd ..
rm -rf build/* $GCC
rm -rf build

# We need a symlink to arm-elf-gcc in /usr/bin/ the way the current paparazzi AP compile script works
# We need a better solution here then symlinks, any clues...plz improve
# Yes, helping with a better use of shell by using arm-elf wild-cards is appreciated 
PREFIXBINDIR=$PREFIX/bin
OURBINDIR=/usr/bin
#Remove old symlinks
for x in $OURBINDIR/arm-elf*; do if [ -L $x ]; then sudo rm $x; fi ; done
#Make fresh symlinks so arm tools ar found by paparazzi center
sudo ln -s $PREFIXBINDIR/arm-elf-gcc $OURBINDIR/arm-elf-gcc
sudo ln -s $PREFIXBINDIR/arm-elf-size $OURBINDIR/arm-elf-size
sudo ln -s $PREFIXBINDIR/arm-elf-objcopy $OURBINDIR/arm-elf-objcopy
sudo ln -s $PREFIXBINDIR/arm-elf-objdump $OURBINDIR/arm-elf-objdump
sudo ln -s $PREFIXBINDIR/arm-elf-nm $OURBINDIR/arm-elf-nm
sudo ln -s $PREFIXBINDIR/arm-elf-addr2line $OURBINDIR/arm-elf-addr2line
sudo ln -s $PREFIXBINDIR/arm-elf-ar $OURBINDIR/arm-elf-ar
sudo ln -s $PREFIXBINDIR/arm-elf-as $OURBINDIR/arm-elf-as
sudo ln -s $PREFIXBINDIR/arm-elf-c++filt $OURBINDIR/arm-elf-c++filt
sudo ln -s $PREFIXBINDIR/arm-elf-cpp $OURBINDIR/arm-elf-cpp
sudo ln -s $PREFIXBINDIR/arm-elf-gcc $OURBINDIR/arm-elf-gcc
sudo ln -s $PREFIXBINDIR/arm-elf-gcc-3.4.4 $OURBINDIR/arm-elf-gcc-3.4.4
sudo ln -s $PREFIXBINDIR/arm-elf-gccbug $OURBINDIR/arm-elf-gccbug
sudo ln -s $PREFIXBINDIR/arm-elf-gcov $OURBINDIR/arm-elf-gcov
sudo ln -s $PREFIXBINDIR/arm-elf-ld $OURBINDIR/arm-elf-ld
sudo ln -s $PREFIXBINDIR/arm-elf-nm $OURBINDIR/arm-elf-nm
sudo ln -s $PREFIXBINDIR/arm-elf-objcopy $OURBINDIR/arm-elf-objcopy
sudo ln -s $PREFIXBINDIR/arm-elf-objdump $OURBINDIR/arm-elf-objdump
sudo ln -s $PREFIXBINDIR/arm-elf-ranlib $OURBINDIR/arm-elf-ranlib
sudo ln -s $PREFIXBINDIR/arm-elf-readelf $OURBINDIR/arm-elf-readelf
sudo ln -s $PREFIXBINDIR/arm-elf-size $OURBINDIR/arm-elf-size
sudo ln -s $PREFIXBINDIR/arm-elf-strings $OURBINDIR/arm-elf-strings
sudo ln -s $PREFIXBINDIR/arm-elf-strip $OURBINDIR/arm-elf-strip

# If you also a want to add the debugger, Uncomen the lines here. Configure could need parameter "--disable-werror" in some cases
#wget -N -c ftp://ftp.gnu.org/gnu/gdb/$GDB.tar.bz2
#tar xfvj $GDB.tar.bz2
#cd build
#../$GDB/configure --target=$TARGET --prefix=$PREFIX --enable-interwork --enable-multilib
#make $SPEEDUPCOMPILATION
#make install
#cd ..

#rm -rf build $GDB
#if [ "${CLEANUPDOWNLOADS}" != "N" ]
#then
#  rm $GDB.tar.bz2
#fi

echo "Misterious as this scripts progress might have looked, everything is now done, hopefully without any issue"
