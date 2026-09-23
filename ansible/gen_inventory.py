#!/usr/bin/python3
# Begin gen_inventory.py - script to generate ansible inventory 
#   from terraform output JSON data file
import os
import json
import argparse
import sys
from jinja2 import Environment, FileSystemLoader

# set template and output file
jinja_tmpl = "inventory.j2";
out_file   = "inventory.ini";

# print USAGE 
USAGE = "USAGE: ./gen_inventory.py TF_JSON"
if (len(sys.argv) < 2):
    print(USAGE)
    sys.exit(0)

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
template = env.get_template(jinja_tmpl)
rendered = template.render(tf=tf_data)
with open(out_file, 'w') as f:
    f.write(rendered)

print(f"Successfully generated Ansible inventory: '{out_file}'")
