#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

_private_dir='usr/lib/x86_64-linux-gnu/tor/private'

set -e

_strip_files() {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    echo
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --64
    make -j$(nproc --all) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.so*
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_xz() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _xz_ver="$(wget -qO- 'https://github.com/tukaani-project/xz/releases' | grep -i '/tukaani-project/xz/releases/download/v[1-9]' | sed 's| |\n|g' | grep -i '/tukaani-project/xz/releases/download/v' | sed -e 's|.*/xz-||g' -e 's|"||g' | grep -ivE 'alpha|beta|rc|win' | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/tukaani-project/xz/releases/download/v${_xz_ver}/xz-${_xz_ver}.tar.gz"
    tar -xof xz-*.tar.*
    sleep 1
    rm -f xz-*.tar*
    cd xz-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-threads=yes --enable-year2038 \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/xz
    make install DESTDIR=/tmp/xz
    cd /tmp/xz
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/xz
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
        make -j$(nproc --all) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$ORIGIN'; export LDFLAGS
        cmake \
        -S "." \
        -B "build" \
        -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
        -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
        -DSYSCONF_INSTALL_DIR:PATH=/etc \
        -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
        -DLIB_SUFFIX=64 \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_zstd() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/facebook/zstd.git"
    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$OOORIGIN'; export LDFLAGS
    #make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C lib lib-mt
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C programs
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C contrib/pzstd
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    install -v -c -m 0755 contrib/pzstd/pzstd /tmp/zstd/usr/bin/
    cd /tmp/zstd
    ln -svf zstd.1 usr/share/man/man1/pzstd.1
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_openssl35() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl35_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.5\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.5\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl35_ver}/openssl-${_openssl35_ver}.tar.gz
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS=''; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc --all) all
    rm -fr /tmp/openssl35
    make DESTDIR=/tmp/openssl35 install_sw
    cd /tmp/openssl35
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl35
    /sbin/ldconfig
}

_build_libevent() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libevent_ver="$(wget -qO- 'https://github.com/libevent/libevent/releases' | grep -i 'libevent/releases/tag/release-[1-9]' | sed 's| |\n|g' | grep -i 'libevent/releases/tag/release-[1-9]' | sed -e 's|.*/release-||g' -e 's|"||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/libevent/libevent/releases/download/release-${_libevent_ver}/libevent-${_libevent_ver}.tar.gz"
    tar -xof libevent-*.tar*
    sleep 1
    rm -f libevent-*.tar*
    cd libevent-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static --enable-openssl \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/libevent
    make install DESTDIR=/tmp/libevent
    cd /tmp/libevent
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libevent
    /sbin/ldconfig
}

_build_tor() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _tor_ver="$(wget -qO- 'https://www.torproject.org/download/tor/' | grep -i 'https://dist.torproject.org/tor-[0-9]' | sed 's| |\n|g' | grep -i 'https://dist.torproject.org/tor-[0-9]' | grep -ivE 'alpha|beta|rc|win' | sed -e 's|.*/tor-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://dist.torproject.org/tor-${_tor_ver}.tar.gz"
    tar -xof tor-*.tar*
    sleep 1
    rm -f tor-*.tar*
    cd tor-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN/../lib/x86_64-linux-gnu/tor/private'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-gpl --enable-pic --enable-lzma --enable-zstd \
    --disable-expensive-hardening --disable-fragile-hardening --disable-libscrypt \
    --disable-seccomp --disable-systemd --disable-html-manual \
    --enable-asciidoc --enable-manpage \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/tor
    make install DESTDIR=/tmp/tor
    cd /tmp/tor
    _strip_files
    install -m 0755 -d usr/lib/x86_64-linux-gnu/tor
    cp -afr /"${_private_dir}" usr/lib/x86_64-linux-gnu/tor/
    rm -f usr/lib/x86_64-linux-gnu/tor/private/libevent_core*
    rm -f usr/lib/x86_64-linux-gnu/tor/private/libevent_extra*
    rm -f usr/lib/x86_64-linux-gnu/tor/private/libevent_openssl*
    rm -f usr/lib/x86_64-linux-gnu/tor/private/libevent_pthreads*
    sleep 2
    tar -Jcvf /tmp/tor-"${_tor_ver}"-1_ub2204_amd64.tar.xz *
    echo
    sleep 2
    cd /tmp
    openssl dgst -r -sha256 tor-"${_tor_ver}"-1_ub2204_amd64.tar.xz | sed 's|\*| |g' > tor-"${_tor_ver}"-1_ub2204_amd64.tar.xz.sha256
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/tor
    /sbin/ldconfig
}

############################################################################

rm -fr /usr/lib/x86_64-linux-gnu/tor

_build_zlib
_build_xz
_build_brotli
_build_zstd
_build_openssl35
_build_libevent
_build_tor

rm -fr /tmp/_output
mkdir /tmp/_output
mv -f /tmp/tor-*.tar* /tmp/_output/

echo
echo ' build tor ub2204 done'
echo
exit
