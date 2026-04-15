import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import argparse
from generate_email import generate_email_content  # Assuming generate_email.py is in the same directory

# Function to send email with dynamic SMTP configuration
def send_email(subject, html_content, recipient, smtp_user):
    # SMTP server configuration (same for all environments)
    smtp_server = 'localhost'
    smtp_port = 1025
    smtp_password = 'n/a'

    # Create the email
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = smtp_user
    msg['To'] = recipient

    # Attach the HTML content
    part = MIMEText(html_content, 'html')
    msg.attach(part)

    # Send the email
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        recipients = 'edilson.mucanze@standardbank.co.mz,tirapa.tondapu@standardbank.co.mz,bharath.gundapu@standardbank.co.mz,padma.padma@standardbank.co.mz'
        msg['To'] = recipients
        server.sendmail(msg['From'], recipients.split(','), msg.as_string())

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate and send email.')
    parser.add_argument('--name', required=True, help='Name of the user')
    parser.add_argument('--status', required=True, help='Build status')
    parser.add_argument('--service_name', required=True, help='Service name')
    parser.add_argument('--build_number', required=True, help='Build number')
    parser.add_argument('--build_time', required=True, help='Build time')
    parser.add_argument('--url', required=True, help='URL for the build')
    parser.add_argument('--recipient', required=True, help='Recipient email address')
    parser.add_argument('--environment', required=True, help='Environment (nonprod, prod, dr)')

    args = parser.parse_args()

    # Clean up the service name to avoid newline issues
    clean_service_name = args.service_name.replace('\n', ', ')

    # Generate email content
    html_content = generate_email_content(args)

    # Determine the correct SMTP user (sender email) based on the environment
    if args.environment == 'nonprod':
        smtp_user = 'ocp-nonprod@standardbank.co.mz'
    elif args.environment == 'prod':
        smtp_user = 'ocp-pr-cluster1@standardbank.co.mz'
    elif args.environment == 'dr':
        smtp_user = 'ocp-dr-cluster1@standardbank.co.mz'
    else:
        raise ValueError(f"Unknown environment: {args.environment}")

    # Send email with environment-specific SMTP user
    send_email(f'{clean_service_name}-CP4I Job Completion Notification', html_content, args.recipient, smtp_user)
