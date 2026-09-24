#!/usr/bin/python3
# Begin gen_playbook.py - script to generate ansible files from terraform data 
#   from terraform output JSON data file
import os
import json
import argparse
import sys
from jinja2 import Environment, FileSystemLoader

# print USAGE 
USAGE = "USAGE: ./gen_ansible.py TF_JSON"
if (len(sys.argv) < 2):
    print(USAGE)
    sys.exit(0)

# set jinja template and output files
transforms = {
    "playbook.j2"  : "playbook.yml",
    "inventory.j2" : "inventory.ini",
    "hosts.j2"     : "hosts.patch",
}
for jinja_tmpl, outfile in transforms.items():

    # parse terraform JSON and strip metadata unnecessary for jinja access
    tf_file = sys.argv[1]
    tf_data = None
    try:
        with open(tf_file, "r") as file:
            tf_data = json.load(file) 
            tf_data = {k: v.get('value') for k, v in tf_data.items()}
    except Exception as e:
        print(f"error parsing '{tf_file}': {e}", file=sys.stderr)
        sys.exit(1)

    # load and render jinja template 
    env = Environment(loader=FileSystemLoader('.'))
    env.filters['basename'] = os.path.basename
    template = env.get_template(jinja_tmpl)
    rendered = template.render(tf=tf_data)
    with open(outfile, 'w') as f:
        f.write(rendered)

    print(f"generated Ansible config: '{outfile}'")
