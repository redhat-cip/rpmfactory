#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2016 Red Hat, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Usage:
# python cb-add-get.py rpmfactory.sftests.com admin:userpass \
# add /tmp/test/jenkins-koji.tgz mysupersecret
# python cb-add-get.py rpmfactory.sftests.com admin:userpass get mysupersecret

import os
import re
import sys
import requests
import mimetypes

from pysflib.sfauth import get_cookie


def add(data_path, description, host, sfcookie):
    filename = os.path.basename(data_path)
    mimetype = mimetypes.guess_type(data_path)
    slotid = 'thefile'

    files = [('_.scope', ('',
                          'GLOBAL')),
             ('_.id', ('',
                       '')),
             ('_.username', ('',
                             '')),
             ('_.password', ('',
                             '')),
             ('_.description', ('',
                                '')),
             ('stapler-class', ('',
                                'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl')),  # noqa
             ('stapler-class', ('',
                                'com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey')),  # noqa
             ('stapler-class', ('',
                                'org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl')),  # noqa
             (slotid, (filename,
                       open(data_path, 'rb'),
                       mimetype)),
             ('_.description', ('',
                                description)),
             ('stapler-class', ('',
                                'org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl')),  # noqa
             ('_.id', ('',
                       '')),
             ('_.secret', ('',
                           '')),
             ('_.description', ('',
                                '')),
             ('stapler-class', ('',
                                'com.cloudbees.plugins.credentials.impl.CertificateCredentialsImpl')),  # noqa
             ('_.scope', ('',
                          'GLOBAL')),
             ('id115.keyStoreSource', ('',
                                       '0')),
             ('_.keyStoreFile', ('',
                                 '')),
             ('stapler-class', ('',
                                'com.cloudbees.plugins.credentials.impl.CertificateCredentialsImpl$FileOnMasterKeyStoreSource')),  # noqa
             ('kind', ('',
                       'com.cloudbees.plugins.credentials.impl.CertificateCredentialsImpl$FileOnMasterKeyStoreSource')),  # noqa
             ('_.uploadedKeystore', ('',
                                     '')),
             ('stapler-class', ('',
                                'com.cloudbees.plugins.credentials.impl.CertificateCredentialsImpl$UploadedKeyStoreSource')),  # noqa
             ('kind', ('',
                       'com.cloudbees.plugins.credentials.impl.CertificateCredentialsImpl$UploadedKeyStoreSource')),  # noqa
             ('_.password', ('',
                             '')),
             ('_.description', ('',
                                '')),
             ('json', ('',
                       "{\"\": \"2\", \"credentials\": {\"stapler-class\": \"org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl\", \"id\": \"\", \"file\": \"%s\", \"description\": \"%s\"}}" % (slotid, description))),  # noqa
             ('Submit', ('',
                         'OK')),
    ]

    cookies = {'auth_pubtkt': sfcookie}
    requests.post(
        "http://%s/jenkins/credential-store/domain/_/createCredentials" % host,
        files=files,
        cookies=cookies)


def get(description, host, sfcookie):
    cookies = {'auth_pubtkt': sfcookie}
    response = requests.get(
        "http://%s/jenkins/credential-store/domain/_/" % host,
        cookies=cookies)
    for line in response.text.split('\n'):
        m = re.search('<a href="credential/(\S+)" tooltip="%s">' %
                      description, line)
        if m:
            print m.groups()[0]
            sys.exit(0)


if __name__ == "__main__":

    host = sys.argv[1]
    auth = sys.argv[2]
    user, password = auth.split(':')
    sfcookie = get_cookie(host, user, password)

    if sys.argv[3] == 'get':
        description = sys.argv[4]
        get(description, host, sfcookie)
        sys.exit(1)
    if sys.argv[3] == 'add':
        data_path = sys.argv[4]
        assert os.path.isfile(data_path)
        description = sys.argv[5]
        add(data_path, description, host, sfcookie)
