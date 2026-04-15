from jinja2 import Environment, FileSystemLoader
import os


def generate_email_content(args):
    template_dir = os.path.dirname(__file__)

    print(f"Loading template from: {template_dir}")

    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template('email-template.jinja')

    data = {
        'name': args.name,
        'status': args.status,
        'service_name': args.service_name,
        'build_number': args.build_number,
        'url': args.url,
        'build_time': args.build_time,
        'environment': args.environment
    }

    return template.render(data)
