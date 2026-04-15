import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import argparse
import os
from generate_email import generate_email_content


def send_email(subject, html_content, recipient, smtp_user):
    # ✅ Support both LOCAL + COMPANY SMTP
    smtp_server = os.getenv("SMTP_SERVER", "localhost")
    smtp_port = int(os.getenv("SMTP_PORT", "1025"))

    print(f"Using SMTP Server: {smtp_server}:{smtp_port}")

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = smtp_user
    msg['To'] = recipient

    part = MIMEText(html_content, 'html')
    msg.attach(part)

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.sendmail(msg['From'], recipient.split(','), msg.as_string())
            print("✅ Email sent successfully")
    except Exception as e:
        print("❌ Failed to send email:", str(e))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate and send email.')

    parser.add_argument('--name', required=True)
    parser.add_argument('--status', required=True)
    parser.add_argument('--service_name', required=True)
    parser.add_argument('--build_number', required=True)
    parser.add_argument('--build_time', required=True)
    parser.add_argument('--url', required=True)
    parser.add_argument('--recipient', required=True)
    parser.add_argument('--environment', required=True)

    args = parser.parse_args()

    # ✅ Clean service names
    clean_service_name = args.service_name.replace('\n', ', ').strip()

    html_content = generate_email_content(args)

    # ✅ Dynamic sender
    if args.environment == 'nonprod':
        smtp_user = 'ocp-nonprod@standardbank.co.mz'
    elif args.environment == 'prod':
        smtp_user = 'ocp-pr-cluster1@standardbank.co.mz'
    elif args.environment == 'dr':
        smtp_user = 'ocp-dr-cluster1@standardbank.co.mz'
    else:
        raise ValueError(f"Unknown environment: {args.environment}")

    send_email(
        f'{clean_service_name}-CP4I Job Notification',
        html_content,
        args.recipient,
        smtp_user
    )
