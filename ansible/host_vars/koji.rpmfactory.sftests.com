---
koji_builder_smtphost: localhost
koji_builder_from_addr: Koji Build System <buildsys@sftests.com>
koji_builder_topdir: /mnt/koji
koji_builder_minspace: 4096
koji_builder_packager: RPMFactory
koji_builder_user: koji-builder01
koji_builder_cert: "/etc/pki/koji/pems/koji-builder01.pem"

ssl_cnf_owner: root
ssl_cnf_group: root
ca_root_path: /etc/pki/koji
countryName_default: 'FR'
stateOrProvinceName_default: 'Paris'
localityName_default: 'Paris'
organizationName_default: 'RedHat'
organizationalUnitName: 'RCIP'
CN: 'rcip-dev.ring.sftests.com'
ca_name: koji
koji_ca_emailUser: softwarefactory
koji_ca_emailDomain: sftests.com

koji_db_pass: koji

postgresql_databases:
  - name: koji

postgresql_users:
  - name: koji
    pass: "{{ koji_db_pass }}"
    encrypted: no       # denotes if the password is already encrypted.

postgresql_user_privileges:
  - name: koji         # user name
    db: koji           # database
    priv: "ALL"        # privilege string format: example: INSERT,UPDATE/table:SELECT/anothertable:ALL

koji_hub_kojiadmins:
  - { name: 'kojiadmin' }
  - { name: 'sfadmin', email: 'softwarefactory@sftests.com' }

koji_hub_issue_cert: True
koji_kojira_grant_repo: True
koji_kojira_issue_cert: True
koji_kojira_topdir: /mnt/koji
koji_builder_hub_server: "http://{{ hostvars[groups['koji_hub'][0]]['inventory_hostname'] }}/kojihub"

koji_web_secret: cuKeix4Uqueey
koji_web_issue_cert: true
