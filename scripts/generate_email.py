import argparse
from jinja2 import Environment, FileSystemLoader
import os

def generate_email_content(args):
    # Set up the Jinja2 environment and load the template
    template_dir = os.path.dirname(__file__)
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template('email-template.jinja')

    # Define data from command-line arguments
    data = {
        'name': args.name,
        'status': args.status,
        'service_name': args.service_name,
        'build_number': args.build_number,
        'url': args.url,
        'build_time': args.build_time,
        'environment': args.environment
    }

    # Render the template with the data
    email_content = template.render(data)
    return email_content

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate email content.')
    parser.add_argument('--name', required=True, help='Name of the user')
    parser.add_argument('--status', required=True, help='Build status')
    parser.add_argument('--service_name', required=True, help='Service name')
    parser.add_argument('--build_number', required=True, help='Build number')
    parser.add_argument('--build_time', required=True, help='Build time')
    parser.add_argument('--url', required=True, help='CD Url')
    parser.add_argument('--environment', required=True, help='Environment (nonprod, prod, dr)')

    args = parser.parse_args()
    print(generate_email_content(args))