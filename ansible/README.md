# ansible-koji-rcip-dev

## Documentation

* http://www.slideshare.net/vtunka/jenkinskoji-plugin-presentation-on-python-ruby-devel-group-brno
* https://fedoraproject.org/wiki/Using_the_Koji_build_system
* https://fedoraproject.org/wiki/Koji/ServerHowTo

## Installation

```shell
ansible-galaxy install -r Ansiblefile.yml --force
```
## Install RPMFactory default on an existing SF
```shell
# Make sure to set the right defaults roles/sf-rpmfactory/defaults/main.yaml
ansible-playbook -i hosts rpmfactory.yml
```
