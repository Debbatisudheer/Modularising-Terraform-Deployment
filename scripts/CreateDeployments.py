#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
from distutils.dir_util import copy_tree
from jinja2 import Environment, FileSystemLoader

components = ['infra', 'alb', 'waf', 'ecservices', 'splunk', 'datadog']


def run_cmd(cmd):
    print("Running CMD: " + cmd)
    cmd_id = subprocess.Popen(
        cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    stdout, stderr = cmd_id.communicate()
    print("STDOUT: " + str(stdout.decode()))
    print("STDERR: " + str(stderr.decode() if stderr else ""))
    print("ReturnCode: " + str(cmd_id.returncode))
    return cmd_id.returncode


def render_template(dest_dir, template_name, file_name, input_json):
    j2_env = Environment(loader=FileSystemLoader(dest_dir), trim_blocks=True, lstrip_blocks=True)
    template_file = os.path.join(dest_dir, template_name)
    if not os.path.exists(template_file):
        return
    rendered_template = j2_env.get_template(template_name).render(input_json)
    output_file_path = os.path.join(dest_dir, file_name)
    with open(output_file_path, 'w+') as f:
        f.write(rendered_template)
    # Remove the original .j2 template
    os.remove(template_file)


def deploy_app(opts):
    src_dir = opts['srcDir']
    dest_dir = opts['destDir']
    if not os.path.exists(src_dir):
        print(src_dir + " does not exist.")
        exit(1)

    print("Copying the template from " + src_dir + " to " + dest_dir)
    copy_tree(src_dir, dest_dir)

    # Render all .j2 files dynamically
    for fname in os.listdir(dest_dir):
        if fname.endswith('.j2'):
            render_template(dest_dir, fname, fname[:-3], opts['inputJSON'])

    print("Deployment for " + opts['app'] + " created.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Create Eventing Pipeline.')
    parser.add_argument(
        '--fullStack',
        dest='fullStack',
        action='store_true',
        help='Boolean if you want to create deployment for all components.'
    )
    parser.add_argument('-t', '--template', dest='template', help='The template directory.')
    parser.add_argument('-a', '--app', dest='app', help='The application name of template')
    parser.add_argument('-i', '--input', dest='input', help='The data in json format')
    parser.add_argument('-d', '--destination', dest='destination', help='The Destination to render the template to')
    parser.set_defaults(fullStack=False)

    args = parser.parse_args()
    print(args)

    opts = {}
    config = {}

    # Load input JSON
    with open(args.input) as f:
        config.update(json.load(f))

    opts['inputJSON'] = config
    opts['cwd'] = os.getcwd()

    if args.fullStack:
        for component in components:
            opts['srcDir'] = os.path.join(opts['cwd'], args.template, component)
            opts['destDir'] = os.path.join(opts['cwd'], args.destination, component)
            opts['app'] = component
            deploy_app(opts)
    else:
        opts['app'] = args.app
        opts['srcDir'] = os.path.join(opts['cwd'], args.template, opts['app'])
        opts['destDir'] = os.path.join(opts['cwd'], args.destination, opts['app'])
        deploy_app(opts)



