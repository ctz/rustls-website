all: packages.done certs.done config.done webroot.done fetch-rustls.done build.done

backports.done:
	echo "deb http://ftp.debian.org/debian wheezy-backports main" > /etc/apt/sources.list.d/backports.list
	touch $@

packages.done: backports.done
	apt-get update
	apt-get -y install nginx build-essential git
	apt-get -y install certbot -t jessie-backports
	curl https://sh.rustup.rs -sSf | sh
	touch $@

certs.done: packages.done
	certbot certonly --standalone -d rustls.jbp.io --non-interactive --email jbp@jbp.io
	openssl rsa -in /etc/letsencrypt/live/rustls.jbp.io/privkey.pem \
	        > /etc/letsencrypt/live/rustls.jbp.io/privkey.rsa
	touch $@

config.done: packages.done
	cp -v cfg/nginx /etc/nginx/sites-available/default
	cp -v cfg/forwarder.service /etc/systemd/system/forwarder.service
	chmod 644 /etc/systemd/system/forwarder.service
	touch $@

webroot.done:
	cp -vr html /var/www
	dd if=/dev/zero bs=1M count=10 of=/var/www/html/10mb.bin
	dd if=/dev/zero bs=1M count=100 of=/var/www/html/100mb.bin
	touch $@

fetch-rustls.done:
	git clone https://github.com/ctz/rustls.git /root/rustls
	touch $@

build.done: fetch-rustls.done
	cd /root/rustls
	~/.cargo/bin/cargo test --no-run
	~/.cargo/bin/cargo test --no-run --release
	touch $@

run.done: build.done config.done
	systemctl daemon-reload
	systemctl restart forwarder.service
	systemctl restart nginx

