#!/usr/bin/env python
""" koji2graphviz.py - Visualize Koji Tags and their relationships.

Author:     Ralph Bean <rbean@redhat.com>
License:    LGPLv2+
"""

import multiprocessing.pool
import sys

from operator import itemgetter as getter

import koji

# https://pypi.python.org/pypi/graphviz
from graphviz import Digraph

N = 40

graph_options = {'format': 'png'}
tags_parent_child = Digraph(
    name='tags_parent_child', comment='Koji Tags, Parent/Child relationships',
    **graph_options)
tags_groups = Digraph(
    name='tags_groups', comment='Koji Tags and what Groups they are in',
    **graph_options)
tags_and_targets = Digraph(
    name='tags_and_targets', comment='Koji Tags and Targets',
    **graph_options)

client = koji.ClientSession('http://koji-rpmfactory.ring.enovance.com/kojihub')
tags = client.listTags()
for tag in tags:
    tags_parent_child.node(tag['name'], tag['name'])


def get_relations(tag):
    sys.stdout.write('.')
    sys.stdout.flush()
    idx = tag['id']
    return (tag, {
        'parents': client.getInheritanceData(tag['name']),
        'group_list': sorted(map(getter('name'), client.getTagGroups(idx))),
        'dest_targets': client.getBuildTargets(destTagID=idx),
        'build_targets': client.getBuildTargets(buildTagID=idx),
        'external_repos': client.getTagExternalRepos(tag_info=idx),
    })


print "getting parent/child relationships with %i threads" % N
pool = multiprocessing.pool.ThreadPool(N)
relationships = pool.map(get_relations, tags)
print
print "got relationships for all %i tags" % len(relationships)

print "collating known groups"
known_groups = list(set(sum([
    data['group_list'] for tag, data in relationships
], [])))
for group in known_groups:
    tags_groups.node('group-' + group, 'Group: ' + group)

print "collating known targets"
known_targets = list(set(sum([
    [target['name'] for target in data['build_targets']] +
    [target['name'] for target in data['dest_targets']]
    for tag, data in relationships
], [])))
for target in known_targets:
    tags_and_targets.node('target-' + target, 'Target: ' + target)

print "building graph"
for tag, data in relationships:
    for parent in data['parents']:
        tags_parent_child.edge(parent['name'], tag['name'])
    for group in data['group_list']:
        tags_groups.edge(tag['name'], 'group-' + group)
    for target in data['build_targets']:
        tags_and_targets.edge('target-' + target['name'], tag['name'], 'build')
    for target in data['dest_targets']:
        tags_and_targets.edge(tag['name'], 'target-' + target['name'], 'dest')

print "writing"
tags_parent_child.render()
tags_groups.render()
tags_and_targets.render()
print "done"
