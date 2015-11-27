ssl_cnf_owner: root
ssl_cnf_group: root
ca_root_path: /etc/pki/koji
countryName_default: 'FR'
stateOrProvinceName_default: 'Paris'
localityName_default: 'Paris'
organizationName_default: 'RedHat'
organizationalUnitName: 'RCIP'
CN: 'koji.sf.enovance.com'
ca_name: koji
koji_ca_emailUser: info
koji_ca_emailDomain: example.org

koji_ca_certs2issue:
  - kojira
  - "{{ ansible_fqdn }}"

koji_builder_patch_crearepo: true
