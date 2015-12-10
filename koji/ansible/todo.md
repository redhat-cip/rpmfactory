# ToDo

* support multi-builders (le touch fait que uniquement le premier builder est renseingé)
* scp des certificats sur les builders
* creation des certs pour les builders
* nfs sur les builders
* install de createrepo sur les builders
 * Fix createrepo (on centos builders, use fedora version)
 * https://bugzilla.redhat.com/show_bug.cgi?id=1058975
 * https://kojipkgs.fedoraproject.org/packages/createrepo/0.10.3/3.fc21/noarch/createrepo-0.10.3-3.fc21.noarch.rpm
* rights sur /mnt/koji (kojira)
 * setsebool -P httpd_can_network_connect_db=1 allow_httpd_anon_write=1 httpd_use_nfs=1
 * chcon -R -t public_content_rw_t /mnt/koji/*
