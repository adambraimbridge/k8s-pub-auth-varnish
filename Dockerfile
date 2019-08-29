FROM alpine:3.9

ENV VARNISHSRC=/usr/include/varnish VMODDIR=/usr/lib/varnish/vmods

RUN apk --update add varnish varnish-dev git automake autoconf libtool python make py-docutils curl jq && \
  cd / && echo "-------basicauth-build-------" && \
  git clone http://git.gnu.org.ua/repo/vmod-basicauth.git && \
  cd vmod-basicauth && \
  git clone http://git.gnu.org.ua/repo/acvmod.git && \
  git checkout ef9772ebab0c3aeaf6ad9a8f843fa458d0c8397c && \
  mkdir -p /usr/include/varnish/bin/varnishtest/ && \
  ln -s /usr/bin/varnishtest /usr/include/varnish/bin/varnishtest/varnishtest && \
  mkdir -p /usr/include/varnish/lib/libvcc/ && \
  ln -s /usr/share/varnish/vmodtool.py /usr/include/varnish/lib/libvcc/vmodtool.py && \
  ./bootstrap && \
  ./configure && \
  make && \
  make install && \
  apk del git automake autoconf libtool python make py-docutils && \
  rm -rf /var/cache/apk/* /vmod-basicauth

COPY default.vcl /etc/varnish/default.vcl
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
