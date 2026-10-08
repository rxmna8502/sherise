"""Flask CLI commands for provisioning administrators without plaintext secrets."""

import click

from extensions import db
from .auth import hash_password
from .models import AdminUser
from .permissions import VALID_ROLES


def register_admin_cli(app):
    @app.cli.command("admin-create")
    @click.option("--email", prompt=True)
    @click.option("--role", type=click.Choice(sorted(VALID_ROLES)), prompt=True)
    def admin_create(email, role):
        """Create an Admin account with an interactively entered password."""
        email = email.strip().lower()
        password = click.prompt("Password", hide_input=True, confirmation_prompt=True)
        if not email or not password:
            raise click.ClickException("Email and password are required")
        if AdminUser.query.filter_by(email=email).first():
            raise click.ClickException("An Admin account with that email already exists")
        admin = AdminUser(
            id=__import__("uuid").uuid4().hex,
            email=email,
            password_hash=hash_password(password),
            role=role,
        )
        db.session.add(admin)
        db.session.commit()
        click.echo(f"Created Admin account {email} with role {role}")
